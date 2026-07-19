extends LevelBase

var _boss_arena_active: bool = false

func _ready() -> void:
    level_data = preload("res://src/resources/level_01_data.tres")
    super()
    _setup_smoke_platforms()
    _setup_blaze_portal(Vector2(1450, 250), 1500, 1)
    # Hidden door to the Chill Lounge, tucked up on a high ledge.
    var door := preload("res://src/level/secret_door.tscn").instantiate()
    door.global_position = Vector2(2350, 250)
    add_child(door)
    _setup_depth_routes()
    AudioManager.set_reverb_profile("forest")
    AudioManager.play_playlist(["res://src/assets/music/level01_theme.ogg", "res://src/assets/music/level01_theme_alt.ogg", "res://src/assets/music/lil_blunt_theme.mp3"])
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
    for lad: Array in [[Vector2(770, 350), 300.0], [Vector2(2345, 450), 200.0]]:
        var ladder := preload("res://src/level/ladder.tscn").instantiate()
        ladder.global_position = lad[0]
        ladder.height = lad[1]
        add_child(ladder)
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
        set_boss_background()
        ScreenShake.zoom_to(0.85, 0.5)
        AudioManager.set_reverb_profile("boss")
        var boss := preload("res://src/boss/auditor.tscn").instantiate()
        boss.global_position = boss_spawn.global_position
        add_child(boss)
        AudioManager.play_playlist(["res://src/assets/music/boss01_theme.ogg", "res://src/assets/music/boss01_theme_alt.ogg"])
        AudioManager.play_voice("boss1_intro")
