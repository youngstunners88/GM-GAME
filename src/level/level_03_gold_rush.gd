extends LevelBase

var _boss_arena_active: bool = false

func _ready() -> void:
	level_data = preload("res://src/resources/level_03_data.tres")
	super()
	_setup_blaze_portal(Vector2(2600, 300), 4000, 3)
	_setup_depth_routes()
	AudioManager.set_reverb_profile("mine")
	AudioManager.play_playlist(["res://src/assets/music/level03_theme.ogg", "res://src/assets/music/level03_theme_alt.ogg", "res://src/assets/music/lil_blunt_theme.mp3"])
	AudioManager.play_voice("stage3_intro")

## Task #23 extension — Gold Rush depth (LEVEL_23_EXTEND.md):
##   SPEEDRUNNER: the TIMED-GATE run — a pressure-plate timed door guards a
##     golden one-way shortcut lane; miss the window and you take the long way
##     (mine-cart Casual route below). Gold rush = racing the clock.
##   CASUAL: the authored floor + mine-cart route, untouched.
##   EXPLORER: secret walls in the diggings + the FORT KNOX VAULT — the
##     token-gated community room (Hall-of-Blaze pattern, gold plated) just
##     before the Claim Jumper's arena.
func _setup_depth_routes() -> void:
	# SPEEDRUNNER — timed gate (reuses the existing timed_door mechanic)
	# opening onto a golden one-way lane with a rich coin trail.
	var gate := preload("res://src/level/timed_door.tscn").instantiate()
	gate.name = "GoldGate"
	gate.global_position = Vector2(1520, 530)
	gate.open_duration = 4.0
	add_child(gate)
	# The plate that starts the clock sits a sprint away — step on it, then
	# RACE to the gate before it slams (that's the Gold Rush).
	var plate := preload("res://src/level/pressure_plate.tscn").instantiate()
	plate.global_position = Vector2(1180, 630)
	add_child(plate)
	plate.linked_doors = [plate.get_path_to(gate)]
	var gold_lane := [Vector2(1700, 460), Vector2(1900, 400), Vector2(2100, 340), Vector2(2300, 400)]
	for pos: Vector2 in gold_lane:
		var plat := preload("res://src/level/one_way_platform.tscn").instantiate()
		plat.global_position = pos
		add_child(plat)
		var deck := plat.get_node_or_null("Deck")
		if deck:
			deck.color = Color(0.95, 0.8, 0.3, 1.0)  # gold
		EntitySpawner.spawn("coin", pos + Vector2(-20, -34), self)
		EntitySpawner.spawn("coin", pos + Vector2(20, -34), self)
	# Ladder up to the timed gate's approach ledge (escape from the cart run).
	var ladder := preload("res://src/level/ladder.tscn").instantiate()
	ladder.global_position = Vector2(1465, 350)
	ladder.height = 300.0
	add_child(ladder)
	# EXPLORER — secret walls in the old diggings.
	for wall_pos: Vector2 in [Vector2(868, 586), Vector2(2468, 586), Vector2(3068, 586)]:
		var wall := preload("res://src/level/secret_wall.tscn").instantiate()
		wall.global_position = wall_pos
		add_child(wall)
	# FORT KNOX VAULT — token-gated community room before the boss arena.
	var vault := preload("res://src/level/hall_of_blaze.tscn").instantiate()
	vault.room_title = "— THE FORT KNOX VAULT —"
	vault.global_position = Vector2(3550, 648)
	add_child(vault)

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
