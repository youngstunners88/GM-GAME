extends Node
## Founder, 2026-08-26 (P0): "The 2nd and 3rd bosses STILL don't move in on Lil
## Blunt." DeepSeek's audit named the cause: under a player-following camera, a
## boss that holds a CONSTANT offset has ZERO on-screen motion — it reads as
## parked no matter its speed. The camera tracks the player, so the boss's
## ON-SCREEN x is essentially (boss_x - player_x) = the GAP. A constant gap =
## parked; a gap that CYCLES = visible pursuit.
##
## This gate kites the player and measures the GAP over time for each late boss,
## asserting it OSCILLATES with real amplitude (the boss visibly lunges in and
## resets) rather than holding flat. It is the headless regression guard for the
## on-screen-motion fix; the founder's hard-refresh (real browser frames) is the
## acceptance.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/boss_visible_lunge_test.tscn

const LEVEL2 := preload("res://src/level/level_02_crystal_caverns.tscn")
const LEVEL3 := preload("res://src/level/level_03_gold_rush.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BOSS VISIBLE LUNGE (on-screen oscillation):")
	await _run("Stage 2 Distributor", LEVEL2, "distributor", 120.0)
	await _run("Stage 3 Claim Jumper", LEVEL3, "claim_jumper", 140.0)
	print("BOSS_VISIBLE_LUNGE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _find_boss(level: Node, needle: String) -> Node:
	for c in level.get_children():
		var sc: Script = c.get_script()
		if sc and needle in str(sc.resource_path):
			return c
	return null

func _run(label: String, scene: PackedScene, needle: String, half_body: float) -> void:
	if not StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
		StateMachine.change_state(StateMachine.State.PLAYING)
	var level := scene.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	# Enter the arena to spawn the boss.
	var arena_x: float = level.level_data.boss_arena.get("start_x", 3000) + 60.0
	player.global_position = Vector2(arena_x, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame
	var boss := _find_boss(level, needle)
	if boss == null:
		_check("[%s] boss spawned" % label, false)
		level.queue_free(); await get_tree().process_frame
		return
	# Gate CHASE, not contact — disable the boss hitbox so a lunge that reaches
	# the player doesn't restart the run mid-measurement.
	var hb := boss.get_node_or_null("Hitbox")
	if hb: hb.set_deferred("monitoring", false)

	# KITE: the player weaves left/right inside the arena at ~sprint speed while
	# the boss pursues. Sample the horizontal gap every frame.
	var lo: float = boss.arena_min.x + 40.0 if boss.arena_min != Vector2.ZERO else arena_x - 250.0
	var hi: float = boss.arena_max.x - 40.0 if boss.arena_max != Vector2.ZERO else arena_x + 250.0
	var gaps: Array[float] = []
	var t: float = 0.0
	for f in range(600):  # 10s
		t += 1.0 / 60.0
		# Weave across the arena width (period ~4s), staying grounded.
		var px: float = lerpf(lo, hi, 0.5 + 0.5 * sin(t * 1.6))
		player.global_position = Vector2(px, 500.0)
		player.velocity = Vector2.ZERO
		if not is_instance_valid(boss):
			break
		var bc: float = boss.global_position.x + half_body
		gaps.append(absf(bc - player.global_position.x))
		await get_tree().physics_frame

	if gaps.size() < 100:
		_check("[%s] collected enough samples" % label, false, "only %d" % gaps.size())
		if is_instance_valid(boss): boss.queue_free()
		level.queue_free(); await get_tree().process_frame
		return

	# Amplitude of on-screen motion = how much the gap swings. A parked boss has
	# a near-flat gap; a lunging boss swings it. Use robust 10th/90th percentiles.
	var sorted := gaps.duplicate()
	sorted.sort()
	var p10: float = sorted[int(sorted.size() * 0.10)]
	var p90: float = sorted[int(sorted.size() * 0.90)]
	var gmin: float = sorted[0]
	var amplitude: float = p90 - p10
	print("  [INFO] %s: gap min=%.0f p10=%.0f p90=%.0f amplitude(p90-p10)=%.0f"
		% [label, gmin, p10, p90, amplitude])
	# The boss must visibly CLOSE (reach a tight gap at least once) AND the gap
	# must swing by a real on-screen amount (not a flat constant offset).
	_check("[%s] boss lunges CLOSE at least once (min gap < 180px)" % label,
		gmin < 180.0, "closest it ever got was %.0fpx — never bore down" % gmin)
	_check("[%s] gap OSCILLATES on screen (p90-p10 >= 70px, not a flat park)" % label,
		amplitude >= 70.0, "amplitude only %.0fpx — reads as parked under the camera" % amplitude)

	if is_instance_valid(boss): boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
