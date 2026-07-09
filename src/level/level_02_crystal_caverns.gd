extends LevelBase

var _boss_arena_active: bool = false

func _ready() -> void:
	level_data = preload("res://src/resources/level_02_data.tres")
	super()
	_setup_blaze_portal(Vector2(2100, 280), 2500, 2)
	AudioManager.play_music("res://src/assets/music/level02_theme.ogg")

func _on_boss_trigger(body: Node2D) -> void:
	if body.is_in_group("player") and not _boss_arena_active:
		_boss_arena_active = true
		set_boss_background()
		var boss := preload("res://src/boss/distributor.tscn").instantiate()
		boss.global_position = boss_spawn.global_position
		add_child(boss)
		AudioManager.play_music("res://src/assets/music/boss_theme.ogg")
