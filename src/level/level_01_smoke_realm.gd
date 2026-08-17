extends LevelBase

var _boss_arena_active: bool = false

func _ready() -> void:
    level_data = preload("res://src/resources/level_01_data.tres")
    super()
    _setup_smoke_platforms()
    _setup_blaze_portal(Vector2(1450, 250), 1500, 1)
    # Hidden door to the Smoke Lounge, tucked up on a high ledge.
    var door := preload("res://src/level/secret_door.tscn").instantiate()
    door.global_position = Vector2(2350, 250)
    add_child(door)
    _setup_depth_routes()
    AudioManager.set_reverb_profile("forest")
    # Founder residual (2026-08-17): "This song needs to always be the 1st
    # song that plays in level one no matter what" — level01_theme.ogg is
    # listed FIRST, and AudioManager.play_playlist() now guarantees the first
    # entry starts the very first track deterministically (see
    # AudioManager._play_playlist_first for why: the picker used to be random
    # even on the opening call, which is exactly "a different song playing"
    # every time the game boots).
    # "This song must also feature in level 1" — level01_theme_oxbow.mp3
    # (founder-supplied "Oxbow Lake") added as a real rotation track.
    # "Remove this song completely!" — the old level01_theme_alt.ogg is
    # deleted from disk and dropped from this playlist.
    AudioManager.play_playlist(["res://src/assets/music/level01_theme.ogg", "res://src/assets/music/level01_theme_oxbow.mp3", "res://src/assets/music/lil_blunt_theme.mp3"])
    AudioManager.play_voice("stage1_intro")

## Task #23 — three routes per section (ground y=650, plats y=300..500):
##   SPEEDRUNNER: high one-way chain (x 850→1350) toward the Blaze Portal —
##     coin-rich but runs past the fly swarms; Down+Jump bails out anywhere.
##   CASUAL: the original authored ground/platform route, untouched.
##   EXPLORER: shimmer secret walls near the pit gaps (lore/tips/referral
##     codes, DIAMOND shards for wallet holders) + the Hall of Blaze alcove.
## Ladders double as escape routes out of the high-death pockets (the pit
## gaps at x≈800 and x≈2260 — exactly where the heatmap says players fall).
func _setup_depth_routes() -> void:
    # SPEEDRUNNER — ascending one-way chain with a coin trail (risk = reward).
    var oneway_positions := [Vector2(880, 480), Vector2(1060, 390), Vector2(1240, 300)]
    for pos: Vector2 in oneway_positions:
        var plat := preload("res://src/level/one_way_platform.tscn").instantiate()
        plat.global_position = pos
        add_child(plat)
        EntitySpawner.spawn("coin", pos + Vector2(0, -34), self)
        EntitySpawner.spawn("coin", pos + Vector2(34, -34), self)
    # Escape-route ladders out of the two deadliest pit approaches.
    #
    # Neither ladder set a custom top_exit_offset, so both fell back to the
    # generic default Vector2(0,-20) ("stand directly above my own x").
    # Ladder 1 (x=770) happens to land inside platform (750,350,120,20)'s
    # x-range [750,870] by coincidence, so it was never visibly broken.
    # Ladder 2 (x=2345) does NOT: the nearest platform is (2400,450,120,20),
    # whose left edge starts 55px to the right — topping out with the
    # default offset drops the player in open air short of the platform.
    # This is the confirmed "climb to the top of a ladder with a platform
    # and NOT land on it" bug (level_02's ladders already had this tuning;
    # level_01's never did). Offset computed the same way level_02's were:
    # target = (platform_x + width/2, platform_y - 20).
    var ladder1 := preload("res://src/level/ladder.tscn").instantiate()
    ladder1.global_position = Vector2(770, 350)
    ladder1.height = 300.0
    add_child(ladder1)

    var ladder2 := preload("res://src/level/ladder.tscn").instantiate()
    ladder2.global_position = Vector2(2345, 450)
    ladder2.height = 200.0
    ladder2.top_exit_offset = Vector2(115, -20)  # -> platform centre (2460, 430)
    add_child(ladder2)
    # EXPLORER — secret walls hugging the gap edges and the far quiet corner.
    for wall_pos: Vector2 in [Vector2(468, 586), Vector2(1368, 586), Vector2(2768, 586)]:
        var wall := preload("res://src/level/secret_wall.tscn").instantiate()
        wall.global_position = wall_pos
        add_child(wall)
    # Hall of Blaze — token-gated alcove at the level's far right, before the
    # boss trigger. Holders see the graffiti wall + weekly top-10 silhouettes.
    var hall := preload("res://src/level/hall_of_blaze.tscn").instantiate()
    hall.global_position = Vector2(3250, 648)
    add_child(hall)

func _setup_smoke_platforms() -> void:
    var platform_data := [
        {"pos": Vector2(650, 300), "dist": 80.0, "vert": false},
        {"pos": Vector2(1250, 350), "dist": 60.0, "vert": true},
        {"pos": Vector2(1900, 300), "dist": 100.0, "vert": false}
    ]
    for data in platform_data:
        var plat := preload("res://src/level/smoke_cloud_platform.tscn").instantiate()
        plat.global_position = data.pos
        plat.move_distance = data.dist
        plat.vertical = data.vert
        add_child(plat)

func _on_boss_trigger(body: Node2D) -> void:
    if body.is_in_group("player") and not _boss_arena_active:
        _boss_arena_active = true
        # NO ARENA SEAL for the Auditor (founder, 2026-08-04).
        #
        # The seal raises a World-layer wall at boss_arena.start_x (2800) to
        # stop the player fleeing. But the Auditor's own collision_mask is 13,
        # which includes bit 1 (World) — so that wall caged the BOSS too,
        # inside a 600px box between x=2800 and the far wall at x=3400. That
        # is precisely the founder's "the Auditor is still unable to move
        # beyond this point".
        #
        # His requirement is the opposite of a seal: "even if Lil Blunt runs
        # back to the beginning section of the game, The Auditor should be
        # able to chase him all the way through the stage". So this fight is
        # now a full-stage hunt — the player may retreat and the boss follows.
        # set_boss_background() correspondingly repaints the ENTIRE level.
        set_boss_background()
        ScreenShake.zoom_to(0.85, 0.5)
        AudioManager.set_reverb_profile("boss")
        var boss := preload("res://src/boss/auditor.tscn").instantiate()
        boss.global_position = boss_spawn.global_position
        add_child(boss)
        AudioManager.play_playlist(["res://src/assets/music/boss01_theme.ogg", "res://src/assets/music/boss01_theme_alt.ogg"])
        AudioManager.play_voice("boss1_intro")
