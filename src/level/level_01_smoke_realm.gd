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
    AudioManager.set_reverb_profile("forest")
    AudioManager.play_playlist(["res://src/assets/music/level01_theme.ogg", "res://src/assets/music/level01_theme_alt.ogg", "res://src/assets/music/lil_blunt_theme.mp3"])
    AudioManager.play_voice("stage1_intro")

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
