extends LevelBase

var _boss_arena_active: bool = false

func _ready() -> void:
    level_data = preload("res://src/resources/level_01_data.tres")
    super()
    _setup_smoke_platforms()
    _setup_blaze_portal(Vector2(1450, 250), 1500, 1)
    AudioManager.play_music("res://src/assets/music/level01_theme.ogg")

func _setup_background() -> void:
    pass  # Use parallax from level_data

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
        var boss := preload("res://src/boss/auditor.tscn").instantiate()
        boss.global_position = boss_spawn.global_position
        add_child(boss)
        AudioManager.play_music("res://src/assets/music/boss_theme.ogg")
