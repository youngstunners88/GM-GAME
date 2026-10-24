extends Node
## Gate for the touch PROFILES and the finger-movement controls (src/input/mobile/).
##
## Real fingers end to end (Input.parse_input_event -> GUI -> control -> TouchActions ->
## InputMap) wherever a finger matters, and pure synthetic point streams wherever a
## threshold matters:
##   * TouchUi and TouchActions' new verbs (pulse, tap, look accumulator, ensure_action)
##   * the swipe-pad classifier: hop + re-anchor, jump lockout + re-arm, duck hysteresis,
##     minimum hold, release on suspend / hide / rotation
##   * the tap field: a resting finger never swallows the next finger's tap, the emulated
##     mouse never double-fires, a finger it did not press is never adopted
##   * the look pad: slop, accumulation, clamp, cleared on release / suspend
##   * profile selection by group node, build-before-show, ONE release per profile change,
##     the layer above the films, the scoped hide fade, keyboard flip, suspended-by-scene
##   * analog_vertical vs the platformer stick (byte-identical golden signature)
##   * every layout scene and every touch source file is wordless
##
## Run: godot --headless res://tests/touch_controls_profiles_test.tscn
## Ends with `TOUCH_CONTROLS_PROFILES: ALL PASS` (exit 0) or `N FAILURE(S)` (exit N).

## MD5 of the platformer stick's full output signature, captured from the UNMODIFIED
## stick before analog_vertical existed (see _stick_signature). If this changes, the
## platformer's feel changed.
const PLATFORMER_STICK_SIGNATURE := "345 lines md5=62c6a790e618e4a057b13949070bf3c1"

## A scene node that picks the touch profile (the duck-typed contract the manager reads).
class ProfileNode extends Node:
	signal touch_profile_changed
	var profile: StringName = &"platformer"
	var suspended: bool = false
	func touch_profile() -> StringName:
		return profile
	func touch_suspended() -> bool:
		return suspended

## Counts what falls through the GUI to the game (a tap that a control swallows never arrives).
class Probe extends Node:
	var touches: int = 0
	var mice: int = 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			touches += 1
		elif event is InputEventMouseButton:
			mice += 1

var _fail: int = 0
var _seen: Array[String] = []
var _pn: ProfileNode
var _screen: Vector2i = Vector2i(844, 390)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _near(a: float, b: float, eps: float = 0.05) -> bool:
	return absf(a - b) <= eps

func _input(event: InputEvent) -> void:
	if event is InputEventAction:
		var a := event as InputEventAction
		_seen.append("%s:%s" % [a.action, "down" if a.pressed else "up"])

func _count(name: String) -> int:
	return _seen.count(name)

# --- helpers -----------------------------------------------------------------

func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_pos

func _touch(index: int, pressed: bool, pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.pressed = pressed
	t.position = _to_window(pos)
	Input.parse_input_event(t)

## A drag with a RELATIVE step in canvas units (the GUI hands controls canvas units).
func _drag(index: int, pos: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = _to_window(pos)
	d.relative = get_viewport().get_final_transform().basis_xform(rel)
	Input.parse_input_event(d)

func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

## Long enough for a pulse() to have been released (one physics frame, then a process frame).
func _wait_pulse() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _centre(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5

func _go_playing() -> void:
	if StateMachine.get_state_enum() != StateMachine.State.TRANSITIONING and StateMachine.get_state_enum() != StateMachine.State.PLAYING:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	if StateMachine.get_state_enum() == StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.PLAYING)

func _set_screen(size: Vector2i) -> void:
	_screen = size
	get_window().size = size
	await _frames(2)

## Put the manager into `profile` (touch forced on, PLAYING, nothing locked) and return its layout.
func _enter(profile: StringName) -> TouchLayout:
	_pn.profile = profile
	_go_playing()
	MobileLayoutManager.refresh()
	await _frames(2)
	return MobileLayoutManager.layout()

func _find(lay: TouchLayout, type_name: String) -> VirtualControl:
	for c in lay.controls():
		if c.get_script() != null and (c.get_script() as Script).get_global_name() == type_name:
			return c
	return null

func _ready() -> void:
	get_window().size = _screen
	await _frames(2)
	print("TOUCH CONTROLS PROFILES:")
	_pn = ProfileNode.new()
	add_child(_pn)
	_pn.add_to_group(MobileLayoutManager.GROUP_WANTED)
	_pn.profile = &"none"
	MobileLayoutManager.force_touch_ui = true
	MobileLayoutManager.is_touch_device = true
	_go_playing()
	MobileLayoutManager.refresh()
	await _frames(2)

	await _test_touch_ui()
	_test_profile_key_resolution()
	await _test_touch_actions_verbs()
	_test_classifier()
	await _test_stick_analog_vertical()
	_test_wordless_scan()
	await _test_profile_selection()
	await _test_tap_field()
	await _test_swipe_pad_live()
	await _test_look_pad_live()
	await _test_buttons_live()
	await _test_rotate_cue()
	await _test_hide_fade()
	await _test_suspended_overlay()
	await _test_release_paths()

	_pn.profile = &"none"
	MobileLayoutManager.refresh()
	TouchActions.release_all()
	print("TOUCH_CONTROLS_PROFILES: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

# --- TouchUi -----------------------------------------------------------------

func _test_touch_ui() -> void:
	print(" TouchUi:")
	_check("is_touch() follows the manager (forced on)", TouchUi.is_touch())
	_check("keys_shown() is false on a touch device not driven by a keyboard", not TouchUi.keys_shown())
	MobileLayoutManager._keyboard_mode = true
	_check("a hybrid device driven by a keyboard still shows keys", TouchUi.keys_shown() and TouchUi.is_keyboard_mode())
	MobileLayoutManager._keyboard_mode = false
	_check("metrics() is the manager's live metrics", TouchUi.metrics() == MobileLayoutManager.metrics())
	_check("is_portrait() false in a landscape window", not TouchUi.is_portrait())
	await _set_screen(Vector2i(390, 844))
	_check("is_portrait() true in a portrait window", TouchUi.is_portrait())
	await _set_screen(Vector2i(844, 390))
	_check("profile() reads the manager's current profile", TouchUi.profile() == MobileLayoutManager.current_profile())
	# null-safe without the autoload: rename it away so the root lookup fails
	MobileLayoutManager.name = "MobileLayoutManagerAway"
	var shown: bool = TouchUi.keys_shown()
	var touch: bool = TouchUi.is_touch()
	var kb: bool = TouchUi.is_keyboard_mode()
	var met: TouchMetrics = TouchUi.metrics()
	var prof: StringName = TouchUi.profile()
	MobileLayoutManager.name = "MobileLayoutManager"
	_check("without the autoload: keys shown on a non-touch machine, no crash", shown and not touch and not kb)
	_check("without the autoload: metrics() is a fresh read, profile() is platformer", met != null and met.viewport_size.x > 0.0 and prof == &"platformer")

# --- profile key resolution (pure) ----------------------------------------------

func _test_profile_key_resolution() -> void:
	print(" profile layout key resolution:")
	var all: Array = [&"phone_landscape", &"tablet_landscape", &"phone_portrait", &"x_phone_landscape", &"x_tablet_landscape", &"x_phone_portrait"]
	_check("platformer keeps the old keys", TouchMetrics.profile_layout_key(&"platformer", &"phone", &"landscape", all) == &"phone_landscape")
	_check("an empty profile is the platformer", TouchMetrics.profile_layout_key(&"", &"tablet", &"landscape", all) == &"tablet_landscape")
	_check("exact key: phone landscape", TouchMetrics.profile_layout_key(&"x", &"phone", &"landscape", all) == &"x_phone_landscape")
	_check("exact key: tablet landscape", TouchMetrics.profile_layout_key(&"x", &"tablet", &"landscape", all) == &"x_tablet_landscape")
	_check("exact key: any portrait", TouchMetrics.profile_layout_key(&"x", &"tablet", &"portrait", all) == &"x_phone_portrait")
	var landscape_only: Array = [&"phone_landscape", &"tablet_landscape", &"phone_portrait", &"x_phone_landscape"]
	_check("missing tablet scene falls back to the profile's landscape scene", TouchMetrics.profile_layout_key(&"x", &"tablet", &"landscape", landscape_only) == &"x_phone_landscape")
	_check("missing portrait scene falls back to the profile's landscape scene", TouchMetrics.profile_layout_key(&"x", &"phone", &"portrait", landscape_only) == &"x_phone_landscape")
	var platformer_only: Array = [&"phone_landscape", &"tablet_landscape", &"phone_portrait"]
	_check("a profile with no scene falls back to the platformer layout (tablet)", TouchMetrics.profile_layout_key(&"x", &"tablet", &"landscape", platformer_only) == &"tablet_landscape")
	_check("a profile with no scene falls back to the platformer layout (portrait)", TouchMetrics.profile_layout_key(&"x", &"phone", &"portrait", platformer_only) == &"phone_portrait")
	var covered: bool = true
	for profile in MobileLayoutManager.KNOWN_PROFILES:
		if profile == &"platformer" or profile == &"none":
			continue
		for v in [&"phone_landscape", &"tablet_landscape", &"phone_portrait"]:
			if not MobileLayoutManager.PROFILE_SCENES.has(StringName("%s_%s" % [profile, v])):
				covered = false
	_check("every profile has all three scenes registered", covered)

# --- TouchActions: ensure_action / pulse / tap / look ---------------------------------

func _test_touch_actions_verbs() -> void:
	print(" TouchActions verbs:")
	TouchActions.release_all()
	# ensure_action
	var probe_action := &"ep2_touch_probe_action"
	_check("probe action does not exist yet", not InputMap.has_action(probe_action))
	TouchActions.ensure_action(probe_action)
	_check("ensure_action adds an empty action", InputMap.has_action(probe_action) and InputMap.action_get_events(probe_action).is_empty())
	TouchActions.ensure_action(probe_action)
	_check("ensure_action is idempotent", InputMap.has_action(probe_action))
	var jump_events: int = InputMap.action_get_events(&"jump").size()
	TouchActions.ensure_action(&"jump")
	_check("ensure_action never touches an existing action's events", InputMap.action_get_events(&"jump").size() == jump_events and jump_events > 0)
	TouchActions.press(probe_action)
	_check("a touch-only action can be pressed and read", Input.is_action_pressed(probe_action) and TouchActions.is_held(probe_action))
	TouchActions.release(probe_action)

	# pulse: a momentary press that releases by itself
	_seen.clear()
	TouchActions.pulse(&"move_left")
	_check("pulse presses now", Input.is_action_pressed(&"move_left"))
	await _wait_pulse()
	_check("pulse releases on its own", not Input.is_action_pressed(&"move_left") and not TouchActions.is_held(&"move_left"))
	_check("pulse is one down edge and one up edge", _count("move_left:down") == 1 and _count("move_left:up") == 1, str(_seen))
	# a pulse over a held action is a FRESH edge
	_seen.clear()
	TouchActions.press(&"jump")
	TouchActions.pulse(&"jump")
	await _wait_pulse()
	_check("a pulse over a held action gives a fresh down edge", _count("jump:down") == 2, str(_seen))
	TouchActions.release_all()
	# while suspended a pulse is dropped
	TouchActions.set_suspended(true)
	_seen.clear()
	TouchActions.pulse(&"jump")
	await _wait_pulse()
	_check("a pulse made while suspended is dropped", _count("jump:down") == 0 and not TouchActions.is_held(&"jump"))
	# ...and one made just before the suspension ends must not leak a press on resume
	# (move_left is a RESUME action: a recorded wish would be restored)
	_seen.clear()
	TouchActions.set_suspended(true)
	TouchActions.pulse(&"move_left")
	TouchActions.set_suspended(false)
	await _wait_pulse()
	_check("a pulse made during a suspension does not leak a press at resume", _count("move_left:down") == 0 and not TouchActions.is_held(&"move_left"), str(_seen))
	TouchActions.release_all()
	_check("pulse on an unknown action does nothing", not _pulse_unknown())

	# tap: a resting finger must not swallow the next finger's tap
	_seen.clear()
	TouchActions.tap(&"jump")
	TouchActions.tap(&"jump")
	await _frames(1)
	_check("two taps on a held action are two down edges", _count("jump:down") == 2, str(_seen))
	_check("...and the action stays held", Input.is_action_pressed(&"jump"))
	TouchActions.release(&"jump")
	_seen.clear()
	TouchActions.press(&"jump")
	TouchActions.press(&"jump")
	await _frames(1)
	_check("(contrast) press() twice is ONE down edge: that is why tap() exists", _count("jump:down") == 1, str(_seen))
	TouchActions.release_all()

	# look accumulator
	TouchActions.take_look()
	TouchActions.add_look(Vector2(3, -2))
	TouchActions.add_look(Vector2(1, 5))
	_check("add_look accumulates", TouchActions.look_pending() == Vector2(4, 3))
	_check("take_look drains it", TouchActions.take_look() == Vector2(4, 3) and TouchActions.take_look() == Vector2.ZERO)
	TouchActions.add_look(Vector2(9, 9))
	TouchActions.release_all()
	_check("release_all clears the look accumulator", TouchActions.take_look() == Vector2.ZERO)
	TouchActions.add_look(Vector2(9, 9))
	TouchActions.set_suspended(true)
	_check("suspending clears the look accumulator", TouchActions.take_look() == Vector2.ZERO)
	TouchActions.add_look(Vector2(9, 9))
	_check("look is ignored while suspended", TouchActions.take_look() == Vector2.ZERO)
	TouchActions.set_suspended(false)
	TouchActions.add_look(Vector2(1, 1))
	_check("look works again after the suspension", TouchActions.take_look() == Vector2(1, 1))

func _pulse_unknown() -> bool:
	TouchActions.pulse(&"no_such_action_anywhere")
	return TouchActions.held_count() > 0

# --- the swipe classifier on synthetic point streams -----------------------------------

func _cls() -> VirtualSwipePad.Classifier:
	return VirtualSwipePad.Classifier.new()

## Does the classifier output equal exactly this command list?
func _is(cmds: Array[int], expected: Array) -> bool:
	if cmds.size() != expected.size():
		return false
	for i in cmds.size():
		if cmds[i] != int(expected[i]):
			return false
	return true

func _test_classifier() -> void:
	print(" swipe classifier (pure, dp coordinates, explicit clock):")
	var Cmd := VirtualSwipePad.Cmd
	# slop and the dominant-axis ratio
	var c := _cls()
	c.down(Vector2.ZERO, 0)
	_check("inside the slop nothing happens", c.move(Vector2(5, 0), 10).is_empty())
	_check("21 dp sideways is not a hop yet", c.move(Vector2(21, 0), 20).is_empty())
	var out: Array[int] = c.move(Vector2(22, 0), 30)
	_check("22 dp sideways hops right", _is(out, [Cmd.HOP_RIGHT]), str(out))
	_check("the hop re-anchors x", is_equal_approx(c.anchor.x, 22.0))
	_check("another 15 dp is not a second hop", c.move(Vector2(37, 0), 40).is_empty())
	out = c.move(Vector2(44, 0), 50)
	_check("a further 22 dp hops again without lifting", _is(out, [Cmd.HOP_RIGHT]), str(out))
	out = c.move(Vector2(18, 0), 60)
	_check("swiping back 26 dp hops LEFT", _is(out, [Cmd.HOP_LEFT]), str(out))
	c = _cls()
	c.down(Vector2.ZERO, 0)
	_check("a diagonal (30 sideways, 25 up) is neither hop nor jump", c.move(Vector2(30, -25), 10).is_empty())
	c = _cls()
	c.down(Vector2.ZERO, 0)
	_check("sideways 30 with 20 of drift still hops (ratio 1.3 holds: 30 >= 26)", _is(c.move(Vector2(30, -17), 10), [Cmd.HOP_RIGHT]))

	# jump: threshold, lockout, re-arm, one jump per long swipe
	c = _cls()
	c.down(Vector2.ZERO, 0)
	_check("19 dp up is not a jump", c.move(Vector2(0, -19), 5).is_empty())
	out = c.move(Vector2(0, -21), 10)
	_check("20+ dp up jumps", _is(out, [Cmd.JUMP]), str(out))
	var long_swipe: Array[int] = []
	for y in [-30.0, -45.0, -70.0, -100.0]:
		long_swipe.append_array(c.move(Vector2(0, y), 400))
	_check("one long swipe up jumps ONCE (the finger must come back down first)", long_swipe.is_empty(), str(long_swipe))
	_check("coming back down 10 dp re-arms", c.move(Vector2(0, -90), 800).is_empty() and c.jump_armed)
	out = c.move(Vector2(0, -125), 900)
	_check("then 20+ dp up again jumps a second time", _is(out, [Cmd.JUMP]), str(out))
	# lockout: re-armed and far enough, but inside 120 ms
	c = _cls()
	c.down(Vector2.ZERO, 0)
	c.move(Vector2(0, -21), 0)                       # JUMP at t=0, anchor.y = -21
	c.move(Vector2(0, -1), 20)                       # back down 20 dp: re-armed
	_check("inside the 120 ms lockout a second jump is held back", c.move(Vector2(0, -45), 40).is_empty())
	out = c.move(Vector2(0, -46), 130)
	_check("after the lockout the same swipe jumps", _is(out, [Cmd.JUMP]), str(out))
	# lifting re-arms
	c.up(200)
	c.down(Vector2(100, 100), 300)
	_check("a fresh touch is armed again", c.jump_armed)
	_check("...and jumps on its first 20 dp up", _is(c.move(Vector2(100, 78), 310), [Cmd.JUMP]))

	# duck: threshold, hysteresis, minimum hold, pending release on lift
	c = _cls()
	c.down(Vector2.ZERO, 0)
	_check("23 dp down is not a duck", c.move(Vector2(0, 23), 100).is_empty())
	out = c.move(Vector2(0, 25), 1000)
	_check("24+ dp down ducks", _is(out, [Cmd.DUCK_ON]) and c.duck_on, str(out))
	_check("anywhere above anchor+12 keeps the duck (hysteresis: 13 dp)", c.move(Vector2(0, 13), 1500).is_empty() and c.duck_on)
	out = c.move(Vector2(0, 11), 1600)
	_check("below anchor+12 releases it (held > 150 ms)", _is(out, [Cmd.DUCK_OFF]) and not c.duck_on, str(out))
	c = _cls()
	c.down(Vector2.ZERO, 0)
	c.move(Vector2(0, 30), 1000)
	_check("a duck younger than 150 ms is not released by moving back up", c.move(Vector2(0, 0), 1050).is_empty() and c.duck_on)
	_check("...it is pending until it is due", c.needs_poll() and c.poll(1100).is_empty() and c.duck_on)
	out = c.poll(1150)
	_check("...and releases when 150 ms are up", _is(out, [Cmd.DUCK_OFF]) and not c.duck_on, str(out))
	c = _cls()
	c.down(Vector2.ZERO, 0)
	c.move(Vector2(0, 30), 1000)
	_check("lifting a flick keeps the duck for its minimum hold", c.up(1060).is_empty() and c.duck_on and c.needs_poll())
	_check("...then releases it", _is(c.poll(1151), [Cmd.DUCK_OFF]) and not c.duck_on)
	c = _cls()
	c.down(Vector2.ZERO, 0)
	c.move(Vector2(0, 30), 1000)
	_check("lifting after the minimum hold releases at once", _is(c.up(1400), [Cmd.DUCK_OFF]) and not c.duck_on)
	# hops are allowed while ducking, and do not drop the duck
	c = _cls()
	c.down(Vector2.ZERO, 0)
	c.move(Vector2(0, 30), 1000)
	out = c.move(Vector2(40, 30), 1200)
	_check("a hop while ducking hops and keeps the duck", _is(out, [Cmd.HOP_RIGHT]) and c.duck_on, str(out))
	# cancel (suspend / hide) releases a held duck at once and resets
	out = c.cancel()
	_check("cancel() releases a held duck at once", _is(out, [Cmd.DUCK_OFF]) and not c.duck_on and not c.needs_poll())
	_check("cancel() when nothing is held is silent", c.cancel().is_empty())
	_check("a cancelled classifier ignores stray moves", c.move(Vector2(0, 90), 5000).is_empty())

# --- analog_vertical and the platformer stick ---------------------------------------------

## The platformer stick's full output signature: a grid of tilts entered fresh plus
## out-and-back hysteresis paths. Same function that produced PLATFORMER_STICK_SIGNATURE
## on the unmodified stick.
func _stick_signature(stick: VirtualJoystick) -> String:
	var radius: float = stick.base_radius_dp * stick.unit
	var origin: Vector2 = stick.size * Vector2(0.5, 0.5)
	var lines: PackedStringArray = []
	var paths: Array = []
	for iy in range(-12, 13, 2):
		for ix in range(-12, 13, 2):
			paths.append([Vector2(ix / 10.0, iy / 10.0)])
	for hx in [0.0, 0.2, 0.5, 0.9]:
		var p: Array = []
		for i in range(0, 11):
			p.append(Vector2(hx, -i / 10.0))
		for i in range(10, -1, -1):
			p.append(Vector2(hx, -i / 10.0))
		for i in range(0, 11):
			p.append(Vector2(-hx, i / 10.0))
		for i in range(10, -1, -1):
			p.append(Vector2(-hx, i / 10.0))
		paths.append(p)
	for path in paths:
		stick._begin(origin)
		for n: Vector2 in path:
			stick._move(origin + n * radius)
			var v: Vector2 = stick.value()
			lines.append("%.3f,%.3f|%.4f,%.4f,%.4f,%.4f|%.4f,%.4f" % [n.x, n.y,
				Input.get_action_strength("move_left"), Input.get_action_strength("move_right"),
				Input.get_action_strength("move_up"), Input.get_action_strength("move_down"), v.x, v.y])
		stick._reset()
	var text: String = "\n".join(lines)
	return "%d lines md5=%s" % [lines.size(), text.md5_text()]

## `analog`: -1 leaves the scene's own default (what a platformer layout gets), 0 / 1 set it.
func _make_stick(analog: int) -> VirtualJoystick:
	var holder := Control.new()
	holder.size = Vector2(1280, 720)
	add_child(holder)
	var stick: VirtualJoystick = (load("res://src/input/mobile/virtual_joystick.tscn") as PackedScene).instantiate()
	if analog >= 0:
		stick.analog_vertical = analog == 1
	holder.add_child(stick)
	stick.apply_layout(TouchMetrics.compute(Vector2(1280, 720), Vector2(1280, 720), 1.0, Vector4.ZERO, true), 1.0)
	return stick

func _test_stick_analog_vertical() -> void:
	print(" analog_vertical vs the platformer stick:")
	TouchActions.release_all()
	TouchActions.set_suspended(false)
	var plat: VirtualJoystick = _make_stick(-1)
	_check("analog_vertical defaults to false (the stick scene's own default)", not plat.analog_vertical)
	var shipped_sticks: int = 0
	var shipped_analog: PackedStringArray = []
	for key in MobileLayoutManager.LAYOUT_SCENES:
		var lay: Node = (MobileLayoutManager.LAYOUT_SCENES[key] as PackedScene).instantiate()
		for c in (lay as TouchLayout).controls():
			if c is VirtualJoystick:
				shipped_sticks += 1
				if (c as VirtualJoystick).analog_vertical:
					shipped_analog.append(str(key))
		lay.free()
	_check("every shipped platformer layout has a stick and none of them is analog_vertical", shipped_sticks == 3 and shipped_analog.is_empty(), "sticks=%d analog=%s" % [shipped_sticks, str(shipped_analog)])
	var sig: String = _stick_signature(plat)
	_check("platformer outputs are byte-identical to the pre-change stick", sig == PLATFORMER_STICK_SIGNATURE, "got %s" % sig)
	var radius: float = plat.base_radius_dp * plat.unit
	var origin: Vector2 = plat.size * 0.5
	# platformer: a light forward push does nothing, a steep push suppresses sidestep
	plat._begin(origin)
	plat._move(origin + Vector2(0.0, -radius * 0.29))
	_check("platformer: a light push up is below the digital threshold", Input.get_action_strength("move_up") == 0.0)
	plat._move(origin + Vector2(radius * 0.70, -radius * 0.80))
	_check("platformer: a steep push climbs and suppresses the sidestep", Input.get_action_strength("move_up") == 1.0 and Input.get_action_strength("move_right") == 0.0)
	plat._reset()

	var fps: VirtualJoystick = _make_stick(1)
	fps._begin(origin)
	fps._move(origin + Vector2(0.0, -radius * 0.29))
	var light: float = Input.get_action_strength("move_up")
	_check("analog: a light push forward is a gentle analog walk (0.3..0.6)", light > 0.3 and light < 0.6, "got %f" % light)
	fps._move(origin + Vector2(0.0, -radius * 0.90))
	_check("analog: a firm push forward is the full strength", _near(Input.get_action_strength("move_up"), 1.0, 0.001))
	fps._move(origin + Vector2(0.0, radius * 0.29))
	var back: float = Input.get_action_strength("move_down")
	_check("analog: a light pull back is gentle too, and forward is released", back > 0.3 and back < 0.6 and Input.get_action_strength("move_up") == 0.0, "got %f" % back)
	fps._move(origin + Vector2(radius * 0.50, -radius * 0.80))
	_check("analog: forward + sidestep both stay (no 'vertical beats sidestep')", Input.get_action_strength("move_up") > 0.9 and Input.get_action_strength("move_right") > 0.5,
			"up=%f right=%f" % [Input.get_action_strength("move_up"), Input.get_action_strength("move_right")])
	_check("analog: get_axis reads the forward tilt (the FPS poll)", Input.get_axis("move_down", "move_up") > 0.9)
	_check("analog: value() reports the signed strengths", fps.value().y < -0.9 and fps.value().x > 0.5)
	fps._reset()
	_check("analog: lifting releases everything", Input.get_action_strength("move_up") == 0.0 and Input.get_action_strength("move_right") == 0.0)
	plat.get_parent().queue_free()
	fps.get_parent().queue_free()
	await _frames(1)

# --- wordless scan --------------------------------------------------------------------------

func _first_text_node(root: Node) -> String:
	for cls in ["Label", "RichTextLabel", "Button", "LinkButton", "CheckBox", "CheckButton", "MenuButton", "OptionButton", "LineEdit", "TextEdit", "CodeEdit"]:
		if root.is_class(cls):
			return "%s is a %s" % [root.name, cls]
	for prop in ["text", "tooltip_text", "label"]:
		if prop in root and str(root.get(prop)) != "":
			return "%s.%s = '%s'" % [root.name, prop, str(root.get(prop))]
	for child in root.get_children():
		var found: String = _first_text_node(child)
		if found != "":
			return found
	return ""

func _test_wordless_scan() -> void:
	print(" wordless scan:")
	var scenes: Dictionary = {}
	for k in MobileLayoutManager.LAYOUT_SCENES:
		scenes[k] = MobileLayoutManager.LAYOUT_SCENES[k]
	for k in MobileLayoutManager.PROFILE_SCENES:
		scenes[k] = MobileLayoutManager.PROFILE_SCENES[k]
	_check("21 layout scenes are registered (3 platformer + 6 profiles x 3)", scenes.size() == 21, "got %d" % scenes.size())
	var bad: PackedStringArray = []
	for k in scenes:
		var lay: Node = (scenes[k] as PackedScene).instantiate()
		var words: String = _first_text_node(lay)
		if words != "":
			bad.append("%s: %s" % [k, words])
		lay.free()
	_check("no layout scene holds a Label, a Button, or any text", bad.is_empty(), "; ".join(bad))
	for path in ["res://src/input/mobile/virtual_button.tscn", "res://src/input/mobile/virtual_joystick.tscn", "res://src/input/mobile/virtual_tap_field.tscn",
			"res://src/input/mobile/virtual_swipe_pad.tscn", "res://src/input/mobile/virtual_look_pad.tscn", "res://src/input/mobile/virtual_rotate_cue.tscn"]:
		var node: Node = (load(path) as PackedScene).instantiate()
		var words: String = _first_text_node(node)
		_check("%s carries no text" % path.get_file(), words == "", words)
		node.free()
	# source level: the touch layer never draws a string (a draw_string call IS the words, whatever the scene says)
	var offenders: PackedStringArray = []
	var dir := DirAccess.open("res://src/input/mobile")
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var src: String = FileAccess.get_file_as_string("res://src/input/mobile/%s" % file)
		for needle in ["draw_string", "draw_multiline_string", "fallback_font", "Label.new", "Button.new", "RichTextLabel"]:
			if src.find(needle) != -1:
				offenders.append("%s uses %s" % [file, needle])
	_check("no touch source file draws text or builds a text control", offenders.is_empty(), "; ".join(offenders))

# --- profile selection --------------------------------------------------------------------------

func _layer_value() -> int:
	return (MobileLayoutManager.get_node("TouchLayer") as CanvasLayer).layer

func _test_profile_selection() -> void:
	print(" profile selection:")
	await _set_screen(Vector2i(844, 390))
	# legacy: a group node WITHOUT touch_profile() keeps the platformer behaviour
	_pn.remove_from_group(MobileLayoutManager.GROUP_WANTED)
	var legacy := Node.new()
	legacy.add_to_group(MobileLayoutManager.GROUP_WANTED)
	add_child(legacy)
	_go_playing()
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("a plain group node = the legacy platformer layout", MobileLayoutManager.controls_visible and MobileLayoutManager.current_profile() == &"platformer" and MobileLayoutManager.current_layout_key() == &"phone_landscape")
	_check("the platformer layer stays at 18", _layer_value() == MobileLayoutManager.LAYER and MobileLayoutManager.LAYER == 18)
	legacy.queue_free()
	_pn.add_to_group(MobileLayoutManager.GROUP_WANTED)
	await _frames(1)

	_check("LAYER_OVER_FILMS is 60 (above the Episode 2 film / selector layers at 40)", MobileLayoutManager.LAYER_OVER_FILMS == 60)
	for pair in [[&"blaze", 60], [&"ep2_runner", 18], [&"ep2_foot", 18], [&"ep2_film", 60], [&"ep2_end", 60], [&"ep2_rotate", 60], [&"platformer", 18]]:
		var lay: TouchLayout = await _enter(pair[0])
		_check("profile %s selects its own layout and sits on layer %d" % [pair[0], pair[1]],
				MobileLayoutManager.current_profile() == pair[0] and lay != null and lay.profile == pair[0] and _layer_value() == pair[1],
				"profile=%s lay=%s layer=%d" % [MobileLayoutManager.current_profile(), str(lay.profile) if lay else "-", _layer_value()])
		_check("profile %s is shown with a layout built for this screen" % pair[0], MobileLayoutManager.controls_visible and String(MobileLayoutManager.current_layout_key()).ends_with("phone_landscape"))

	# the FIRST group node with touch_profile() wins
	var second := ProfileNode.new()
	second.profile = &"ep2_runner"
	add_child(second)
	second.add_to_group(MobileLayoutManager.GROUP_WANTED)
	await _enter(&"blaze")
	_check("the first group node with touch_profile() wins", MobileLayoutManager.current_profile() == &"blaze")
	second.queue_free()
	await _frames(1)

	# an unknown profile is the platformer (with a warning), never a crash
	await _enter(&"nonsense_profile")
	_check("an unknown profile name falls back to the platformer", MobileLayoutManager.current_profile() == &"platformer")

	# none hides and releases
	await _enter(&"ep2_foot")
	TouchActions.press(&"move_right")
	var released_before: int = MobileLayoutManager.release_count()
	await _enter(&"none")
	_check("profile none hides the controls and releases everything", not MobileLayoutManager.controls_visible and not TouchActions.is_held(&"move_right") and MobileLayoutManager.current_profile() == &"none")
	_check("...with exactly one release", MobileLayoutManager.release_count() == released_before + 1, "delta=%d" % (MobileLayoutManager.release_count() - released_before))

	# a profile change while visible releases ONCE and swaps the layout at once
	await _enter(&"ep2_foot")
	var old_layout: TouchLayout = MobileLayoutManager.layout()
	TouchActions.press(&"move_right")
	released_before = MobileLayoutManager.release_count()
	_pn.profile = &"ep2_runner"
	MobileLayoutManager.refresh()
	_check("a profile change releases everything exactly once", MobileLayoutManager.release_count() == released_before + 1 and not TouchActions.is_held(&"move_right"),
			"delta=%d" % (MobileLayoutManager.release_count() - released_before))
	_check("the old layout is gone immediately (never drawn beside the new one)", not is_instance_valid(old_layout) or not old_layout.is_inside_tree())
	_check("the new layout is the runner's", MobileLayoutManager.layout().profile == &"ep2_runner" and MobileLayoutManager.controls_visible)
	await _frames(2)

	# build BEFORE show: layout_changed fires before the controls become visible, and the
	# layout is already the right one when they do
	await _enter(&"ep2_rotate")
	await _enter(&"none")
	var order: Array[String] = []
	var on_layout := func(k: StringName) -> void: order.append("layout:%s" % k)
	var on_vis := func(shown: bool) -> void: order.append("vis:%s:%s" % [shown, MobileLayoutManager.current_layout_key()])
	MobileLayoutManager.layout_changed.connect(on_layout)
	MobileLayoutManager.controls_visibility_changed.connect(on_vis)
	await _enter(&"ep2_film")
	MobileLayoutManager.layout_changed.disconnect(on_layout)
	MobileLayoutManager.controls_visibility_changed.disconnect(on_vis)
	_check("build-before-show: the new layout exists before the layer is shown",
			order.size() == 2 and order[0].begins_with("layout:ep2_film") and order[1].begins_with("vis:true:ep2_film"), str(order))

	# a key press still flips keyboard mode under a profile, a finger flips it back
	MobileLayoutManager.force_touch_ui = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check("a key press hides the controls under a profile (keyboard mode)", not MobileLayoutManager.controls_visible and TouchUi.is_keyboard_mode() and TouchUi.keys_shown())
	_touch(0, true, Vector2(5, 5))
	_touch(0, false, Vector2(5, 5))
	await _frames(2)
	_check("a finger brings them back", MobileLayoutManager.controls_visible and not TouchUi.is_keyboard_mode())
	MobileLayoutManager.force_touch_ui = true

	# the scene can ask for "up but inert" (the armory is open) without orphaning a thumb
	await _enter(&"ep2_runner")
	_pn.suspended = true
	MobileLayoutManager.refresh()
	await _frames(1)
	_check("touch_suspended() keeps the controls up but suspended", MobileLayoutManager.controls_visible and MobileLayoutManager.controls_suspended and TouchActions.is_suspended())
	_pn.suspended = false
	MobileLayoutManager.refresh()
	await _frames(1)
	_check("...and resumes when it clears", MobileLayoutManager.controls_visible and not MobileLayoutManager.controls_suspended and not TouchActions.is_suspended())

	# touch_profile_changed refreshes at once (no waiting for the 5 Hz poll)
	await _enter(&"ep2_foot")
	_pn.profile = &"ep2_film"
	_pn.touch_profile_changed.emit()
	_check("touch_profile_changed swaps the profile immediately", MobileLayoutManager.current_profile() == &"ep2_film")

	# portrait: each profile's portrait scene
	await _enter(&"blaze")
	await _set_screen(Vector2i(390, 844))
	_check("rotating to portrait builds the profile's portrait scene", MobileLayoutManager.current_layout_key() == &"blaze_phone_portrait", str(MobileLayoutManager.current_layout_key()))
	await _set_screen(Vector2i(1024, 768))
	_check("a tablet window builds the profile's tablet scene", MobileLayoutManager.current_layout_key() == &"blaze_tablet_landscape", str(MobileLayoutManager.current_layout_key()))
	await _set_screen(Vector2i(844, 390))

	# per-profile first-run pulse
	MobileLayoutManager._hints_seen.erase(&"ep2_foot")
	await _enter(&"none")
	var foot: TouchLayout = await _enter(&"ep2_foot")
	var pulsed: bool = false
	for c in foot.controls():
		pulsed = pulsed or c.hint_active
	_check("the first appearance of a profile plays its own wordless pulse", pulsed and bool(MobileLayoutManager._hints_seen.get(&"ep2_foot", false)))
	var quiet: PackedStringArray = []
	for quiet_profile in [&"ep2_film", &"ep2_end", &"ep2_rotate"]:
		MobileLayoutManager._hints_seen.erase(quiet_profile)
		await _enter(&"none")
		var lay_q: TouchLayout = await _enter(quiet_profile)
		for c in lay_q.controls():
			if c.hint_active:
				quiet.append(str(quiet_profile))
	_check("the film / end / rotate profiles never pulse", quiet.is_empty(), str(quiet))
	await _enter(&"none")

# --- the tap field (Blaze) ---------------------------------------------------------------------

func _test_tap_field() -> void:
	print(" tap field:")
	await _enter(&"blaze")
	var lay: TouchLayout = MobileLayoutManager.layout()
	var field := _find(lay, "VirtualTapField") as VirtualTapField
	_check("blaze: the tap field is the layout's first control and covers the viewport", field != null and lay.controls()[0] == field and field.size.is_equal_approx(MobileLayoutManager.metrics().viewport_size))
	var p := Vector2(300, 260)
	var q := Vector2(900, 380)
	TouchActions.release_all()
	_seen.clear()
	_touch(0, true, p)
	await _frames(2)
	_check("a tap anywhere presses jump", Input.is_action_pressed(&"jump"))
	_check("one finger = exactly ONE jump down (the emulated mouse never double-fires)", _count("jump:down") == 1, str(_seen))
	_touch(1, true, q)
	await _frames(2)
	_check("a SECOND finger while the first rests is a fresh jump edge", _count("jump:down") == 2, str(_seen))
	_touch(0, false, p)
	await _frames(2)
	_check("lifting one finger keeps jump held while another is down", Input.is_action_pressed(&"jump") and field.finger_count() == 1)
	_touch(1, false, q)
	await _frames(2)
	_check("the last finger up releases jump", not Input.is_action_pressed(&"jump") and field.finger_count() == 0)
	# a tap on the pause button does not jump (the button is above the field)
	var pause := lay.find_button(&"pause")
	_seen.clear()
	_touch(2, true, _centre(pause))
	await _frames(2)
	_check("a touch on PAUSE reaches PAUSE, not the field", Input.is_action_pressed(&"pause") and _count("jump:down") == 0, str(_seen))
	_touch(2, false, _centre(pause))
	await _frames(2)
	# hide with a finger down: released at once, the lift later does nothing
	_touch(0, true, p)
	await _frames(2)
	_check("(setup) finger down", Input.is_action_pressed(&"jump"))
	MobileLayoutManager.set_locked(&"tap_test", true)
	_check("hiding releases the jump the field was holding", not Input.is_action_pressed(&"jump") and field.finger_count() == 0)
	_touch(0, false, p)
	await _frames(1)
	# orphan: a finger that pressed while hidden is never adopted
	_seen.clear()
	_touch(3, true, p)
	await _frames(1)
	MobileLayoutManager.set_locked(&"tap_test", false)
	await _frames(2)
	_drag(3, p + Vector2(40, 0), Vector2(40, 0))
	await _frames(1)
	_touch(3, false, p)
	await _frames(2)
	_check("a finger that pressed while hidden is never adopted (no jump, nothing stuck)", _count("jump:down") == 0 and not Input.is_action_pressed(&"jump") and field.finger_count() == 0, str(_seen))
	# a real (non-emulated) mouse click still counts as one finger
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _to_window(p)
	_seen.clear()
	Input.parse_input_event(click)
	await _frames(2)
	_check("a real mouse click (touch laptop) presses jump once", Input.is_action_pressed(&"jump") and _count("jump:down") == 1, str(_seen))
	var unclick := InputEventMouseButton.new()
	unclick.button_index = MOUSE_BUTTON_LEFT
	unclick.pressed = false
	unclick.position = _to_window(p)
	Input.parse_input_event(unclick)
	await _frames(2)
	_check("...and its release lets go", not Input.is_action_pressed(&"jump"))
	# focus loss
	_touch(0, true, p)
	await _frames(2)
	MobileLayoutManager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("focus loss releases the field", not Input.is_action_pressed(&"jump") and field.finger_count() == 0)
	_touch(0, false, p)
	await _frames(2)
	await _enter(&"none")

# --- the swipe pad, with real fingers ----------------------------------------------------------

## One finger: down at the pad centre, two drag steps by `vec_dp`, a beat, optionally lift.
func _swipe(pad: VirtualSwipePad, vec_dp: Vector2, lift: bool = true, finger: int = 0) -> void:
	var dpu: float = MobileLayoutManager.metrics().dp
	var start: Vector2 = _centre(pad)
	_touch(finger, true, start)
	await _frames(1)
	_drag(finger, start + vec_dp * dpu * 0.5)
	await _frames(1)
	_drag(finger, start + vec_dp * dpu)
	await _frames(1)
	if lift:
		_touch(finger, false, start + vec_dp * dpu)
		await _frames(1)

func _test_swipe_pad_live() -> void:
	print(" swipe pad (real fingers):")
	await _enter(&"ep2_runner")
	var lay: TouchLayout = MobileLayoutManager.layout()
	var pad := _find(lay, "VirtualSwipePad") as VirtualSwipePad
	var dpu: float = MobileLayoutManager.metrics().dp
	_check("the pad's left edge is >= 24 dp inboard (OS back-swipe strip)", pad.global_position.x >= 24.0 * dpu - 0.5, "%.1f dp" % (pad.global_position.x / dpu))
	TouchActions.release_all()

	_seen.clear()
	await _swipe(pad, Vector2(34, 0))
	await _wait_pulse()
	_check("swipe right pulses move_right once", _count("move_right:down") == 1 and _count("move_right:up") == 1 and not Input.is_action_pressed(&"move_right"), str(_seen))
	_seen.clear()
	await _swipe(pad, Vector2(-34, 0))
	await _wait_pulse()
	_check("swipe left pulses move_left once", _count("move_left:down") == 1 and not Input.is_action_pressed(&"move_left"), str(_seen))
	_seen.clear()
	await _swipe(pad, Vector2(0, -34))
	await _wait_pulse()
	_check("swipe up pulses jump once", _count("jump:down") == 1 and not Input.is_action_pressed(&"jump"), str(_seen))
	_check("a swipe never presses anything it should not", _count("move_left:down") == 0 and _count("move_right:down") == 0 and _count("move_down:down") == 0, str(_seen))

	# duck: held while the finger is low, released when it comes back
	await _swipe(pad, Vector2(0, 34), false)
	_check("swipe down presses move_down and HOLDS it", Input.is_action_pressed(&"move_down") and pad.is_ducking())
	await _wait(0.25)
	_check("...still held while the finger stays down", Input.is_action_pressed(&"move_down"))
	_drag(0, _centre(pad))
	await _frames(2)
	_check("bringing the finger back above the anchor releases it", not Input.is_action_pressed(&"move_down") and not pad.is_ducking())
	_touch(0, false, _centre(pad))
	await _frames(1)
	# flick: lift at once, the duck lasts its minimum hold
	await _swipe(pad, Vector2(0, 34), true)
	_check("a flick down keeps the duck after the finger lifted (min hold)", Input.is_action_pressed(&"move_down"))
	await _wait(0.35)
	_check("...and lets go after its minimum hold", not Input.is_action_pressed(&"move_down") and not pad.is_ducking())

	# suspension: the pad drops its duck itself and does not resume it
	await _swipe(pad, Vector2(0, 34), false)
	_check("(setup) ducking with the finger down", Input.is_action_pressed(&"move_down"))
	StateMachine.change_state(StateMachine.State.PAUSED)
	await _frames(2)
	_check("pause releases the duck", not Input.is_action_pressed(&"move_down") and not TouchActions.is_held(&"move_down"))
	StateMachine.change_state(StateMachine.State.PLAYING)
	await _frames(2)
	_check("resume does NOT bring the duck back (move_down is a RESUME action, the pad cleared it)", not Input.is_action_pressed(&"move_down") and not TouchActions.is_held(&"move_down"))
	_drag(0, _centre(pad) + Vector2(0, 50.0 * dpu))
	await _frames(2)
	_check("the finger that was down across the suspension is ignored until it lifts", not Input.is_action_pressed(&"move_down") and not pad.is_ducking())
	_touch(0, false, _centre(pad))
	await _frames(2)
	_seen.clear()
	await _swipe(pad, Vector2(0, -34))
	await _wait_pulse()
	_check("a fresh finger steers normally after the suspension", _count("jump:down") == 1, str(_seen))

	# a swipe made while suspended does nothing and does not fire on respawn
	StateMachine.change_state(StateMachine.State.GAME_OVER)
	await _frames(2)
	_seen.clear()
	await _swipe(pad, Vector2(0, -34), false)
	await _swipe(pad, Vector2(34, 0), false, 1)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await _frames(2)
	await _wait_pulse()
	_check("gestures made during a death do nothing, now or at respawn", _count("jump:down") == 0 and _count("move_right:down") == 0 and not Input.is_action_pressed(&"move_down"), str(_seen))
	_drag(0, _centre(pad) + Vector2(0, -90.0 * dpu))
	await _frames(1)
	_drag(1, _centre(pad) + Vector2(60.0 * dpu, 0))
	await _frames(1)
	await _wait_pulse()
	_check("fingers that PRESSED during a death never steer after the respawn, however far they drag", _count("jump:down") == 0 and _count("move_right:down") == 0, str(_seen))
	_touch(0, false, _centre(pad))
	_touch(1, false, _centre(pad))
	await _frames(2)

	# a second finger while the first owns the pad is ignored
	_seen.clear()
	_touch(0, true, _centre(pad))
	await _frames(1)
	_touch(1, true, _centre(pad) + Vector2(10, 0))
	await _frames(1)
	_drag(1, _centre(pad) + Vector2(10.0 + 40.0 * dpu, 0))
	await _frames(2)
	await _wait_pulse()
	_check("a second finger on the pad does not steer it", _count("move_right:down") == 0, str(_seen))
	_touch(1, false, _centre(pad))
	_touch(0, false, _centre(pad))
	await _frames(2)

	# orphan: a finger that pressed while the controls were hidden is never adopted
	MobileLayoutManager.set_locked(&"swipe_test", true)
	_touch(2, true, _centre(pad))
	await _frames(1)
	MobileLayoutManager.set_locked(&"swipe_test", false)
	await _frames(2)
	_seen.clear()
	_drag(2, _centre(pad) + Vector2(0, -34.0 * dpu))
	await _frames(1)
	_drag(2, _centre(pad) + Vector2(0, -70.0 * dpu))
	await _frames(1)
	await _wait_pulse()
	_check("a finger that pressed while hidden is never adopted by the pad", _count("jump:down") == 0, str(_seen))
	_touch(2, false, _centre(pad))
	await _frames(2)

	# hide with a duck held releases it
	await _swipe(pad, Vector2(0, 34), false)
	_check("(setup) ducking", Input.is_action_pressed(&"move_down"))
	MobileLayoutManager.set_locked(&"swipe_test", true)
	_check("hiding releases a held duck", not Input.is_action_pressed(&"move_down") and not pad.is_ducking())
	_touch(0, false, _centre(pad))
	MobileLayoutManager.set_locked(&"swipe_test", false)
	await _frames(2)

	# rotation with a duck held releases it
	await _swipe(pad, Vector2(0, 34), false)
	_check("(setup) ducking before the rotation", Input.is_action_pressed(&"move_down"))
	await _set_screen(Vector2i(390, 844))
	_check("rotating rebuilds the layout and releases a held duck", not Input.is_action_pressed(&"move_down"))
	await _set_screen(Vector2i(844, 390))
	_touch(0, false, Vector2(300, 300))
	await _frames(2)
	await _enter(&"none")

# --- the look pad ----------------------------------------------------------------------------------

func _test_look_pad_live() -> void:
	print(" look pad:")
	await _enter(&"ep2_foot")
	var lay: TouchLayout = MobileLayoutManager.layout()
	var look := _find(lay, "VirtualLookPad") as VirtualLookPad
	var dpu: float = MobileLayoutManager.metrics().dp
	var unit_look: float = VirtualLookPad.REFERENCE_UNITS_PER_DP * look.gain
	var p: Vector2 = look.global_position + look.size * Vector2(0.5, 0.25)
	TouchActions.release_all()
	TouchActions.take_look()
	_touch(0, true, p)
	await _frames(1)
	_drag(0, p + Vector2(2.0 * dpu, 0), Vector2(2.0 * dpu, 0))
	await _frames(1)
	_check("a 2 dp tremor is inside the slop: no look", TouchActions.take_look() == Vector2.ZERO)
	_drag(0, p + Vector2(5.0 * dpu, 0), Vector2(3.0 * dpu, 0))
	await _frames(1)
	var got: Vector2 = TouchActions.take_look()
	_check("past the slop the ACCUMULATED travel is applied (5 dp x gain, no lag)", _near(got.x, 5.0 * unit_look, 0.6) and _near(got.y, 0.0, 0.01), "got %s want %f" % [str(got), 5.0 * unit_look])
	_drag(0, p + Vector2(15.0 * dpu, 0), Vector2(10.0 * dpu, 0))
	await _frames(1)
	_drag(0, p + Vector2(15.0 * dpu, 5.0 * dpu), Vector2(0, 5.0 * dpu))
	await _frames(1)
	got = TouchActions.take_look()
	_check("two drags in one frame accumulate (10 dp right + 5 dp down)", _near(got.x, 10.0 * unit_look, 0.6) and _near(got.y, 5.0 * unit_look, 0.6), "got %s" % str(got))
	_drag(0, p + Vector2(15.0 * dpu, -400.0 * dpu), Vector2(0, -400.0 * dpu))
	await _frames(1)
	got = TouchActions.take_look()
	_check("one huge drag event is clamped (48 dp)", _near(got.y, -VirtualLookPad.MAX_STEP_DP * unit_look, 1.0), "got %s want %f" % [str(got), -VirtualLookPad.MAX_STEP_DP * unit_look])
	# a second finger on the pad is ignored while the first owns it
	_touch(1, true, p + Vector2(50, 0))
	await _frames(1)
	_drag(1, p + Vector2(80, 0), Vector2(30, 0))
	await _frames(1)
	_check("a second finger on the pad adds no look", TouchActions.take_look() == Vector2.ZERO)
	_touch(1, false, p + Vector2(80, 0))
	_touch(0, false, p)
	await _frames(2)
	_drag(0, p + Vector2(60, 0), Vector2(60, 0))
	await _frames(1)
	_check("after the finger lifts, stray drags with its index do nothing", TouchActions.take_look() == Vector2.ZERO)

	# hide clears the accumulator and drops the finger; a finger pressed while hidden is never adopted
	_touch(0, true, p)
	await _frames(1)
	_drag(0, p + Vector2(10.0 * dpu, 0), Vector2(10.0 * dpu, 0))
	await _frames(1)
	MobileLayoutManager.set_locked(&"look_test", true)
	_check("hiding clears the look accumulator and drops the finger", TouchActions.look_pending() == Vector2.ZERO and not look.is_active())
	_touch(0, false, p)
	_touch(4, true, p)
	await _frames(1)
	MobileLayoutManager.set_locked(&"look_test", false)
	await _frames(2)
	_drag(4, p + Vector2(40.0 * dpu, 0), Vector2(40.0 * dpu, 0))
	await _frames(1)
	_check("a finger that pressed while hidden is never adopted", TouchActions.take_look() == Vector2.ZERO and not look.is_active())
	_touch(4, false, p)
	await _frames(2)

	# suspension: clears, and a drag during the suspension banks nothing
	_touch(0, true, p)
	await _frames(1)
	_drag(0, p + Vector2(10.0 * dpu, 0), Vector2(10.0 * dpu, 0))
	await _frames(1)
	StateMachine.change_state(StateMachine.State.PAUSED)
	await _frames(2)
	_check("suspending clears the accumulator", TouchActions.look_pending() == Vector2.ZERO)
	_drag(0, p + Vector2(40.0 * dpu, 0), Vector2(30.0 * dpu, 0))
	await _frames(1)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await _frames(2)
	_check("a drag made during the suspension banks no camera jump", TouchActions.take_look() == Vector2.ZERO)
	_drag(0, p + Vector2(50.0 * dpu, 0), Vector2(10.0 * dpu, 0))
	await _frames(1)
	_check("the same finger keeps steering the camera after the resume", _near(TouchActions.take_look().x, 10.0 * unit_look, 0.6))
	_touch(0, false, p)
	await _frames(2)

	# the buttons above the pad win their own touches and move no camera
	var fire := lay.find_button(&"attack")
	_seen.clear()
	_touch(0, true, _centre(fire))
	await _frames(2)
	_drag(0, _centre(fire) + Vector2(30, 0), Vector2(30, 0))
	await _frames(1)
	_check("FIRE (above the look region) fires and turns nothing", Input.is_action_pressed(&"attack") and TouchActions.take_look() == Vector2.ZERO)
	_touch(0, false, _centre(fire))
	await _frames(2)

	# the foot stick is analog both ways through the real pipeline
	var stick := lay.find_role(&"stick") as VirtualJoystick
	var radius: float = stick.base_radius_dp * stick.unit
	var origin: Vector2 = stick.global_position + stick.size * Vector2(0.5, 0.45)
	_touch(0, true, origin)
	await _frames(1)
	_drag(0, origin + Vector2(0, -radius * 0.29))
	await _frames(2)
	var walk: float = Input.get_axis("move_down", "move_up")
	_check("foot stick: a light push forward walks gently through real fingers", walk > 0.3 and walk < 0.6, "axis=%f" % walk)
	_drag(0, origin + Vector2(radius * 0.5, -radius * 0.8))
	await _frames(2)
	_check("foot stick: forward + strafe together", Input.get_axis("move_down", "move_up") > 0.9 and Input.get_axis("move_left", "move_right") > 0.5)
	_touch(0, false, origin)
	await _frames(2)
	await _enter(&"none")

# --- buttons: glyphs, hold ring, arm delay, touch-only actions ----------------------------------------

func _test_buttons_live() -> void:
	print(" buttons (SKIP ring, arm delay, touch-only):")
	# SKIP: presses jump, fills a ring while held, emits hold_completed, resets on lift
	var lay: TouchLayout = await _enter(&"ep2_film")
	var skip := lay.find_button(&"jump")
	var done: Array[bool] = [false]
	skip.hold_completed.connect(func() -> void: done[0] = true)
	_touch(0, true, _centre(skip))
	await _frames(2)
	_check("SKIP presses the ordinary jump action", Input.is_action_pressed(&"jump") and skip.is_down())
	await _wait(0.45)
	_check("the hold ring is about half full at half the hold (0.45 / 0.9 s)", skip.ring_progress > 0.3 and skip.ring_progress < 0.75, "ring=%f" % skip.ring_progress)
	_check("hold_completed has not fired yet", not done[0])
	await _wait(0.6)
	_check("the ring completes and hold_completed fires once", done[0] and skip.ring_progress >= 0.999)
	_touch(0, false, _centre(skip))
	await _frames(2)
	_check("lifting resets the ring and releases jump", skip.ring_progress == 0.0 and not Input.is_action_pressed(&"jump"))
	_touch(0, true, _centre(skip))
	await _frames(2)
	MobileLayoutManager.set_locked(&"btn_test", true)
	_check("hiding with SKIP held resets the ring and releases jump", skip.ring_progress == 0.0 and not Input.is_action_pressed(&"jump"))
	_touch(0, false, _centre(skip))
	MobileLayoutManager.set_locked(&"btn_test", false)
	await _frames(2)

	# arm delay: retry / home ignore a press that lands as they appear
	lay = await _enter(&"ep2_end")
	var retry := lay.find_button(&"jump")
	_check("retry starts disarmed", not retry.is_armed() and retry.arm_delay_s >= 0.5)
	_seen.clear()
	_touch(0, true, _centre(retry))
	await _frames(2)
	_check("a press during the arming window does nothing", not Input.is_action_pressed(&"jump") and _count("jump:down") == 0 and not retry.is_down(), str(_seen))
	_touch(0, false, _centre(retry))
	await _wait(0.9)
	_check("retry is armed after the beat", retry.is_armed())
	_touch(0, true, _centre(retry))
	await _frames(2)
	_check("...and then works (jump = try again)", Input.is_action_pressed(&"jump"))
	_touch(0, false, _centre(retry))
	await _frames(2)
	var home := lay.find_button(&"ui_cancel")
	_touch(0, true, _centre(home))
	await _frames(2)
	_check("home presses ui_cancel (the existing 'back to menu' action)", Input.is_action_pressed(&"ui_cancel"))
	_touch(0, false, _centre(home))
	await _frames(2)

	# touch-only actions are registered the moment a layout using them is built
	await _enter(&"ep2_foot")
	var registered: bool = true
	for action in [&"ep2_touch_jump", &"ep2_touch_aim", &"ep2_touch_reload"]:
		registered = registered and InputMap.has_action(action) and InputMap.action_get_events(action).is_empty()
	_check("ep2_touch_jump / aim / reload exist as EMPTY actions (no key can collide)", registered)
	await _enter(&"ep2_runner")
	_check("ep2_touch_swipe exists as an empty action", InputMap.has_action(&"ep2_touch_swipe") and InputMap.action_get_events(&"ep2_touch_swipe").is_empty())
	var rl: TouchLayout = MobileLayoutManager.layout()
	var pick := rl.find_button(&"ep2_touch_swipe")
	_seen.clear()
	_touch(0, true, _centre(pick))
	await _frames(2)
	_check("the pickaxe button presses ep2_touch_swipe", Input.is_action_pressed(&"ep2_touch_swipe") and _count("ep2_touch_swipe:down") == 1, str(_seen))
	_touch(0, false, _centre(pick))
	await _frames(2)
	_check("...and releases it", not Input.is_action_pressed(&"ep2_touch_swipe"))
	await _enter(&"none")

# --- the rotate cue -----------------------------------------------------------------------------------

func _test_rotate_cue() -> void:
	print(" rotate cue:")
	var probe := Probe.new()
	add_child(probe)
	await _set_screen(Vector2i(390, 844))
	await _enter(&"none")
	_touch(0, true, Vector2(400, 900))
	await _frames(2)
	_touch(0, false, Vector2(400, 900))
	await _frames(2)
	_check("(control) with no controls up a tap reaches the game", probe.touches >= 1 and probe.mice >= 1, "touches=%d mice=%d" % [probe.touches, probe.mice])
	probe.touches = 0
	probe.mice = 0
	var lay: TouchLayout = await _enter(&"ep2_rotate")
	_check("portrait: the rotate profile builds the cue on layer 60", MobileLayoutManager.current_layout_key() == &"ep2_rotate_phone_portrait" and _layer_value() == 60)
	_check("TouchUi.is_portrait() agrees", TouchUi.is_portrait())
	_touch(0, true, Vector2(400, 900))
	await _frames(2)
	_touch(0, false, Vector2(400, 900))
	await _frames(2)
	_check("the rotate cue swallows touches (no stray shot into the paused room)", probe.touches == 0 and probe.mice == 0, "touches=%d mice=%d" % [probe.touches, probe.mice])
	var cue := _find(lay, "VirtualRotateCue") as VirtualRotateCue
	_check("the cue covers the whole viewport", cue != null and cue.size.is_equal_approx(MobileLayoutManager.metrics().viewport_size))
	probe.queue_free()
	await _set_screen(Vector2i(844, 390))
	await _enter(&"none")

# --- the scoped hide fade -----------------------------------------------------------------------------------

func _test_hide_fade() -> void:
	print(" scoped hide fade:")
	var lay: TouchLayout = await _enter(&"blaze")
	await _wait(0.3)
	var layer: CanvasLayer = MobileLayoutManager.get_node("TouchLayer")
	# an ordinary hide is instant
	MobileLayoutManager.set_locked(&"fade_test", true)
	_check("an ordinary hide is instant (layer hidden, no fade running)", not layer.visible and not MobileLayoutManager.is_hide_fading())
	MobileLayoutManager.set_locked(&"fade_test", false)
	await _frames(2)
	# the requested one fades, inert, released at once
	TouchActions.tap(&"jump")
	MobileLayoutManager.request_fade_hide(0.12)
	MobileLayoutManager.set_locked(&"fade_test", true)
	var inert: bool = true
	for c in lay.controls():
		inert = inert and c.mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check("a requested hide fades: layer still drawn, controls inert, held actions released AT ONCE",
			layer.visible and MobileLayoutManager.is_hide_fading() and inert and TouchActions.held_count() == 0 and not MobileLayoutManager.controls_visible)
	_seen.clear()
	_touch(0, true, Vector2(300, 260))
	await _frames(2)
	_check("a finger landing during the fade presses nothing", not Input.is_action_pressed(&"jump") and _count("jump:down") == 0, str(_seen))
	_touch(0, false, Vector2(300, 260))
	await _wait(0.3)
	var restored: bool = true
	for c in lay.controls():
		restored = restored and c.mouse_filter == Control.MOUSE_FILTER_STOP
	_check("after the fade the layer is hidden and the controls listen again", not layer.visible and not MobileLayoutManager.is_hide_fading() and restored)
	# the request is one-shot: the next hide is instant again
	MobileLayoutManager.set_locked(&"fade_test", false)
	await _frames(2)
	MobileLayoutManager.set_locked(&"fade_test", true)
	_check("the request was one-shot (the next hide is instant)", not layer.visible and not MobileLayoutManager.is_hide_fading())
	MobileLayoutManager.set_locked(&"fade_test", false)
	await _frames(2)
	# a stale request expires
	MobileLayoutManager.request_fade_hide(0.12)
	MobileLayoutManager._fade_hide_until_ms = Time.get_ticks_msec() - 1
	MobileLayoutManager.set_locked(&"fade_test", true)
	_check("a stale request (> 1.5 s old) is ignored", not layer.visible and not MobileLayoutManager.is_hide_fading())
	MobileLayoutManager.set_locked(&"fade_test", false)
	await _frames(2)
	# showing again during the fade cancels it cleanly
	MobileLayoutManager.request_fade_hide(0.3)
	MobileLayoutManager.set_locked(&"fade_test", true)
	_check("(setup) fading", MobileLayoutManager.is_hide_fading())
	MobileLayoutManager.set_locked(&"fade_test", false)
	await _frames(2)
	var live: bool = true
	for c in MobileLayoutManager.layout().controls():
		live = live and c.mouse_filter == Control.MOUSE_FILTER_STOP
	_check("showing again mid-fade ends the fade, restores the controls and keeps the layer up", not MobileLayoutManager.is_hide_fading() and layer.visible and MobileLayoutManager.controls_visible and live)
	await _wait(0.4)
	_check("...and the old fade timer never hides it afterwards", layer.visible and MobileLayoutManager.controls_visible)
	await _enter(&"none")

# --- an overlay of the game's own, under a layer-60 profile ----------------------------------------------

func _all_filters(lay: TouchLayout, filter: int) -> bool:
	for c in lay.controls():
		if c.mouse_filter != filter:
			return false
	return true

func _test_suspended_overlay() -> void:
	print(" suspended controls on layer 60 hand the touch to a lower overlay:")
	var probe := Probe.new()
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(probe)
	var lay: TouchLayout = await _enter(&"blaze")
	await _wait(0.3)
	var spot := Vector2(300, 260)
	_touch(0, true, spot)
	await _frames(2)
	_touch(0, false, spot)
	await _frames(2)
	_check("live: the blaze tap field takes the touch (nothing falls through)", probe.touches == 0 and probe.mice == 0, "touches=%d mice=%d" % [probe.touches, probe.mice])
	StateMachine.change_state(StateMachine.State.PAUSED)
	await _frames(2)
	_check("paused: the layer-60 controls go inert (mouse_filter IGNORE)", MobileLayoutManager.controls_suspended and _all_filters(MobileLayoutManager.layout(), Control.MOUSE_FILTER_IGNORE))
	_touch(0, true, spot)
	await _frames(2)
	_touch(0, false, spot)
	await _frames(2)
	_check("paused: a tap reaches the overlay underneath (the Blaze pause card)", probe.touches >= 1, "touches=%d" % probe.touches)
	_check("paused: and presses nothing", not Input.is_action_pressed(&"jump") and TouchActions.held_count() == 0)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await _frames(2)
	_check("resumed: the controls listen again", not MobileLayoutManager.controls_suspended and _all_filters(MobileLayoutManager.layout(), Control.MOUSE_FILTER_STOP))
	probe.touches = 0
	_touch(0, true, spot)
	await _frames(2)
	_touch(0, false, spot)
	await _frames(2)
	_check("resumed: the tap field swallows the tap again", probe.touches == 0)
	# a layer-18 profile keeps its old suspended behaviour (dimmed, still listening)
	lay = await _enter(&"ep2_runner")
	StateMachine.change_state(StateMachine.State.PAUSED)
	await _frames(2)
	_check("a layer-18 profile stays listening while suspended (its pause card sits ABOVE it)", MobileLayoutManager.controls_suspended and _all_filters(MobileLayoutManager.layout(), Control.MOUSE_FILTER_STOP))
	StateMachine.change_state(StateMachine.State.PLAYING)
	await _frames(2)
	# a layout rebuilt while suspended starts inert too (no listening window)
	await _enter(&"blaze")
	StateMachine.change_state(StateMachine.State.PAUSED)
	await _frames(2)
	await _set_screen(Vector2i(390, 844))
	_check("a layout built while suspended starts inert", MobileLayoutManager.controls_suspended and _all_filters(MobileLayoutManager.layout(), Control.MOUSE_FILTER_IGNORE))
	await _set_screen(Vector2i(844, 390))
	StateMachine.change_state(StateMachine.State.PLAYING)
	await _frames(2)
	probe.queue_free()
	await _enter(&"none")

# --- release on every path ---------------------------------------------------------------------------------

func _test_release_paths() -> void:
	print(" release paths:")
	# tablet scenes at tier 1.2 still release everything on a layout swap
	await _enter(&"blaze")
	await _set_screen(Vector2i(1024, 768))
	_check("(setup) the tablet window got the tablet tap field", MobileLayoutManager.current_layout_key() == &"blaze_tablet_landscape")
	_touch(0, true, Vector2(500, 300))
	await _frames(2)
	_check("(setup) the tablet tap field holds jump", Input.is_action_pressed(&"jump"))
	await _set_screen(Vector2i(390, 844))
	_check("rotating from a tablet to a phone portrait releases the held tap", not Input.is_action_pressed(&"jump"))
	_touch(0, false, Vector2(500, 300))
	await _frames(2)
	await _set_screen(Vector2i(844, 390))
	await _enter(&"none")
	_check("nothing is held at the end", TouchActions.held_count() == 0, str(TouchActions._held.keys()))
