extends Node
## Blaze Rush INPUT FEEL gate: jump buffer, coyote time, respawn, pause, haptics.
##
## The run is one button, and a touch tap reaches the game 60-110 ms late. Before
## the mobile pass the tap was a latch cleared EVERY physics tick: a tap 1 tick
## before landing was lost, a tap 1 tick after a gap lip was lost, and every tap in
## the ~6 airborne ticks after a respawn was lost. This drives the REAL run with
## REAL physics and counts ticks, so each number below is observed, not assumed.
##
## Tick accounting (60 Hz): a tap queued at tick T gives the buffer `window` seconds,
## decremented by 1/60 at the end of every tick without a jump, and the cube jumps on
## the first tick J whose start finds it on the floor. It jumps iff J - T < window*60:
##   touch   0.10 s -> J - T <= 5      desktop 0.06 s -> J - T <= 3
## so lead 5 separates the two, lead 2 passes both and lead 9 fails both. (Lead 6 for
## touch and 4 for desktop sit on the float boundary and are deliberately not tested.)
##
## Run: godot --headless res://tests/blaze_input_buffer_test.tscn
## Verdict: BLAZE_INPUT_BUFFER: ALL PASS | N FAILURE(S)

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")
const DROP_Y: float = 400.0          # centre height the cube is dropped from (floor contact at 488)

var _fail: int = 0
var _was_touch: bool = false

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE INPUT BUFFER:")
	_was_touch = MobileLayoutManager.is_touch_device
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500.0, 400.0),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame
	await _test_buffer_windows(run)
	await _test_coyote(run)
	await _test_respawn(run)
	await _test_one_tap_one_jump(run)
	await _test_pause_clears_buffers(run)
	_test_haptics_inert_off_touch(run)
	MobileLayoutManager.is_touch_device = _was_touch
	run.queue_free()
	await get_tree().process_frame
	print("BLAZE_INPUT_BUFFER: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

# ---- helpers -----------------------------------------------------------------------

func _tap_event() -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.index = 0
	return ev

## Enter the PHYSICS context: after this await the test runs between the
## `physics_frame` signal and that tick's _physics_process, and every further
## `await physics_frame` resumes exactly one processed tick later. (Entering from an
## idle frame shifts the first count by one: the first resume lands BEFORE a tick.)
func _sync_to_physics() -> void:
	await get_tree().physics_frame

## Stop the run's own physics while the test sets a scene up, then resume it.
func _freeze(run: Node2D) -> void:
	run.call("_pause_run")

func _thaw(run: Node2D) -> void:
	run.call("_resume_run")

## Drop the cube from DROP_Y, optionally tapping at drop-tick `tap_tick`. Returns
## {land_tick, jumped, jump_tick}. A jump is velocity.y <= -600 at the end of a tick
## (JUMP_VELOCITY is -700 and nothing else is that fast upward).
func _drop(run: Node2D, tap_tick: int) -> Dictionary:
	var player: CharacterBody2D = run.get("_player")
	await _sync_to_physics()
	_freeze(run)
	player.position = Vector2(100.0, DROP_Y)
	player.velocity = Vector2.ZERO
	run.set("_jump_buffer", 0.0)
	run.set("_coyote", 0.0)
	_thaw(run)
	var land_tick: int = -1
	var jump_tick: int = -1
	for t in range(1, 41):
		if t == tap_tick:
			run.call("_unhandled_input", _tap_event())
		await get_tree().physics_frame
		# physics_frame fires BEFORE the nodes' _physics_process of the NEXT tick, so
		# what we read now is the state AFTER tick t.
		if land_tick < 0 and player.is_on_floor():
			land_tick = t
		if jump_tick < 0 and player.velocity.y <= -600.0:
			jump_tick = t
	return {"land_tick": land_tick, "jumped": jump_tick >= 0, "jump_tick": jump_tick}

# ---- the tests ---------------------------------------------------------------------------

func _test_buffer_windows(run: Node2D) -> void:
	# Calibrate: where does an un-tapped drop land?
	var base: Dictionary = await _drop(run, -1)
	var land: int = base["land_tick"]
	_check("calibration: an un-tapped drop lands and does NOT jump", land > 5 and not base["jumped"],
		"land_tick=%d jumped=%s" % [land, base["jumped"]])
	if land <= 5:
		return
	var jump_tick_j: int = land + 1   # first tick that STARTS on the floor
	# lead = J - T, so the tap tick is J - lead. Touch (0.10 s) first.
	MobileLayoutManager.is_touch_device = true
	var r2: Dictionary = await _drop(run, jump_tick_j - 2)
	_check("touch: a tap 2 ticks before landing jumps on landing", r2["jumped"], str(r2))
	var r5: Dictionary = await _drop(run, jump_tick_j - 5)
	_check("touch: a tap 5 ticks (83 ms) before landing still jumps (0.10 s buffer)", r5["jumped"], str(r5))
	var r9: Dictionary = await _drop(run, jump_tick_j - 9)
	_check("touch: a tap 9 ticks (150 ms) before landing is forgotten", not r9["jumped"], str(r9))
	# Desktop (0.06 s).
	MobileLayoutManager.is_touch_device = false
	var d2: Dictionary = await _drop(run, jump_tick_j - 2)
	_check("desktop: a tap 2 ticks before landing jumps on landing", d2["jumped"], str(d2))
	var d5: Dictionary = await _drop(run, jump_tick_j - 5)
	_check("desktop: the SAME 5-tick lead is outside the 0.06 s buffer", not d5["jumped"], str(d5))
	# Regression of the old behaviour: a tap while airborne with NO landing in reach.
	# Tick 7, not 2: the teleport leaves is_on_floor() stale-true for the first tick,
	# which grants coyote until ~tick 4 (the same stale tick the respawn relies on).
	var d_far: Dictionary = await _drop(run, 7)
	_check("a tap 11 ticks before landing (far above the floor) is forgotten", not d_far["jumped"], str(d_far))

func _test_coyote(run: Node2D) -> void:
	# The first pit of Level 1 starts at x=1350 (BlazeRushLayouts). Stand just short of
	# its lip and run off it; the cube is unsupported once x - 12 >= 1350.
	var player: CharacterBody2D = run.get("_player")
	var floor_loss: int = await _run_off_lip(run, -1)
	_check("calibration: the cube runs off the pit lip", floor_loss > 0, "floor_loss_tick=%d" % floor_loss)
	if floor_loss <= 0:
		return
	# A tap 1 tick after the floor ended (the old latch needed is_on_floor()) jumps now.
	var late1: int = await _run_off_lip(run, floor_loss + 1)
	_check("coyote: a tap 1 tick (17 ms) after the floor ended still jumps", late1 == -2, "result=%d" % late1)
	# 5 ticks after is past the 0.06 s grace.
	var late5: int = await _run_off_lip(run, floor_loss + 5)
	_check("coyote: a tap 5 ticks (83 ms) after the floor ended does not jump", late5 != -2, "result=%d" % late5)
	player.position = Vector2(100.0, 488.0)

## Run the cube off the first pit of L1. Returns the tick at whose START the floor was
## gone (when tap_tick < 0), or -2 when a tap at `tap_tick` produced a jump.
func _run_off_lip(run: Node2D, tap_tick: int) -> int:
	var player: CharacterBody2D = run.get("_player")
	await _sync_to_physics()
	_freeze(run)
	player.position = Vector2(1300.0, 488.0)
	player.velocity = Vector2.ZERO
	run.set("_jump_buffer", 0.0)
	run.set("_coyote", 0.0)
	_thaw(run)
	var floor_loss: int = -1
	var was_floor: bool = false
	for t in range(1, 30):
		if t == tap_tick:
			run.call("_unhandled_input", _tap_event())
		await get_tree().physics_frame
		if player.velocity.y <= -600.0:
			return -2
		var on_floor: bool = player.is_on_floor()
		if was_floor and not on_floor and floor_loss < 0:
			floor_loss = t + 1   # the first tick that STARTS without a floor
		was_floor = on_floor
	return floor_loss

func _test_respawn(run: Node2D) -> void:
	var player: CharacterBody2D = run.get("_player")
	var cam: Camera2D = run.get("_camera")
	await _sync_to_physics()
	_freeze(run)
	player.position = Vector2(2500.0, 300.0)
	_thaw(run)
	await get_tree().physics_frame
	var attempts_before: int = int(run.get("_attempts"))
	run.call("_crash")
	_check("a crash counts an attempt", int(run.get("_attempts")) == attempts_before + 1)
	_check("the respawn puts the cube ON the floor line, not a cube-height above it",
		is_equal_approx(player.position.y, 488.0) and player.position.x == 0.0, "pos=%s" % player.position)
	# Same call, no physics tick in between: the camera already follows (no empty frame).
	_check("the camera is moved IN the crash call (no frame of the old scroll position)",
		is_equal_approx(cam.position.x, player.position.x + float(run.get("_look_ahead"))),
		"cam.x=%.1f cube.x=%.1f" % [cam.position.x, player.position.x])
	# On the floor within 2 ticks (was ~6 ticks from the old spawn 28 u up).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("the cube is standing on the floor within 2 ticks of the respawn", player.is_on_floor())
	# A tap during the respawn is not lost.
	run.call("_crash")
	run.call("_unhandled_input", _tap_event())
	var jumped := false
	for t in range(4):
		await get_tree().physics_frame
		if player.velocity.y <= -600.0:
			jumped = true
	_check("a tap made during the respawn still jumps (coyote granted by _reset_player)", jumped)

func _test_one_tap_one_jump(run: Node2D) -> void:
	MobileLayoutManager.is_touch_device = true
	var player: CharacterBody2D = run.get("_player")
	await _sync_to_physics()
	_freeze(run)
	player.position = Vector2(100.0, 488.0)
	player.velocity = Vector2.ZERO
	run.set("_jump_buffer", 0.0)
	run.set("_coyote", 0.0)
	_thaw(run)
	await get_tree().physics_frame   # settle on the floor
	await get_tree().physics_frame
	# ONE finger tap = ScreenTouch + emulated mouse (+ the jump action once the tap field
	# is wired): all in the same frame, then a LATE duplicate one tick after takeoff.
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	var act := InputEventAction.new()
	act.action = &"jump"
	act.pressed = true
	run.call("_unhandled_input", _tap_event())
	run.call("_unhandled_input", mouse)
	run.call("_unhandled_input", act)
	# Not every pressed MouseButton is a tap: the wheel and the right button must NOT jump.
	run.set("_jump_buffer", 0.0)
	for button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		var other := InputEventMouseButton.new()
		other.pressed = true
		other.button_index = button
		run.call("_unhandled_input", other)
	_check("the mouse wheel / right / middle buttons do not queue a jump", float(run.get("_jump_buffer")) == 0.0)
	var takeoffs: int = 0
	var prev_vy: float = player.velocity.y
	for t in range(70):
		await get_tree().physics_frame
		if t == 1:
			run.call("_unhandled_input", mouse)   # a late duplicate while airborne
		if player.velocity.y <= -600.0 and prev_vy > -600.0:
			takeoffs += 1
		prev_vy = player.velocity.y
	_check("one finger tap (touch + mouse + action, plus a late duplicate) is exactly ONE jump over a full flight",
		takeoffs == 1, "takeoffs=%d" % takeoffs)

func _test_pause_clears_buffers(run: Node2D) -> void:
	run.set("_jump_buffer", 0.1)
	run.set("_coyote", 0.06)
	run.call("_pause_run")
	_check("pausing clears the jump buffer and the coyote grace",
		float(run.get("_jump_buffer")) == 0.0 and float(run.get("_coyote")) == 0.0)
	_check("pausing stops the run's physics", not run.is_physics_processing() and bool(run.call("is_run_paused")))
	run.call("_unhandled_input", _tap_event())
	_check("a tap while paused is ignored (it cannot fire a jump on resume)", float(run.get("_jump_buffer")) == 0.0)
	run.set("_jump_buffer", 0.1)
	run.call("_resume_run")
	_check("resuming clears the buffer again and restarts physics",
		float(run.get("_jump_buffer")) == 0.0 and run.is_physics_processing() and not bool(run.call("is_run_paused")))

func _test_haptics_inert_off_touch(run: Node2D) -> void:
	MobileLayoutManager.is_touch_device = false
	var before: int = int(run.get("_haptic_sent"))
	run.call("_buzz", 8)
	run.call("_buzz", 30)
	_check("haptics are inert on a mouse-and-keyboard machine", int(run.get("_haptic_sent")) == before)
	MobileLayoutManager.is_touch_device = true
	run.call("_buzz", 8)
	_check("haptics are forwarded to TouchActions on a touch device", int(run.get("_haptic_sent")) == before + 1)
