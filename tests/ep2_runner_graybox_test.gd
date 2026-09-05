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
		r.get_cart_x() > x_before + 1.0 and r.get_lane() == 2)
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

	print("EP2_RUNNER_GRAYBOX: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
