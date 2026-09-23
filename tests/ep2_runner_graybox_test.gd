extends Node
## Gate for src/episode2/runner/runner_graybox.gd — the Episode 2 runner
## graybox vertical slice. Proves the core runner mechanics in a headless
## Godot run, deterministically (physics_process disabled; the sim is stepped
## by hand via step(delta) so timing is exact and not frame-clock dependent).
##
## Mechanics proven: (1) the packed scene loads, (2) auto-run advances +Z,
## (3) rail switching moves the cart in X, (4) an un-jumped obstacle in-lane
## registers exactly one hit, (5) jumping clears that same obstacle (no hit),
## (6) reaching the chamber entrance emits chamber_reached and halts the run.
## Hazard-type + duck + zipline extension (2026-09-06, design review in
## docs/model-responses/2026-09-06-grok-ep2-runner-hazards.md): (7) a held
## duck clears an "arrow" hazard, (8) jumping does NOT clear an "arrow"
## (opposite of "box"), (9) ducking does NOT clear a "boulder" hazard,
## (10) jumping does NOT clear a "boulder" — only hopping carts does (rule
## changed by the founder 2026-09-23; 10b proves the hop),
## (11) ziplining suspends cart-phase hazard checks entirely, (12) lane
## switch / jump / duck are all no-ops while ziplining.
## Regression coverage for the Kimi K3 code audit
## (docs/model-responses/2026-09-06-kimi-ep2-runner-hazards-audit.md), each
## a real bug found in the first cut of the above: (13) duck held for
## exactly 6 frames @ 1/60s (nominal 0.10s, but IEEE-754 float accumulation
## lands a couple ULPs short) still counts as effective — the float
## precision bug, (14) a duck held continuously through a zipline segment
## does NOT carry effective cover to an arrow just past the zip's end — the
## "duck isn't actually suspended during zip" bug, (15) a box/boulder hazard
## sitting just past a zipline's end is NOT free-cleared, and jump() is NOT
## a dead no-op there — the residual-fall-time bug from snapping straight to
## ZIP_HEIGHT and letting gravity walk it down.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_graybox_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _spawn() -> Node3D:
	var r: Node3D = SCENE.instantiate()
	add_child(r)
	r.set_physics_process(false)  # deterministic: we step() by hand
	return r

func _run_to_distance(r: Node3D, target: float, dt: float = 0.05, cap: int = 100000) -> void:
	var i := 0
	while r.get_distance() < target and r.is_running() and i < cap:
		r.step(dt)
		i += 1

## Ziplines must now be EARNED: be airborne as you reach the cable. Jump 3m out.
func _catch_zip(r: Node3D, start_z: float) -> void:
	_run_to_distance(r, start_z - 3.0)
	r.jump()

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 RUNNER GRAYBOX:")

	# 1. Scene loads and instantiates with the expected API.
	var r := _spawn()
	_check("packed scene instantiates with runner API",
		r.has_method("step") and r.has_method("switch_lane_right") and r.has_method("jump"))

	# 2. Auto-run advances forward.
	r.setup(200.0, [])
	var z0: float = r.get_distance()
	for _i in range(20):
		r.step(0.05)
	_check("auto-run advances +Z (%.1f → %.1f)" % [z0, r.get_distance()], r.get_distance() > z0 + 5.0)

	# 3. Rail switching moves the cart in X toward the right rail.
	var x_before: float = r.get_cart_x()
	r.switch_lane_right()
	for _i in range(20):
		r.step(0.05)
	_check("rail switch moves cart in X (%.2f → %.2f, lane %d)" % [x_before, r.get_cart_x(), r.get_lane()],
		is_equal_approx(r.get_cart_x(), float(RunnerGraybox.LANE_X[2])) and r.get_lane() == 2
		and absf(r.get_cart_x() - x_before) > 1.0)
	r.queue_free()

	# 4. Un-jumped obstacle in the starting lane (centre) registers ONE hit.
	var r2 := _spawn()
	r2.setup(200.0, [{"z": 10.0, "lane": 1}])
	_run_to_distance(r2, 13.0)
	_check("un-jumped in-lane obstacle costs exactly 1 health (health=%d)" % r2.get_health(),
		r2.get_health() == 2)
	r2.queue_free()

	# 5. Jumping clears the same obstacle — no hit.
	var r3 := _spawn()
	r3.setup(200.0, [{"z": 10.0, "lane": 1}])
	_run_to_distance(r3, 6.8)          # approach
	r3.jump()                          # airborne before the z-window [9,11]
	_run_to_distance(r3, 13.0)         # pass over it
	_check("jumping clears the obstacle (health unchanged=%d)" % r3.get_health(),
		r3.get_health() == 3, "cart was not above clear-height across the obstacle window")
	r3.queue_free()

	# 6. Reaching the chamber entrance emits chamber_reached and halts.
	var r4 := _spawn()
	r4.setup(60.0, [])
	var reached := {"v": false}
	r4.chamber_reached.connect(func() -> void: reached["v"] = true)
	_run_to_distance(r4, 60.0)
	# a couple more steps to ensure the trigger frame ran
	r4.step(0.05)
	_check("chamber entrance emits chamber_reached", reached["v"])
	_check("run halts at the chamber entrance", not r4.is_running())
	r4.queue_free()

	# 7. A held duck clears an "arrow" hazard (duck started well before the
	#    hazard's z-window, so DUCK_MIN_HOLD is satisfied by the time it opens).
	var r5 := _spawn()
	r5.setup(200.0, [{"z": 10.0, "lane": 1, "type": "arrow"}])
	_run_to_distance(r5, 7.0)
	r5.duck_start()
	_run_to_distance(r5, 13.0)
	_check("held duck clears an arrow hazard (health unchanged=%d)" % r5.get_health(),
		r5.get_health() == 3, "duck did not block the arrow")
	r5.duck_end()
	r5.queue_free()

	# 8. Jumping does NOT clear an "arrow" — opposite of "box"/"boulder".
	var r6 := _spawn()
	r6.setup(200.0, [{"z": 10.0, "lane": 1, "type": "arrow"}])
	_run_to_distance(r6, 6.8)
	r6.jump()
	_run_to_distance(r6, 13.0)
	_check("jumping does NOT clear an arrow (health=%d)" % r6.get_health(),
		r6.get_health() == 2, "arrow should hit an airborne player")
	r6.queue_free()

	# 9. Ducking does NOT clear a "boulder" — opposite of "arrow".
	var r7 := _spawn()
	r7.setup(200.0, [{"z": 10.0, "lane": 1, "type": "boulder"}])
	_run_to_distance(r7, 7.0)
	r7.duck_start()
	_run_to_distance(r7, 13.0)
	_check("ducking does NOT clear a boulder (health=%d)" % r7.get_health(),
		r7.get_health() == 2, "boulder should crush a ducking player")
	r7.duck_end()
	r7.queue_free()

	# 10. RULE CHANGE (founder, 2026-09-23): a boulder is too big to jump — the
	#     only answer is hopping into the cart on another rail. This assertion
	#     used to say "jumping clears a boulder"; it now proves the opposite.
	var r8 := _spawn()
	r8.setup(200.0, [{"z": 10.0, "lane": 1, "type": "boulder"}])
	_run_to_distance(r8, 6.8)
	r8.jump()
	_run_to_distance(r8, 13.0)
	_check("jumping does NOT clear a boulder (health=%d)" % r8.get_health(),
		r8.get_health() == 2, "a boulder must only be escapable by hopping carts")
	r8.queue_free()

	# 10b. Hopping to another rail's cart DOES escape a boulder.
	var r8b := _spawn()
	r8b.setup(200.0, [{"z": 10.0, "lane": 1, "type": "boulder"}])
	_run_to_distance(r8b, 5.0)
	r8b.switch_lane_left()
	_run_to_distance(r8b, 13.0)
	_check("hopping carts escapes a boulder (health unchanged=%d)" % r8b.get_health(),
		r8b.get_health() == 3)
	r8b.queue_free()

	# 11. Ziplining suspends cart-phase hazard checks entirely — a boulder
	#     sitting inside the zip segment never registers a hit, and the cart
	#     is held at ZIP_HEIGHT for the duration.
	var r9 := _spawn()
	r9.setup(200.0, [{"z": 10.0, "lane": 1, "type": "boulder"}], [{"start_z": 8.0, "end_z": 14.0}])
	_catch_zip(r9, 8.0)
	_run_to_distance(r9, 10.0)
	_check("cart is ziplining mid-segment", r9.is_ziplining())
	_run_to_distance(r9, 20.0)
	_check("zipline suspends hazard checks (health unchanged=%d)" % r9.get_health(),
		r9.get_health() == 3, "boulder inside the zip segment should never be checked")
	r9.queue_free()

	# 12. Lane switch, jump, and duck are all no-ops while ziplining.
	var r10 := _spawn()
	r10.setup(200.0, [], [{"start_z": 8.0, "end_z": 14.0}])
	_catch_zip(r10, 8.0)
	_run_to_distance(r10, 10.0)
	var lane_before: int = r10.get_lane()
	r10.switch_lane_right()
	r10.jump()
	r10.duck_start()
	_check("lane switch is a no-op while ziplining", r10.get_lane() == lane_before)
	_check("jump is a no-op while ziplining (cart_y unchanged=%.1f)" % r10.get_cart_y(),
		is_equal_approx(r10.get_cart_y(), RunnerGraybox.ZIP_HEIGHT))
	_check("duck is a no-op while ziplining", not r10.is_ducking())
	r10.queue_free()

	# 13. Duck held for exactly 6 frames @ 1/60s (nominal 0.10s) still counts
	#     as effective, despite IEEE-754 float accumulation landing a couple
	#     ULPs short of DUCK_MIN_HOLD (Kimi audit #1 — regression for
	#     DUCK_HOLD_EPSILON). Hazard z chosen so its hit-window only opens on
	#     exactly the 6th step, isolating the frame under test.
	var r11 := _spawn()
	r11.setup(200.0, [{"z": 2.1, "lane": 1, "type": "arrow"}])
	r11.duck_start()
	for _i in range(6):
		r11.step(1.0 / 60.0)
	_check("duck held exactly 6 frames @ 1/60s counts as effective (health=%d)" % r11.get_health(),
		r11.get_health() == 3, "float accumulation should not undercount a nominal 0.10s hold")
	r11.duck_end()
	r11.queue_free()

	# 14. A duck held continuously THROUGH a zipline segment does not carry
	#     effective cover to an arrow just past the zip's end — the hold
	#     timer must not accumulate while ziplining (Kimi audit #5b). Before
	#     the fix, duck_hold_time kept counting the whole 5-unit zip
	#     segment and would have wrongly blocked this arrow.
	var r12 := _spawn()
	r12.setup(200.0, [{"z": 10.3, "lane": 1, "type": "arrow"}], [{"start_z": 5.0, "end_z": 10.0}])
	r12.duck_start()
	_catch_zip(r12, 5.0)
	_run_to_distance(r12, 20.0)
	_check("duck held through a zip does NOT carry cover past it (health=%d)" % r12.get_health(),
		r12.get_health() == 2, "duck hold time must reset while ziplining")
	r12.duck_end()
	r12.queue_free()

	# 15a. A hazard just past a zipline's end is NOT free-cleared by residual
	#      fall time from ZIP_HEIGHT — the dismount must snap the cart back
	#      to the rail floor immediately (Kimi audit #5a).
	var r13 := _spawn()
	r13.setup(200.0, [{"z": 10.3, "lane": 1, "type": "box"}], [{"start_z": 5.0, "end_z": 10.0}])
	_catch_zip(r13, 5.0)
	_run_to_distance(r13, 20.0)
	_check("hazard just past zip-end is NOT free-cleared (health=%d)" % r13.get_health(),
		r13.get_health() == 2, "dismount should land on the rail, not linger airborne")
	r13.queue_free()

	# 15b. The cart is grounded (cart_y exactly 0) the instant the zip ends —
	#      not still falling from ZIP_HEIGHT. This is the direct regression
	#      signal for the dismount snap: without it cart_y stays near
	#      ZIP_HEIGHT for ~0.3s, during which jump()'s own grounded check
	#      (is_zero_approx(_cart_y)) correctly, but unhelpfully, refuses to
	#      fire — a dead no-op window (Kimi audit #5a).
	var r14 := _spawn()
	r14.setup(200.0, [], [{"start_z": 5.0, "end_z": 10.0}])
	_catch_zip(r14, 5.0)
	_run_to_distance(r14, 10.1)
	var y_at_dismount: float = r14.get_cart_y()
	_check("cart is grounded immediately after zip-end (cart_y=%.4f)" % y_at_dismount,
		is_zero_approx(y_at_dismount), "should land on the rail, not linger airborne from ZIP_HEIGHT")
	r14.jump()
	r14.step(0.05)
	_check("jump raises the cart once grounded post-zip (cart_y=%.2f)" % r14.get_cart_y(),
		r14.get_cart_y() > 0.3)
	r14.queue_free()


	# 16. A zipline reached WITHOUT jumping is missed: one health, stay on the rails,
	#     and the rest of that chain is not judged again (one hit per chain, not per cable).
	var chain := [{"start_z": 5.0, "end_z": 10.0}, {"start_z": 14.0, "end_z": 20.0}]
	var r15 := _spawn()
	r15.setup(200.0, [], chain)
	_run_to_distance(r15, 7.0)
	_check("walking under a zipline does NOT hook it", not r15.is_ziplining())
	_run_to_distance(r15, 25.0)
	_check("a missed zip chain costs exactly ONE health (health=%d)" % r15.get_health(),
		r15.get_health() == 2, "a miss must not cascade into one hit per cable")
	r15.queue_free()

	# 17. Chained cables: jump near the end of one to swing onto the next.
	var r16 := _spawn()
	r16.setup(200.0, [], chain)
	_catch_zip(r16, 5.0)
	_run_to_distance(r16, 7.0)
	_check("jumping to a zipline hooks it", r16.is_ziplining())
	r16.jump()                                  # 3m from the end: inside the transfer window
	_run_to_distance(r16, 12.0)
	_check("still airborne in the gap between chained cables", r16.is_ziplining())
	_run_to_distance(r16, 17.0)
	_check("swung onto the second cable (index=%d)" % r16.get_zip_index(), r16.get_zip_index() == 1)
	_run_to_distance(r16, 25.0)
	_check("a clean chain costs nothing (health=%d)" % r16.get_health(), r16.get_health() == 3)
	_check("dismounted onto the rails after the chain", not r16.is_ziplining() and is_zero_approx(r16.get_cart_y()))
	r16.queue_free()

	# 18. Riding a chained cable to its end WITHOUT the transfer jump drops you.
	var r17 := _spawn()
	r17.setup(200.0, [], chain)
	_catch_zip(r17, 5.0)
	_run_to_distance(r17, 12.0)
	_check("no transfer jump = dropped at the end of the cable", not r17.is_ziplining())
	_run_to_distance(r17, 25.0)
	_check("a dropped chain costs exactly ONE health (health=%d)" % r17.get_health(), r17.get_health() == 2)
	r17.queue_free()

	# 19. A jump early on a cable (outside the window) does NOT arm the transfer.
	var r18 := _spawn()
	r18.setup(200.0, [], [{"start_z": 5.0, "end_z": 20.0}, {"start_z": 24.0, "end_z": 30.0}])
	_catch_zip(r18, 5.0)
	_run_to_distance(r18, 8.0)                  # 12m from the end: outside the 6m window
	r18.jump()
	_check("an early jump on the cable does not arm the swing", not r18.is_zip_transfer_armed())
	r18.queue_free()

	# 20. Hooking a cable carries the rider to the centre rail (the cable is over it).
	var r19 := _spawn()
	r19.setup(200.0, [], [{"start_z": 8.0, "end_z": 20.0}])
	r19.switch_lane_left()
	_catch_zip(r19, 8.0)
	_run_to_distance(r19, 18.0)
	_check("ziplining pulls the rider over the centre rail (x=%.2f)" % r19.get_cart_x(),
		absf(r19.get_cart_x()) < 0.05 and r19.get_lane() == 1)
	r19.queue_free()

	# 21. SHOOTING. Unarmed legs cannot shoot (the Winchester comes in Chamber 0).
	var bear := [{"id": "b1", "z": 30.0, "side": 1}]
	var volley := [{"z": 30.0, "lane": 1, "type": "arrow", "archer": "b1"}]
	var r20 := _spawn()
	r20.setup(200.0, volley, [], bear, false)
	_check("shoot() is a no-op before the Winchester is granted", not r20.shoot() and r20.archers_alive() == 1)
	r20.queue_free()

	# 22. Armed: shooting the archer ahead drops it AND cancels its arrows — the
	#     volley then passes harmlessly with no duck at all.
	var r21 := _spawn()
	r21.setup(200.0, volley, [], bear, true)
	_check("shooting an archer in range drops it", r21.shoot() and r21.archers_alive() == 0)
	_run_to_distance(r21, 40.0)
	_check("a dropped archer's arrows never land (health unchanged=%d)" % r21.get_health(),
		r21.get_health() == 3, "shooting the bear must cancel its volley")
	r21.queue_free()

	# 23. Out of range (too far ahead) is a miss; the lever cooldown blocks spam.
	var r22 := _spawn()
	r22.setup(200.0, [], [], [{"id": "far", "z": 90.0, "side": -1}, {"id": "near", "z": 20.0, "side": 1}], true)
	_run_to_distance(r22, 1.0)
	var first: bool = r22.shoot()
	_check("the nearest archer in range is the one hit", first and r22.archers_alive() == 1)
	_check("the lever-action cooldown blocks an immediate second shot", not r22.shoot())
	r22.step(RunnerGraybox.SHOOT_COOLDOWN + 0.01)
	_check("an archer beyond range cannot be hit", not r22.shoot() and r22.archers_alive() == 1)
	r22.queue_free()

	# 24. Unshot archers still hurt: an armed player who neither shoots nor ducks is hit.
	var r23 := _spawn()
	r23.setup(200.0, volley, [], bear, true)
	_run_to_distance(r23, 40.0)
	_check("an unanswered volley still lands (health=%d)" % r23.get_health(), r23.get_health() == 2)
	r23.queue_free()

	print("EP2_RUNNER_GRAYBOX: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
