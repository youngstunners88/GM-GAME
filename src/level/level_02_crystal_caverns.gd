extends LevelBase

var _boss_arena_active: bool = false

func _ready() -> void:
	level_data = preload("res://src/resources/level_02_data.tres")
	super()
	# Cave level — Lil Blunt wears his miner gear here.
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		p.set_outfit(Player.Outfit.MINER)
	_setup_blaze_portal(Vector2(2100, 280), 2500, 2)
	AudioManager.set_reverb_profile("cave")
	AudioManager.play_playlist(["res://src/assets/music/level02_theme.ogg", "res://src/assets/music/level02_theme_alt.ogg", "res://src/assets/music/lil_blunt_theme.mp3"])
	AudioManager.play_voice("stage2_intro")

func _on_boss_trigger(body: Node2D) -> void:
	if body.is_in_group("player") and not _boss_arena_active:
		_boss_arena_active = true
		set_boss_background()
		ScreenShake.zoom_to(0.85, 0.5)
		AudioManager.set_reverb_profile("boss")
		var boss := preload("res://src/boss/distributor.tscn").instantiate()
		boss.global_position = boss_spawn.global_position
		add_child(boss)
		AudioManager.play_playlist(["res://src/assets/music/boss02_theme.ogg", "res://src/assets/music/boss02_theme_alt.ogg"])
		AudioManager.play_voice("boss2_intro")
