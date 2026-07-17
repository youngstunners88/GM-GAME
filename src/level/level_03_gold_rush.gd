extends LevelBase

var _boss_arena_active: bool = false

func _ready() -> void:
	level_data = preload("res://src/resources/level_03_data.tres")
	super()
	_setup_blaze_portal(Vector2(2600, 300), 4000, 3)
	AudioManager.set_reverb_profile("mine")
	AudioManager.play_playlist(["res://src/assets/music/level03_theme.ogg", "res://src/assets/music/level03_theme_alt.ogg", "res://src/assets/music/lil_blunt_theme.mp3"])
	AudioManager.play_voice("stage3_intro")

func _on_boss_trigger(body: Node2D) -> void:
	if body.is_in_group("player") and not _boss_arena_active:
		_boss_arena_active = true
		set_boss_background()
		ScreenShake.zoom_to(0.85, 0.5)
		AudioManager.set_reverb_profile("boss")
		var boss := preload("res://src/boss/claim_jumper.tscn").instantiate()
		boss.global_position = boss_spawn.global_position
		add_child(boss)
		AudioManager.play_playlist(["res://src/assets/music/boss03_theme.ogg", "res://src/assets/music/boss03_theme_alt.ogg"])
		AudioManager.play_voice("boss3_intro")
