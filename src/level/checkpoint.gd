extends Area2D

@export var checkpoint_id: int = 0
## Which level this checkpoint belongs to — set by EntitySpawner as a
## pre-add_child prop (see level_base.gd) so it's correct before any touch.
## Was hardcoded to 1 for every level; a Level 2/3 checkpoint silently
## clobbered Level 1's save slot, and every level's respawn read slot 1 back.
@export var level_index: int = 1

@onready var sprite: ColorRect = $ColorRect

var activated: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    # Founder, 2026-08-20 (Block_Fixes_1): the floating blue/green block was
    # never meant to be a visible object — it's a save trigger. Six screenshots
    # showed it reading as an unexplained solid box in every level once an
    # earlier "boss-launch" fix added a solid `StandSurface` StaticBody2D to
    # this scene. That session hid the ColorRect (alpha 0) but deliberately
    # KEPT StandSurface solid, which turned it into an INVISIBLE 32x48 wall at
    # every checkpoint in every level.
    #
    # Founder, 2026-08-22 ("The fucking 1st boss is still floating in the
    # fucking sky!!!!"): that invisible wall is the whole P0. Measured with a
    # real-physics probe on the live level_01 scene — the Auditor walks west
    # toward the player, reaches checkpoint 2 (level_01_data.tres:
    # `checkpoints = [Vector2(1100,500), Vector2(2200,500)]`) and his x FREEZES
    # at exactly 2200 for the rest of the fight. A 220px-tall boss cannot pass
    # a 32x48 post, so `is_on_wall()` stays true, which re-arms the wall-leap
    # every cooldown forever: he pogos between y=90 and y=280 (feet at 310,
    # above the level's HIGHEST platform at y=300) and never advances again.
    # That is precisely the "suspended in the sky, not on any platform"
    # screenshot — he is not hovering, he is trapped on an invisible post.
    #
    # RESOLUTION — StandSurface is gone. A checkpoint is a save TRIGGER only.
    #
    # This does supersede the founder's 2026-08-20 request ("The 1st boss need
    # to be able to jump on the block that i have circled so that he can launch
    # himself onto the platform"), and that is deliberate, because a LATER
    # instruction of his own made that request unsatisfiable:
    #
    #   * That request was about a block he could SEE and circle.
    #   * Block_Fixes_1 (also his) then required the block to stop being a
    #     visible object, so its ColorRect alpha is 0 — see below.
    #
    # A launch pad nobody can see is not a launch pad; it is an invisible
    # 32x48 solid. Keeping it solid gives two failure modes and no benefit:
    # horizontally it walled a 220px boss (he froze at x=2200 for 46.8s of a
    # 60s fight, pogoing above every platform — the "floating in the sky"
    # report), and vertically it lets a body come to REST on an invisible box
    # 150px above the ground, which renders as a boss standing on thin air.
    # `checkpoint_solid_platform_test` proved that second one was reachable.
    # Making it one-way would have fixed only the first and preserved the
    # second, i.e. kept a way to reproduce the exact complaint.
    sprite.color = Color(0.5, 0.5, 1.0, 0.0)
    sprite.size = Vector2(32, 48)
    $CollisionShape2D.position = Vector2(16, 24)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and not activated:
        activated = true
        GameManager.save_checkpoint(level_index, checkpoint_id, global_position)
        AudioManager.play_sfx("powerup")
        _snapshot_moment()

## Snapshot Moment (task #23, Movie-Layer marketing hook): a section-end beat.
## Brief camera breath + a 5s "capture" hint; pressing F12 (or P — browsers
## reserve F12 for devtools) opens a pre-filled X share for THIS section.
## Skippable ambience: ignore it and it fades. One per checkpoint.
var _snapshot_active: bool = false

func _snapshot_moment() -> void:
    ScreenShake.zoom_to(0.92, 0.5)
    get_tree().create_timer(1.2).timeout.connect(func() -> void:
        ScreenShake.zoom_to(1.0, 0.6))
    var hint := Label.new()
    hint.text = "Section clear! Score %d\nF12 / P — capture & share this moment" % GameManager.total_score
    hint.add_theme_font_size_override("font_size", 14)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.position = Vector2(-110, -110)
    hint.modulate = Color(0.9, 1.0, 0.92, 0.0)
    hint.z_index = 50
    add_child(hint)
    _snapshot_active = true
    var tw := hint.create_tween()
    tw.tween_property(hint, "modulate:a", 1.0, 0.3)
    tw.tween_interval(5.0)
    tw.tween_property(hint, "modulate:a", 0.0, 0.5)
    tw.finished.connect(func() -> void:
        _snapshot_active = false
        hint.queue_free())

func _unhandled_input(event: InputEvent) -> void:
    if not _snapshot_active or not (event is InputEventKey) or not event.pressed:
        return
    var key := event as InputEventKey
    if key.physical_keycode == KEY_F12 or key.physical_keycode == KEY_P:
        _snapshot_active = false
        Web3Bridge.report_metric("share_clicked", {"source": "snapshot"})
        Web3Bridge.track("snapshot_share")
        # Confirmed handle (SOCIAL_LINKS.md) + a rotating content-engine tagline.
        var text := "%s\nJust cleared a section of the Smoke Realm with %d pts. Come take my spot: https://youngstunners88.itch.io/lil-blunt-adventure @smokering25 #SMOKE" % [GameManager.random_tagline(), GameManager.total_score]
        OS.shell_open("https://twitter.com/intent/tweet?text=" + text.uri_encode())
