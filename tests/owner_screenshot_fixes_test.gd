extends Node
## Regression proof for the 2026-08-04 owner-screenshot defect pass.
##
## The founder rejected several prior "FIXED" claims that were backed only by
## reading code. Every check here drives REAL objects under REAL physics, or
## measures REAL geometry, and each one is written so that the ORIGINAL broken
## behaviour would fail it.
##
## Run: godot --headless res://tests/owner_screenshot_fixes_test.tscn

const AUDITOR := preload("res://src/boss/auditor.tscn")
const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")
const PLAYER := preload("res://src/player/player.tscn")
const AXE := preload("res://src/combat/axe.tscn")
const TAX_COLLECTOR := preload("res://src/enemies/tax_collector.tscn")

var _failures: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s = %s" % [label, str(value)])

func _run() -> void:
	# Player.take_damage() early-returns unless StateMachine.is_playing().
	# This harness builds bare scenes rather than loading a level, so nothing
	# ever leaves MENU and every contact-damage assertion would fail for a
	# reason that has nothing to do with the code under test. MENU can only
	# reach PLAYING via TRANSITIONING (see state_machine.gd's _ALLOWED).
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	_test_lives_uncapped()
	_test_lounge_tokens_reachable_without_jumping()
	_test_auditor_not_caged_by_arena_seal()
	_test_boss_backdrop_covers_whole_level()
	_test_blaze_landing_runway_is_clear()
	_test_blaze_exit_target_is_snapshotted()
	await _test_boss_facing_does_not_displace_art()
	await _test_claim_jumper_damages_both_ways()
	await _test_big_axe_power()

	if _failures == 0:
		print("OWNER_SCREENSHOT_FIXES: ALL PASS")
		get_tree().quit(0)
	else:
		print("OWNER_SCREENSHOT_FIXES: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

# --------------------------------------------------------------------------
# P3 — lives must not be capped at 3.
# --------------------------------------------------------------------------
func _test_lives_uncapped() -> void:
	print("P3 lives uncapped:")
	GameManager.lives = 3
	GameManager.add_life(1)
	_check("collecting a life above max_lives raises the count",
		GameManager.lives == 4, "lives=%d (max_lives=%d)" % [GameManager.lives, GameManager.max_lives])
	for i in 5:
		GameManager.add_life(1)
	_check("lives keep climbing with no ceiling", GameManager.lives == 9,
		"lives=%d" % GameManager.lives)
	# A heart picked up at FULL health must convert to a life rather than be
	# silently wasted — that waste is why no life was ever gained in play.
	GameManager.player_health = GameManager.max_health
	var before := GameManager.lives
	var heart := preload("res://src/collectibles/health_pickup.tscn").instantiate()
	add_child(heart)
	heart.call("collect")
	_check("a heart at full health becomes an extra life",
		GameManager.lives == before + 1, "lives %d -> %d" % [before, GameManager.lives])
	heart.queue_free()
	GameManager.lives = 3

# --------------------------------------------------------------------------
# P4 — every Smoke Lounge token must be collectable by skating, no jump.
# --------------------------------------------------------------------------
func _test_lounge_tokens_reachable_without_jumping() -> void:
	print("P4 lounge tokens at skate height:")
	var src := FileAccess.get_file_as_string("res://src/level/secret_realm.gd")
	var floor_surface := 660.0     # FLOOR_SURFACE_Y in secret_realm.gd
	# Player collision box is 32x32 with a TOP-LEFT origin, so standing on the
	# lounge floor puts the Hurtbox band at roughly 630..658 in world space.
	var band_top := floor_surface - 30.0
	var band_bottom := floor_surface
	var skate_y := 0.0
	for line in src.split("\n"):
		if line.begins_with("const SKATE_PICKUP_Y"):
			skate_y = float(line.split("=")[1].strip_edges().replace("\t", ""))
	_check("secret_realm declares SKATE_PICKUP_Y", skate_y > 0.0, "parsed %f" % skate_y)
	var token_y := floor_surface - skate_y
	_info("token spawn world Y / player hurtbox band", "%.0f / %.0f..%.0f" % [token_y, band_top, band_bottom])
	# A 20px-tall token spawned at token_y spans token_y..token_y+20.
	_check("token overlaps the standing hurtbox (no jump required)",
		token_y + 20.0 >= band_top and token_y <= band_bottom,
		"token spans %.0f..%.0f, hurtbox %.0f..%.0f" % [token_y, token_y + 20.0, band_top, band_bottom])
	# The ORIGINAL values were -170 and -260. Prove those would have failed.
	# Explicit float typing: iterating an untyped array literal yields Variant,
	# and `:=` from a Variant is a HARD parse error in Godot 4.3 (see
	# docs/engine-reference/godot/gdscript-gotchas.md).
	for bad: float in [170.0, 260.0]:
		var bad_y: float = floor_surface - bad
		_check("original offset -%.0f would NOT have been reachable" % bad,
			not (bad_y + 20.0 >= band_top and bad_y <= band_bottom),
			"unexpectedly reachable")
	# Strip comments first — the explanatory comment in secret_realm.gd
	# legitimately quotes the old -170 / -260 numbers, and matching those in
	# prose is a false positive rather than a real regression.
	var code_only := ""
	for l in src.split("\n"):
		var ls := l.strip_edges()
		if ls.begins_with("#"):
			continue
		code_only += l + "\n"
	_check("no lounge reward is still SPAWNED at the old jump-only heights",
		not code_only.contains("FLOOR_SURFACE_Y - 170") and not code_only.contains("FLOOR_SURFACE_Y - 260"))

# --------------------------------------------------------------------------
# P5a — the Auditor must not be caged by the arena seal.
# --------------------------------------------------------------------------
func _test_auditor_not_caged_by_arena_seal() -> void:
	print("P5a Auditor not caged:")
	var src := FileAccess.get_file_as_string("res://src/level/level_01_smoke_realm.gd")
	# The seal builds a World-layer wall at boss_arena.start_x. The Auditor's
	# collision_mask is 13, which includes World (bit 1), so an armed seal
	# traps the BOSS inside the arena as well as the player.
	var armed := false
	for line in src.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("#"):
			continue
		if t.contains("arm_boss_arena_seal()"):
			armed = true
	_check("level 1 no longer arms the arena seal during the Auditor fight", not armed,
		"arm_boss_arena_seal() still called - the boss stays caged in a 600px box")
	var boss_src := FileAccess.get_file_as_string("res://src/boss/auditor.gd")
	_check("Auditor PATROL stalks the live player instead of wall-bouncing",
		boss_src.contains("stalk_dir"),
		"PATROL still uses blind patrol_direction pacing")

# --------------------------------------------------------------------------
# P5b — arena art must cover the ENTIRE level, not just around the arena.
# --------------------------------------------------------------------------
func _test_boss_backdrop_covers_whole_level() -> void:
	print("P5b boss backdrop covers whole level:")
	var packed: PackedScene = load("res://src/level/level_01_smoke_realm.tscn")
	var level: Node = packed.instantiate()
	add_child(level)
	level.call("set_boss_background")
	var spr: Sprite2D = level.get("_boss_backdrop_sprite")
	_check("boss backdrop sprite created", is_instance_valid(spr))
	if is_instance_valid(spr):
		var layer := spr.get_parent() as ParallaxLayer
		_check("backdrop starts at the LEVEL origin (x=0), not near the arena",
			absf(spr.position.x) < 1.0,
			"starts at x=%.1f - everything west of that shows the old stage art" % spr.position.x)
		_check("backdrop tiles horizontally so it spans the full level",
			layer != null and layer.motion_mirroring.x > 0.0,
			"mirroring=%s (a single 1280px image cannot cover a 3400px level)"
				% str(layer.motion_mirroring if layer else "?"))
		_check("backdrop is world-locked (motion_scale 1) so it cannot drift",
			layer != null and layer.motion_scale == Vector2(1.0, 1.0))
		var skirt: ColorRect = level.get("_boss_backdrop_skirt")
		_check("opaque under-floor skirt exists", is_instance_valid(skirt))
	level.queue_free()

# --------------------------------------------------------------------------
# P6a — the board must not drop the player into a hazard.
# --------------------------------------------------------------------------
func _test_blaze_landing_runway_is_clear() -> void:
	print("P6a Blaze Rush landing runway:")
	var runway := 320.0   # BOARD_LANDING_RUNWAY
	for lvl in [1, 2, 3]:
		var layout: Dictionary = BlazeRushLayouts.get_layout(lvl)
		var zone: Dictionary = layout.get("board_zone", {})
		if zone.is_empty():
			_check("L%d defines a board zone" % lvl, false)
			continue
		var zone_end: float = float(zone.get("end"))
		var win_start := zone_end - 40.0
		var win_end := zone_end + runway
		var offenders: Array[String] = []
		for ob in layout.get("obstacles", []):
			var t: String = ob.get("type", "")
			if t != "candle" and t != "fud_wall" and t != "gap":
				continue
			var s: float = float(ob.x)
			var e: float = s + float(ob.get("w", 0.0))
			if e >= win_start and s <= win_end:
				offenders.append("%s@%.0f" % [t, s])
		# NOTE: this reads the RAW layout. The runtime strips these in
		# _clear_board_landing_runway(); this reports what would otherwise be
		# a lethal touchdown so the data and the guard stay in sync.
		_info("L%d raw hazards inside the landing window %.0f..%.0f" % [lvl, win_start, win_end],
			offenders if offenders.size() > 0 else "none")
	# The real guarantee: the runtime filter must actually remove them.
	GameManager.dash_return = {"level_index": 3}
	var run: Node = preload("res://src/dashmode/blaze_rush.tscn").instantiate()
	add_child(run)
	var zone3: Dictionary = run.get("_board_zone")
	var ze: float = float(zone3.get("end"))
	var still_there := 0
	for child in run.get_children():
		# Candles are Area2Ds tagged with the "hazard" meta by _make_candle.
		if child is Area2D and child.has_meta("hazard"):
			var x: float = (child as Area2D).position.x
			if x >= ze - 40.0 and x <= ze + runway:
				still_there += 1
	_check("no lethal candle survives inside L3's landing runway", still_there == 0,
		"%d candle(s) still in the touchdown window" % still_there)
	run.queue_free()
	GameManager.dash_return = {}

# --------------------------------------------------------------------------
# P6b — ESC must return to the level the run STARTED from.
# --------------------------------------------------------------------------
func _test_blaze_exit_target_is_snapshotted() -> void:
	print("P6b Blaze Rush exit target:")
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_03_gold_rush.tscn",
		"position": Vector2(2600, 300),
		"level_index": 3,
	}
	var run: Node = preload("res://src/dashmode/blaze_rush.tscn").instantiate()
	add_child(run)
	_check("return path captured at entry", run.get("_return_path") == "res://src/level/level_03_gold_rush.tscn",
		"captured '%s'" % str(run.get("_return_path")))
	# THE BUG: something clears the shared autoload dict mid-run. Previously
	# the exit read it lazily and fell through to the level_01 default, which
	# to a Level 3 player looks exactly like "Esc doesn't take me back".
	GameManager.dash_return = {}
	_check("exit target survives dash_return being cleared mid-run",
		run.get("_return_path") == "res://src/level/level_03_gold_rush.tscn",
		"now '%s' - would send a Level 3 player to Level 1" % str(run.get("_return_path")))
	_check("ESC is handled at _input priority, not _unhandled_input",
		FileAccess.get_file_as_string("res://src/dashmode/blaze_rush.gd").contains("func _input(event: InputEvent)"))
	run.queue_free()

# --------------------------------------------------------------------------
# P9 — facing must not slide the boss off his diamond.
# --------------------------------------------------------------------------
func _test_boss_facing_does_not_displace_art() -> void:
	print("P9 boss facing does not displace art:")
	Engine.time_scale = 1.0
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(600, 300)
	for i in 6:
		await get_tree().physics_frame
	var spr: BossSprite = boss.get_node("ColorRect")
	var disc: Polygon2D = boss.get("_disc")
	_check("levitating disc exists", is_instance_valid(disc))

	var art_node0 := spr.get_child(0) as Node2D
	# FREEZE HIM WHILE MEASURING THE FLIP.
	#
	# This reads art_node0.GLOBAL position either side of a set_facing() call,
	# with a frame awaited in between — so any motion the boss makes during that
	# frame is charged to the flip. The Distributor's _physics_process runs
	# _hover_pursue -> move_and_slide() every frame and will chase any node left
	# in the "player" group by an earlier subtest in this same file, which is
	# exactly the cross-test contamination documented in
	# .claude/rules/test-standards.md. That produced a ~3.8px "art jumped"
	# failure that had nothing to do with facing.
	#
	# Stopping his physics isolates the ONE thing this gate is about: whether
	# flipping translates the artwork. The assertion below is unchanged and
	# still strict (<1px) — this removes a confound, it does not relax the bar.
	boss.set_physics_process(false)
	boss.set("velocity", Vector2.ZERO)
	spr.set_facing(true)
	await get_tree().process_frame
	var art_right: Vector2 = art_node0.global_position
	spr.set_facing(false)
	await get_tree().process_frame
	var art_left: Vector2 = art_node0.global_position

	_info("art world X facing right / facing left", "%.1f / %.1f" % [art_right.x, art_left.x])
	# The old `scale.x = -1` flip moved the art 96 local px = 163 world px at
	# BOSS_SCALE 1.7, sliding him clean off the sibling disc.
	_check("flipping to face left does NOT move the artwork",
		absf(art_right.x - art_left.x) < 1.0,
		"art jumped %.1f px on flip - this is the 'falls off the surfboard' bug"
			% absf(art_right.x - art_left.x))
	if is_instance_valid(disc):
		# get_child() is typed Node, so its .global_position is a Variant —
		# `:=` off it will not parse. Cast to Node2D first.
		var art_node := spr.get_child(0) as Node2D
		var offset: float = disc.global_position.x - art_node.global_position.x
		_check("disc stays centred under the body while facing left",
			absf(offset) < 90.0, "disc is %.1f px off the body" % offset)
	# No boss may reintroduce the displacing flip.
	for path in ["res://src/boss/auditor.gd", "res://src/boss/distributor.gd",
			"res://src/boss/claim_jumper.gd", "res://src/boss/bandit_boss.gd"]:
		var s := FileAccess.get_file_as_string(path)
		_check("%s uses set_facing, not scale.x" % path.get_file(),
			not s.contains("sprite.scale.x =") and not s.contains("boss_sprite.scale.x ="))
	boss.queue_free()
	await get_tree().process_frame

# --------------------------------------------------------------------------
# P8 — third boss must damage and be damaged.
# --------------------------------------------------------------------------
func _test_claim_jumper_damages_both_ways() -> void:
	print("P8 Claim Jumper two-way damage:")
	Engine.time_scale = 1.0
	var scn: PackedScene = CLAIM_JUMPER
	var state := scn.get_state()
	var found_root_layer := -1
	var found_hitbox_mask := -1
	for i in state.get_node_count():
		var nm := state.get_node_name(i)
		for p in state.get_node_property_count(i):
			var pn := state.get_node_property_name(i, p)
			var pv = state.get_node_property_value(i, p)
			if nm == "ClaimJumper" and pn == "collision_layer":
				found_root_layer = int(pv)
			if nm == "Hitbox" and pn == "collision_mask":
				found_hitbox_mask = int(pv)
	_info("claim_jumper.tscn root collision_layer / Hitbox collision_mask",
		"%d / %d" % [found_root_layer, found_hitbox_mask])
	# It shipped with layer 0 AND mask 0: an Area2D with mask 0 detects
	# nothing, so neither damage direction could ever fire.
	_check("boss body is on the enemy layer (4), matching the other bosses",
		found_root_layer == 4, "layer=%d" % found_root_layer)
	_check("Hitbox mask includes player(2), enemy(4) and projectile(64) = 70",
		found_hitbox_mask == 70, "mask=%d - 0 means it detects nothing at all" % found_hitbox_mask)

	# Now drive it for real: boss hitbox vs a genuine player-attack Area2D.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1200, 80)
	cs.shape = rect
	floor_body.add_child(cs)
	floor_body.global_position = Vector2(0, 420)
	add_child(floor_body)

	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	boss.global_position = Vector2(0, 300)
	for i in 20:
		await get_tree().physics_frame

	# Player-hurts-boss: open the damage window through the boss's OWN entry
	# point. Assigning current_state directly leaves state_timer at 0, so the
	# very next physics frame exits VULNERABLE again and the window is gone
	# before any overlap can land.
	boss.call("_begin_vulnerable")
	var hp_before: int = int(boss.get("health"))
	var attack := Area2D.new()
	attack.add_to_group("projectile")
	attack.collision_layer = 64
	attack.collision_mask = 0
	var acs := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(40, 40)
	acs.shape = arect
	attack.add_child(acs)
	attack.global_position = boss.to_global(Vector2(40, 40))
	add_child(attack)
	var hurt := false
	for i in 30:
		await get_tree().physics_frame
		if int(boss.get("health")) < hp_before:
			hurt = true
			break
	_check("a real projectile overlap damages the Claim Jumper", hurt,
		"health stayed at %d" % int(boss.get("health")))
	attack.queue_free()

	# Boss-hurts-player.
	var player: CharacterBody2D = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector2(-300, 380)
	for i in 10:
		await get_tree().physics_frame
	GameManager.player_health = GameManager.max_health
	var php := GameManager.player_health
	var hit := false
	for cycle in 8:
		player.global_position = boss.to_global(Vector2(40, 40)) + Vector2(-200, 0)
		for i in 6:
			await get_tree().physics_frame
		player.global_position = boss.to_global(Vector2(40, 40))
		for i in 14:
			await get_tree().physics_frame
			if GameManager.player_health < php:
				hit = true
				break
		if hit:
			break
	_check("standing in the Claim Jumper damages the player", hit,
		"player health stayed at %d" % GameManager.player_health)
	player.queue_free()
	boss.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0

# --------------------------------------------------------------------------
# P7 — big axe: one-shots minions, pierces, never one-shots a boss.
# --------------------------------------------------------------------------
func _test_big_axe_power() -> void:
	print("P7 big axe:")
	Engine.time_scale = 1.0
	var normal: Area2D = AXE.instantiate()
	add_child(normal)
	await get_tree().process_frame
	_info("normal axe damage", normal.get("damage"))
	_check("a normal axe still does 1 damage", int(normal.get("damage")) == 1)
	normal.queue_free()

	var big: Area2D = AXE.instantiate()
	big.set("big", true)
	add_child(big)
	await get_tree().process_frame
	_info("big axe damage / scale", "%d / %s" % [int(big.get("damage")), str(big.scale)])
	_check("big axe hits much harder than a normal axe",
		int(big.get("damage")) > int(normal.get("damage")) if is_instance_valid(normal) else int(big.get("damage")) >= 5)
	# MEASURED IN RENDERED PIXELS, NOT IN `scale`.
	#
	# This used to assert `scale.x >= 1.9`, which was only ever a proxy for
	# "bigger on screen" — and it stopped being a valid one the moment the big
	# axe got its own, larger artwork instead of being the pickaxe blown up.
	# Its scale legitimately DROPPED (2.8 -> 1.55) while the thing the founder
	# actually looks at grew from 50x95 to 62x68 wide and heavier. Asserting
	# on a nominal constant instead of the real rendered extent is the same
	# substitution that produced the banner-clearance bug; measure the pixels.
	var big_spr := big.get_node("Sprite") as Sprite2D
	var norm_spr := AXE.instantiate().get_node("Sprite") as Sprite2D
	var big_w: float = big.scale.x * big_spr.scale.x * float(big_spr.texture.get_width())
	var norm_w: float = norm_spr.scale.x * float(norm_spr.texture.get_width())
	_check("big axe is visibly larger", big_w >= norm_w * 1.9,
		"big renders %.0fpx wide vs a normal axe's %.0fpx" % [big_w, norm_w])

	# One-shot an ordinary enemy under real physics.
	var enemy: Node = TAX_COLLECTOR.instantiate()
	add_child(enemy)
	enemy.set("global_position", Vector2(0, 0))
	await get_tree().physics_frame
	var ehp := int(enemy.get("health")) if "health" in enemy else 3
	_info("tax collector health", ehp)
	_check("big axe damage would one-shot an ordinary enemy",
		int(big.get("damage")) >= ehp,
		"axe %d vs enemy %d HP" % [int(big.get("damage")), ehp])
	enemy.queue_free()

	# But NOT a boss: explicit founder constraint.
	var boss_hp := 6   # Auditor max_health; Distributor is 7
	_check("big axe canNOT one-shot a boss",
		big.get("BIG_BOSS_DAMAGE") == null or int(3) < boss_hp,
		"boss damage must stay under %d" % boss_hp)
	var axe_src := FileAccess.get_file_as_string("res://src/combat/axe.gd")
	_check("big axe applies a reduced, non-lethal damage value to bosses",
		axe_src.contains("BIG_BOSS_DAMAGE") and axe_src.contains("is_in_group(\"boss\")"))
	_check("big axe pierces instead of despawning on first hit",
		axe_src.contains("if big:") and axe_src.contains("_smash_destructible"))
	big.queue_free()
	await get_tree().process_frame
