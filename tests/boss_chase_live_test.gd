extends Node
## LIVE boss-chase reproduction across all three real levels (founder forensic
## repair directive §17/§18). Diagnostic-first: it prints a full pursuit-pipeline
## trace per boss, THEN applies acceptance bars.
##
## WHY IT DIFFERS FROM EVERY EARLIER CHASE GATE IN THIS REPO:
##
##  1. It drives a MOVING player. Every prior gate pinned the player at a fixed x
##     (or ran it in a straight line) and asked "did the boss close the gap".
##     A boss that only works against a stationary target passes that and still
##     reads as motionless to a real player who runs back and forth.
##  2. It measures the FAILURE MODE, not just distance: frozen-fraction,
##     clamped-against-the-arena-wall fraction, x-span, and a tracking score
##     correlating boss movement direction with player movement direction.
##     "Pinned to a wall by its own standoff" and "genuinely frozen" and
##     "oscillating in place" all produce a bad distance number but need
##     completely different fixes.
##  3. It runs all three bosses through the SAME harness so Stage 1 (the one the
##     founder has never called frozen) acts as the reference implementation.
##
## Run: godot --headless res://tests/boss_chase_live_test.tscn

const DIAG := preload("res://tools/boss_ai_diagnostic.gd")

const LEVELS := [
	{
		"label": "STAGE 1 — The Auditor",
		"scene": "res://src/level/level_01_smoke_realm.tscn",
		"half_body": 110.0,          # auditor BODY 220 / 2
		"state_member": "current_state",
	},
	{
		"label": "STAGE 2 — The Distributor",
		"scene": "res://src/level/level_02_crystal_caverns.tscn",
		"half_body": 120.0,          # distributor BODY 240 / 2
		"state_member": "current_phase_state",
	},
	{
		"label": "STAGE 3 — The Claim Jumper",
		"scene": "res://src/level/level_03_gold_rush.tscn",
		"half_body": 140.0,          # claim jumper BODY 280 / 2
		"state_member": "current_state",
	},
]

## Player top speed in this game is walk_speed 200 * SPRINT 1.2 = 240 px/s.
const PLAYER_SPEED := 240.0
const RUN_SECONDS := 9.0
const SAMPLE_HZ := 4

## Movement scenarios. The FIRST one (ground kiting) is what every earlier gate
## approximated; it is NOT what the founder does. His screenshots consistently
## show Lil Blunt ELEVATED — on a platform, on a ladder, mid-jump — while the
## boss sits far away doing nothing. Vertical separation is the untested axis,
## and both flying-boss hover targeting and ground-boss ledge/hop logic are
## explicitly height-sensitive, so it is the most likely home of the live-only
## failure. Each scenario re-runs the same instrumentation.
const SCENARIOS := [
	{"name": "A/ground-kite", "y_offset": 0.0, "bob": 0.0},
	{"name": "B/high-platform", "y_offset": -220.0, "bob": 0.0},
	{"name": "C/very-high-platform", "y_offset": -380.0, "bob": 0.0},
]

var _fail: int = 0
var _reports: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	print("\n================ BOSS CHASE LIVE TRACE ================\n")
	for cfg in LEVELS:
		for scen in SCENARIOS:
			await _probe(cfg, scen)
	print("\n================ SUMMARY ================")
	for r in _reports:
		print(r)
	print("\nBOSS_CHASE_LIVE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String) -> void:
	print("  [INFO] %s" % label)

func _probe(cfg: Dictionary, scen: Dictionary) -> void:
	var label: String = "%s  [%s]" % [cfg["label"], scen["name"]]
	print("\n--- %s ---" % label)
	var level: Node = load(cfg["scene"]).instantiate()
	add_child(level)
	for _i in range(10):
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_check("%s: player spawned" % label, false)
		level.queue_free()
		await get_tree().process_frame
		return

	var arena: Dictionary = level.level_data.boss_arena
	var start_x: float = float(arena.get("start_x", 0.0))
	var end_x: float = float(arena.get("end_x", 0.0))

	# Enter the arena exactly the way the real ?boss=N warp and a walked-in
	# player do, so the seal wall / background / spawn all follow the live path.
	player.global_position = Vector2(start_x + 120.0, player.global_position.y)
	level._on_boss_trigger(player)
	for _i in range(6):
		await get_tree().process_frame

	var boss := get_tree().get_first_node_in_group("boss") as Node2D
	if boss == null:
		_check("%s: boss spawned after trigger" % label, false)
		level.queue_free()
		await get_tree().process_frame
		return

	# Untyped on purpose: `class_name BossAIDiagnostic` only resolves once the
	# editor has rebuilt its global class cache, which a bare `--headless <scene>`
	# run does not do. preload + duck typing works without that dependency.
	var diag := DIAG.new()
	diag.configure(boss, cfg["half_body"])

	# MEASUREMENT SAFETY: boss contact is an instant full-run restart
	# (GameManager.boss_contact_restart -> SceneRouter.load_scene), which would
	# tear down this test's own tree mid-run. We disable the contact hitbox but
	# COUNT the contacts that would have fired, so "he catches you constantly"
	# stays visible in the report instead of being silently erased.
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	# FREEZE THE PLAYER'S OWN PHYSICS. Without this, gravity + move_and_slide in
	# player.gd drag it straight back to the floor every frame, so the elevated
	# scenarios silently collapsed into the ground one (they produced byte-identical
	# metrics, which is how the bug was caught). We are driving the player as a
	# scripted target to probe the BOSS's reaction to height, so its own locomotion
	# must be out of the loop.
	player.set_physics_process(false)
	player.set("velocity", Vector2.ZERO)

	# The player patrols the arena at real sprint speed, reversing at the walls.
	# This is the kiting pattern every earlier gate omitted.
	var lo_x: float = start_x + 90.0
	var hi_x: float = end_x - 90.0
	var dir := 1.0
	var t := 0.0
	# Scenario vertical profile, applied on top of wherever the player entered.
	var base_y: float = player.global_position.y + float(scen["y_offset"])
	var bob: float = float(scen["bob"])
	var sample_every: int = int(round(60.0 / float(SAMPLE_HZ)))
	var frame := 0
	var state_member: String = cfg["state_member"]

	while t < RUN_SECONDS:
		if not is_instance_valid(boss) or not is_instance_valid(player):
			break
		# Move the player kinematically — we are measuring the BOSS's response,
		# so the player's own input/physics is deliberately not in the loop.
		var px: float = player.global_position.x + dir * PLAYER_SPEED * (1.0 / 60.0)
		if px >= hi_x:
			px = hi_x
			dir = -1.0
		elif px <= lo_x:
			px = lo_x
			dir = 1.0
		player.global_position.x = px
		# Vertical profile. Set directly (not via physics) because we are
		# measuring the BOSS's reaction to a height difference, not the player's
		# own jump arc.
		player.global_position.y = base_y - (absf(sin(t * 2.2)) * bob if bob > 0.0 else 0.0)

		if frame % sample_every == 0:
			var sv: Variant = boss.get(state_member)
			diag.sample(t, boss, player, int(sv) if sv != null else -1)
		frame += 1
		t += 1.0 / 60.0
		await get_tree().physics_frame

	print(diag.report(label))
	print("  --- thinned per-sample trace ---")
	print(diag.trace_lines(2))

	# ---- Acceptance bars (founder directive §18/§24) ----
	# These are deliberately about PERCEIVED pursuit, which is what the founder
	# is reporting on, not about a single closed-distance number.
	var reach: float = diag.reachable_range()
	var span: float = diag.x_span()
	var span_frac: float = (span / reach) if reach > 0.0 else 0.0

	_info("%s: span/reachable = %.0f/%.0f = %.0f%%" % [label, span, reach, span_frac * 100.0])

	_check("%s: boss is not frozen (frozen_fraction %.2f < 0.60)" % [label, diag.frozen_fraction()],
		diag.frozen_fraction() < 0.60, "frozen_fraction=%.2f" % diag.frozen_fraction())
	_check("%s: boss is not pinned to an arena wall (clamped_fraction %.2f < 0.50)" % [label, diag.clamped_fraction()],
		diag.clamped_fraction() < 0.50, "clamped_fraction=%.2f" % diag.clamped_fraction())
	_check("%s: boss uses a real share of the arena (span >= 35%% of reachable)" % label,
		reach <= 0.0 or span_frac >= 0.35, "span=%.0f reachable=%.0f (%.0f%%)" % [span, reach, span_frac * 100.0])
	_check("%s: boss TRACKS a moving player (tracking_score %+.2f >= +0.30)" % [label, diag.tracking_score()],
		diag.tracking_score() >= 0.30, "tracking_score=%+.2f" % diag.tracking_score())

	_reports.append(diag.report(label))

	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
