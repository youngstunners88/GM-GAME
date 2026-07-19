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
	_setup_depth_routes()
	AudioManager.set_reverb_profile("cave")
	AudioManager.play_playlist(["res://src/assets/music/level02_theme.ogg", "res://src/assets/music/level02_theme_alt.ogg", "res://src/assets/music/lil_blunt_theme.mp3"])
	AudioManager.play_voice("stage2_intro")

## Task #23 extension — Crystal Caverns depth (LEVEL_23_EXTEND.md):
##   SPEEDRUNNER: crystal one-way chain rising through the mid-cavern
##     (mirror-polish cyan decks, coin trails) toward the Blaze Portal.
##   CASUAL: the authored floor route, untouched.
##   EXPLORER: shimmer secret walls beside the deepest pit gaps.
## VERTICAL SHAFTS: this cave is tall — two long ladders run full-height at
## the deadliest drops (x≈1450 gap, x≈3050 gap) as climbable escape shafts.
## DIAMONDS-holder spectacle already lives in the Distributor boss + shard
## drops from secret walls (20% with a wallet — extra on-theme here).
func _setup_depth_routes() -> void:
	# SPEEDRUNNER — crystal one-ways, mirrored left/right around the shaft.
	var crystal_oneways := [Vector2(1050, 470), Vector2(1250, 380), Vector2(1450, 290), Vector2(1650, 380), Vector2(1850, 470)]
	for pos: Vector2 in crystal_oneways:
		var plat := preload("res://src/level/one_way_platform.tscn").instantiate()
		plat.global_position = pos
		add_child(plat)
		var deck := plat.get_node_or_null("Deck")
		if deck:
			deck.color = Color(0.55, 0.85, 1.0, 1.0)  # crystal cyan
		EntitySpawner.spawn("coin", pos + Vector2(0, -34), self)
	# VERTICAL SHAFTS — full-height ladders out of the two deadliest drops.
	for lad: Array in [[Vector2(1420, 300), 350.0], [Vector2(3060, 250), 400.0]]:
		var ladder := preload("res://src/level/ladder.tscn").instantiate()
		ladder.global_position = lad[0]
		ladder.height = lad[1]
		add_child(ladder)
	# EXPLORER — secret walls hugging the pit edges (lore/tips/shards).
	for wall_pos: Vector2 in [Vector2(468, 586), Vector2(1968, 586), Vector2(3468, 586)]:
		var wall := preload("res://src/level/secret_wall.tscn").instantiate()
		wall.global_position = wall_pos
		add_child(wall)

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
