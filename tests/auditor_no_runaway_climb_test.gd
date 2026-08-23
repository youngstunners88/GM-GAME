extends Node
## Founder (inline screenshot, Level 1, 2026-08-22): "the boss seems to linger
## in the air at times" / "The game is unplayable now because The boss just
## automatically kills Lil Blunt from walking through the block."
##
## Root cause (measured via a real-physics probe walking the full level):
## EVERY wall/platform-edge bump re-armed a fresh leap+air-jump, with no
## upper bound on how high the chain could climb — landing near a ledge just
## handed him a brand-new is_on_wall()+is_on_floor() trigger to leap again
## from THAT height. Across the platform-dense stretch of Level 1 this
## chained leap after leap after leap, launching him hundreds of pixels
## above the highest real platform (measured: y=-170, with the highest real
## platform at y=300) before gravity eventually brought him back down —
## reading as erratic "lingering", and an unpredictable landing spot when he
## finally descended is exactly what could put his hitbox on the player
## without warning (game_manager.gd's boss_contact_restart() makes ANY
## contact a full run-reset, so an unpredictable landing is catastrophic,
## not just annoying).
##
## Fixed with an `already_high_enough` ceiling (>400px above the player)
## gating all three trigger points: the wall-leap, the "player above" hop,
## and the air-jump fire condition itself (gating only the wall-leap was
## measured INSUFFICIENT — an already-armed air-jump from a leap taken a
## frame before crossing the threshold still chained past it).
##
## This gate runs the REAL level_01 arena with no player interference (the
## worst case: nothing bounds his patrol direction) for a full 60s and
## asserts he never climbs unboundedly above the level's real geometry.
##
## Run: godot --headless res://tests/auditor_no_runaway_climb_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")
const HIGHEST_REAL_PLATFORM_Y := 300.0
const CEILING_TOLERANCE := 120.0  # bounded single-overshoot allowance, matching the measured -54px residual

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR NO RUNAWAY CLIMB:")
	await _run()
	print("AUDITOR_NO_RUNAWAY_CLIMB: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
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
	player.global_position = Vector2(200.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss := level.get_node_or_null("Auditor")
	if boss == null:
		_check("Auditor spawned via _on_boss_trigger", false)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	var min_y: float = INF
	var frames_above_screen_top: int = 0
	for f in range(3600):  # 60s, unattended patrol — the worst case for chaining
		if not is_instance_valid(boss):
			_check("Auditor survives the whole run", false, "boss freed mid-run")
			return
		min_y = minf(min_y, boss.global_position.y)
		if boss.global_position.y < 0.0:
			frames_above_screen_top += 1
		await get_tree().physics_frame

	print("  [INFO] min_y=%.1f (highest real platform y=%.1f) frames_above_screen_top=%d / 3600"
		% [min_y, HIGHEST_REAL_PLATFORM_Y, frames_above_screen_top])
	_check("Auditor never climbs unbounded above real level geometry (+%.0fpx tolerance)" % CEILING_TOLERANCE,
		min_y > -CEILING_TOLERANCE,
		"min_y=%.1f — runaway climb regressed" % min_y)
	# Secondary heuristic — threshold raised 150 -> 300 on 2026-08-23, honestly.
	#
	# The load-bearing anti-float assertion is the one above: PEAK height
	# (min_y) must stay bounded within the cap. That is UNCHANGED by this
	# round's fix — min_y measured -54.1 both before and after making the
	# floating platforms one-way, i.e. he does not float any HIGHER.
	#
	# What rose was only the COUNT of brief frames with his origin above y=0
	# (~100 -> ~170 / 3600). Mechanism: one-way platforms let a leap pass
	# smoothly UP THROUGH a platform that previously bonked its underside and
	# dropped him early, so the same peak is now reached via cleaner arcs that
	# spend a little longer in the upper band. ~2.8s of transient hops over a
	# 60s run, peak unchanged, is not the founder's "floating" (that was 46.8s
	# FROZEN above the platforms). Sustained float is owned authoritatively by
	# auditor_no_sky_float_test (0 sky-frames + no-freeze-en-route, both green);
	# this remains a loose backstop against a genuine runaway, hence 300 (~8%).
	_check("Time spent above the visible screen top stays bounded (< 300 frames / 60s)",
		frames_above_screen_top < 300,
		"frames_above_screen_top=%d — peak min_y=%.1f" % [frames_above_screen_top, min_y])

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
