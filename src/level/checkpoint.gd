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
    sprite.color = Color(0.5, 0.5, 1.0, 0.5)
    sprite.size = Vector2(32, 48)
    $CollisionShape2D.position = Vector2(16, 24)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and not activated:
        activated = true
        GameManager.save_checkpoint(level_index, checkpoint_id, global_position)
        sprite.color = Color(0.2, 1.0, 0.2, 0.8)
        AudioManager.play_sfx("powerup")
        # Flash effect
        var tween := create_tween()
        tween.tween_property(sprite, "scale:y", 1.5, 0.2)
        tween.tween_property(sprite, "scale:y", 1.0, 0.2)
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
