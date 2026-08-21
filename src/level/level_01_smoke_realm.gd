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
    # Founder (LEVEL1_MUSIC_ORDER_BOSS1_SIZE_CARTS_CHASE, 2026-08-18): "Song A
    # must always be the first song that plays in Level 1, no matter what
    # (cold start, machine on, etc.)... Song B must also feature in Level 1
    # ... Song C must be removed completely." level01_theme_always_first.mp3
    # is the founder-supplied track locked to position 0 with force_first=true
    # (see AudioManager.play_playlist) so it is never left to the shuffle.
    # level01_theme_oxbow.mp3 is the founder's earlier "Oxbow Lake" supply,
    # already confirmed in rotation. level01_theme_alt.ogg (the track the
    # founder asked removed) is deleted from the project entirely, not just
    # dropped from this array.
    AudioManager.play_playlist([
        "res://src/assets/music/level01_theme_always_first.mp3",
        "res://src/assets/music/level01_theme_oxbow.mp3",
        "res://src/assets/music/level01_theme.ogg",
        "res://src/assets/music/lil_blunt_theme.mp3",
    ], true)
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
    # Ladder 1 (x=770) happens to land inside platform (750,350,120,20)'s
    # x-range [750,870] by coincidence, so it was never visibly broken.
    var ladder1 := preload("res://src/level/ladder.tscn").instantiate()
    ladder1.global_position = Vector2(770, 350)
    ladder1.height = 300.0
    add_child(ladder1)

    # Ladder 2 (x=2345). Founder, 2026-08-21 (final presentation residual):
    # circled platform (2400,450,120,20) and demanded it be REMOVED outright
    # — a headless real-physics probe confirmed the Auditor was permanently
    # wall-stuck at x=2520 (that platform's exact right edge) while chasing a
    # fleeing player back through the level, exactly this founder's repeated
    # complaint. This ladder used to start AT that platform's height (450)
    # and its top-exit was tuned to land ON it — both now dangling on a
    # removed object. Re-grounded to climb from the real floor (y=650, this
    # stretch's ground segment is continuous, so nothing is lost) up to the
    # SAME absolute top height as before (250), and reverted to the generic
    # default top-exit offset since there is no longer a specific platform to
    # target — the player tops out near the high coin/ring collectibles and
    # falls back to the (still continuous) ground below, same as any ladder
    # with no adjacent platform.
    var ladder2 := preload("res://src/level/ladder.tscn").instantiate()
    ladder2.global_position = Vector2(2345, 650)
    ladder2.height = 400.0
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
