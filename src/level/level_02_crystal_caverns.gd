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
		# SOLANA, not generic gold (founder: "in level 2 the tokens dont look
		# like Solana logos"). These plain "coin" pickups on the crystal
		# one-way chain are the yellow coins visible in his screenshot — the
		# level's own .tres only ever placed 2 coin_sol, so converting the
		# trail is what actually changes what he sees while playing.
		EntitySpawner.spawn("coin_sol", pos + Vector2(0, -34), self)
		# DIAMONDS token ALONGSIDE the Solana coin, never instead of it —
		# founder: "that doesnt replace the current Solana coins in stage 2".
		# Offset right so the pair reads as two distinct pickups rather than
		# one overlapping smudge (44px triggers need ~48px of separation).
		EntitySpawner.spawn("coin_diamonds", pos + Vector2(52, -34), self)
	# VERTICAL SHAFTS — full-height ladders out of the two deadliest drops.
	#
	# top_exit_offset is NOT optional here (the default Vector2(0,-20) assumes
	# a platform directly above the ladder's own X position). Neither shaft
	# has one:
	#   ladder 1 (x=1420) — nearest platform is Vector4(1500,300,100,20),
	#     80px clear of the ladder's right edge, at the SAME y=300 as the
	#     ladder top. Default offset left the top-out point floating in open
	#     air over the pit; the player fell straight back in. This was the
	#     reported Stage 2 progression block.
	#   ladder 2 (x=3060) — nearest platform is Vector4(3100,300,100,20):
	#     both an X gap (~65px) AND a 50px Y mismatch, since this ladder's
	#     top (y=250) sits above the platform's surface (y=300).
	# Offsets below land the player centered on each platform, y matching the
	# "stand 20px above the surface" convention the default offset already
	# established for the aligned case.
	var ladder1 := preload("res://src/level/ladder.tscn").instantiate()
	ladder1.global_position = Vector2(1420, 300)
	ladder1.height = 350.0
	ladder1.top_exit_offset = Vector2(130, -20)  # -> platform centre (1550, 280)
	add_child(ladder1)

	var ladder2 := preload("res://src/level/ladder.tscn").instantiate()
	ladder2.global_position = Vector2(3060, 250)
	ladder2.height = 400.0
	ladder2.top_exit_offset = Vector2(90, 30)  # -> platform centre (3150, 280)
	add_child(ladder2)
	# EXPLORER — secret walls hugging the pit edges (lore/tips/shards).
	for wall_pos: Vector2 in [Vector2(468, 586), Vector2(1968, 586), Vector2(3468, 586)]:
		var wall := preload("res://src/level/secret_wall.tscn").instantiate()
		wall.global_position = wall_pos
		add_child(wall)

func _on_boss_trigger(body: Node2D) -> void:
	if body.is_in_group("player") and not _boss_arena_active:
		_boss_arena_active = true
		# Raise the entry wall behind the player once they're actually inside.
		# It is NOT built at level load — doing so sealed the boss off entirely.
		arm_boss_arena_seal()
		set_boss_background()
		ScreenShake.zoom_to(0.85, 0.5)
		AudioManager.set_reverb_profile("boss")
		var boss := preload("res://src/boss/distributor.tscn").instantiate()
		boss.global_position = boss_spawn.global_position
		# The Distributor FLIES (founder E2/E4). Hand him the arena box before
		# add_child so his clamp is live on his very first physics frame — he
		# must never be able to drift into a trench and vanish. Set as plain
		# properties BEFORE add_child, the same pre-add contract the carts and
		# the big axe use.
		var arena: Dictionary = level_data.boss_arena
		var ax0: float = float(arena.get("start_x", 0.0)) + 90.0
		var ax1: float = float(arena.get("end_x", 0.0)) - 90.0
		var ay: float = float(boss_spawn.global_position.y)
		boss.arena_min = Vector2(ax0, ay - 320.0)
		boss.arena_max = Vector2(ax1, ay + 120.0)
		add_child(boss)
		AudioManager.play_playlist(["res://src/assets/music/boss02_theme.ogg", "res://src/assets/music/boss02_theme_alt.ogg"])
		AudioManager.play_voice("boss2_intro")
