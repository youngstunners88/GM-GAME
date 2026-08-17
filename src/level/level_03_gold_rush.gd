extends LevelBase

var _boss_arena_active: bool = false

## Session 4: Fort Knox is now a full separate scene reached through a
## walk-into door (see level_02's twin change) — no in-level chamber, so the
## kill_zone_gaps registration is removed and the old drop pit is bridged.

func _ready() -> void:
	level_data = preload("res://src/resources/level_03_data.tres")
	super()
	_setup_blaze_portal(Vector2(2600, 300), 4000, 3)
	_setup_depth_routes()
	_setup_ambient_dust()
	AudioManager.set_reverb_profile("mine")
	AudioManager.play_playlist(["res://src/assets/music/level03_theme.ogg", "res://src/assets/music/level03_theme_alt.ogg", "res://src/assets/music/lil_blunt_theme.mp3"])
	AudioManager.play_voice("stage3_intro")

## Gold-dust motes drifting through the canyon light — the one atmosphere
## element the painted backdrop alone can't give (a static image doesn't
## move). Same CPUParticles2D + fx_dot.png pattern already used by Blaze
## Rush's speed trail, just placed as fixed world decorations instead of
## camera-attached, so there's no coupling to player/camera code and no risk
## of regressing either system. Spread across the level so the sense of
## "sun-baked, drifting dust" reads no matter where the player currently is.
func _setup_ambient_dust() -> void:
	var spots: Array[Vector2] = [
		Vector2(300, 200), Vector2(1100, 150), Vector2(1900, 180),
		Vector2(2600, 160), Vector2(3300, 200), Vector2(3900, 220),
	]
	for spot in spots:
		var dust := CPUParticles2D.new()
		dust.texture = load("res://src/assets/sprites/fx_dot.png")
		dust.position = spot
		dust.amount = 14
		dust.lifetime = 4.0
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = Vector2(220.0, 320.0)
		dust.direction = Vector2(0.3, -1.0)
		dust.spread = 25.0
		dust.initial_velocity_min = 8.0
		dust.initial_velocity_max = 22.0
		dust.gravity = Vector2.ZERO
		dust.scale_amount_min = 0.15
		dust.scale_amount_max = 0.4
		dust.color = Color(1.0, 0.82, 0.35, 0.22)
		add_child(dust)

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
	# MUST be a TYPED array. `linked_doors` is `Array[NodePath]`, and assigning
	# an untyped `[...]` literal to it does not convert — Godot REJECTS the
	# assignment at runtime with "Invalid assignment of property or key
	# 'linked_doors'". The plate therefore had NO linked doors: stepping on it
	# started nothing, and the Gold Rush gate it is supposed to open could
	# never be opened by it. It failed silently in a printed error nobody was
	# reading, which is why the stage's headline mechanic has been dead.
	var links: Array[NodePath] = [plate.get_path_to(gate)]
	plate.linked_doors = links
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
		# GoldMine protocol token on the gold lane (founder: "Lets have GoldMine
		# tokens for the 3rd stage of course"). Credits the HUD's GOLD row as
		# well as score — see crypto_coin.gd's protocol_credit.
		EntitySpawner.spawn("coin_goldmine", pos + Vector2(0, -76), self)
	# Ladder up to the timed gate's approach ledge (escape from the cart run).
	# Founder residual (2026-08-03): flagged "still ambiguous" last session.
	# Resolved by the same computation used for level_01/02's fixed ladders:
	# nearest platform is Vector4(1480,420,120,20) — top_y=350 with the
	# default offset (0,-20) lands at (1465,330), 15px short of the
	# platform's left edge (1480) AND 90px above its surface (420). Target =
	# (platform_x + width/2, platform_y - 20) = (1540, 400).
	var ladder := preload("res://src/level/ladder.tscn").instantiate()
	ladder.global_position = Vector2(1465, 350)
	ladder.height = 300.0
	ladder.top_exit_offset = Vector2(75, 50)  # -> platform centre (1540, 400)
	add_child(ladder)
	# EXPLORER — secret walls tucked in the PITS (the diggings), not on the flat
	# claim roads. S11 layout redesign made the main ground continuous where it
	# used to have gaps, so the old on-ground wall x's would have become
	# chest-high blocks on a flat run (a walk-block the founder is sensitive to).
	# These sit at pit x's, y≈624 — the proven pit-edge pattern (like the old
	# x=868 that lived in a gap): smashable while crossing a gap, never blocking
	# a grounded walk. Verified by tests/s11_stage3_walkpath_test.gd.
	for wall_pos: Vector2 in [Vector2(620, 624), Vector2(1260, 624), Vector2(3620, 624)]:
		var wall := preload("res://src/level/secret_wall.tscn").instantiate()
		wall.global_position = wall_pos
		add_child(wall)
	# GOLD RUSH RESERVE — token-gated community room before the boss arena.
	# RENAMED from "— THE FORT KNOX VAULT —" (Part B): the founder's locked
	# design assigns the name "Fort Knox" to the new PLAYABLE downward vault
	# below, so this wallet-gated spectacle alcove (Hall-of-Blaze pattern, a
	# skin via room_title — L1 keeps "THE HALL OF BLAZE") takes a distinct name
	# to avoid two "Fort Knox" labels in one level. Grok + Fable both flagged
	# the collision; the spectacle room yields the name, not the playable vault.
	# x=3420 sits on the last ground segment before the final pit + boss wall
	# (segment ends at 3480, wall starts 3700) — NOT in the gap between them.
	var reserve := preload("res://src/level/hall_of_blaze.tscn").instantiate()
	reserve.room_title = "— THE GOLD RUSH RESERVE —"
	reserve.global_position = Vector2(3420, 648)
	add_child(reserve)
	# FORT KNOX (session 4) — a FULL SEPARATE ENVIRONMENT reached by walking into
	# the vault door, like Blaze Rush. The old 2620-2760 drop pit that the door
	# footing needs is now filled by a real `ground_segment` in level_03_data.tres
	# (Vector4(2620,650,140,70)), so it renders through LevelBase._create_platform
	# with the same dark body + chain-tile + gold lip as every other platform.
	#
	# Founder (Stage 3 clutter pass, 2026-08-16): the old script-built bridge was
	# a bare brown ColorRect box bypassing that construction — one of the flat
	# "trashy/cheap" rectangles he red-circled. Replaced with data-driven ground
	# so it reads as built terrain, not a dropped-in block. The vault door below
	# is unchanged and still sits at (2690,650).
	var knox_door := preload("res://src/level/vault_door.tscn").instantiate()
	knox_door.protocol = "gold"
	knox_door.realm_path = "res://src/level/fort_knox_realm.tscn"
	knox_door.global_position = Vector2(2690, 650)
	add_child(knox_door)

func _on_boss_trigger(body: Node2D) -> void:
	if body.is_in_group("player") and not _boss_arena_active:
		_boss_arena_active = true
		# Raise the entry wall behind the player once they're actually inside.
		# It is NOT built at level load — doing so sealed the boss off entirely.
		arm_boss_arena_seal()
		set_boss_background()
		ScreenShake.zoom_to(0.85, 0.5)
		AudioManager.set_reverb_profile("boss")
		var boss := preload("res://src/boss/claim_jumper.tscn").instantiate()
		boss.global_position = boss_spawn.global_position
		# HAND HIM THE ARENA BOX BEFORE add_child, so the clamp is live on his
		# very first physics frame — the same pre-add contract level_02 uses for
		# the Distributor.
		#
		# Founder: the Claim Jumper "dies by falling off the ledge... the game
		# cannot proceed". He had no bounds of any kind; the moment his stalk
		# carried him past a platform lip he fell out of the world and the fight
		# became unwinnable. The 90px inset matches level_02's, keeping him off
		# the arena's own walls.
		# RAW arena bounds — the boss insets by its own half-body now (see
		# claim_jumper._clamp_to_arena). The old 90px inset was applied to the
		# boss's ORIGIN, which is its body's top-left, so it shifted his
		# reachable range 40px east AND stole 130px of chase room at each end.
		var arena: Dictionary = level_data.boss_arena
		var bx0: float = float(arena.get("start_x", 0.0))
		var bx1: float = float(arena.get("end_x", 0.0))
		var by: float = float(boss_spawn.global_position.y)
		boss.arena_min = Vector2(bx0, by - 400.0)
		# Floor clamp sits a little BELOW the spawn line so a legitimate hop
		# landing is never snagged, but a fall into the void is caught.
		boss.arena_max = Vector2(bx1, by + 60.0)
		add_child(boss)
		AudioManager.play_playlist(["res://src/assets/music/boss03_theme.ogg", "res://src/assets/music/boss03_theme_alt.ogg"])
		AudioManager.play_voice("boss3_intro")
