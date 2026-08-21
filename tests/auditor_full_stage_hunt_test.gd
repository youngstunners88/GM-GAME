extends Node
## Founder, 2026-08-21 (final presentation residual): "Remove this platform
## completely so that the boss can have a chance at chasing Lil Blunt since
## you ignored my previous request of having the block solid so that the
## boss could leverage it!"
##
## ROOT CAUSE (measured, not guessed): a real-physics probe driving a
## fleeing player back across the whole level found the Auditor permanently
## WALL-STUCK at x=2520 — the exact right edge of `platforms` entry
## Vector4(2400, 450, 120, 20). He never resolved it in 60s of simulated
## time. That platform sat above already-continuous ground (no gap to
## bridge), so removing it outright — the founder's own explicit fix,
## rejected the "make the AI smarter" alternative — cost nothing.
##
## This gate reproduces the exact failure path: trigger the real fight in
## the real level, then have the player flee all the way to the level's
## western edge (the "even if Lil Blunt runs back to the beginning section"
## design this level's own code commits to), and assert the Auditor is not
## abandoned kilometers behind — he must close to within a reasonable
## distance, not get walled anywhere along the route.
##
## Run: godot --headless res://tests/auditor_full_stage_hunt_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR FULL-STAGE HUNT:")
	await _run()
	print("AUDITOR_FULL_STAGE_HUNT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(2920.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss := level.get_node_or_null("Auditor")
	if boss == null:
		_check("Auditor spawned via _on_boss_trigger", false)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	var last_x: float = boss.global_position.x
	var stuck_frames: int = 0
	var max_stuck_streak: int = 0
	for f in range(3600):  # 60s — enough to cross the full 2920->150 flee
		var t: float = float(f) / 60.0
		var target_x: float = maxf(150.0, 2920.0 - t * 60.0)
		player.global_position = Vector2(target_x, 500.0)
		if not is_instance_valid(boss):
			_check("Auditor survives the whole pursuit", false, "boss freed mid-run")
			return
		if absf(boss.global_position.x - last_x) < 2.0:
			stuck_frames += 1
			max_stuck_streak = maxi(max_stuck_streak, stuck_frames)
		else:
			stuck_frames = 0
		last_x = boss.global_position.x
		await get_tree().physics_frame

	var final_gap: float = absf(boss.global_position.x - player.global_position.x)
	print("  [INFO] final boss_x=%.0f player_x=%.0f gap=%.0f max_stuck_streak=%d frames"
		% [boss.global_position.x, player.global_position.x, final_gap, max_stuck_streak])
	_check("Auditor is not permanently walled anywhere on the route (max stuck streak < 5s)",
		max_stuck_streak < 300, "stuck for %d frames straight" % max_stuck_streak)
	_check("Auditor closes to within striking distance of a player who fled the whole level (gap < 400px)",
		final_gap < 400.0, "final gap=%.0f — abandoned behind" % final_gap)

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
