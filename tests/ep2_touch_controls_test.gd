extends Node
## Gate for Episode 2 Part 1 on a PHONE (the mine runner + the Smelting Facility on foot): every claim in the touch build
## is driven by real fingers (Input.parse_input_event -> GUI -> the real layout controls -> TouchActions -> InputMap) through
## the real MobileLayoutManager with the real Ep2SessionRoot + RunnerGraybox, and by pure state wherever a number matters.
##
##   1. profile selection table: runner / on foot / film / TRANSITION / armory open / portrait / run over
##   2. runner gestures: swipe left/right (lane +-1, ammo untouched), swipe up (airborne), hold down (duck + the 150 ms minimum
##      hold), pickaxe -> swipe, attack -> -1 round, a tap in a free area fires once (no double fire), steer + fire fingers
##   3. lifecycle: pause/death suspend drops a held duck and it is NOT restored; a mode swap releases everything; the chained
##      foot -> foot hand-over keeps held input and never flips the profile to none
##   4. on foot: F5 (move_* InputEventAction must not walk/cover), F6 (ep2_touch_jump jumps, W does not), F8 (the emulated mouse
##      never fires/looks/captures; a real mouse still does), look pad -> yaw, ADS press/release, reload, the keyboard map
##   5. films: holding the SKIP button 0.9 s skips the real Ep2VideoFilm and the in-engine film; no button at non-skippable moments
##   6. portrait pauses the sim behind a cue (+ a HOME icon so a locked phone is never trapped), landscape resumes
##   7. Ep2Entry: PLAYING on the menu route, the wordless pause card (PAUSED, PLAY resumes), the run-over profile + retry
##   8. WORDLESS: with the touch flag forced none of the audit-F9 strings is produced by ep2_entry / runner_view / fps_hud /
##      smelting_facility / the films, and the desktop strings are still there with the flag off
##
## Run: godot --headless res://tests/ep2_touch_controls_test.tscn      (1280x720 window)
## Ends with `EP2_TOUCH_CONTROLS: ALL PASS` (exit 0) or `N FAILURE(S)` (exit N). Optional: `-- only=<section>` runs one section.

const ROOT_SCENE := preload("res://src/episode2/session/ep2_session_root.tscn")
const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
const ENTRY := preload("res://src/episode2/ep2_entry.tscn")

## A recording stand-in for an on-foot room: what the router calls, and the answers the profile table reads.
class FootStub extends Node:
	var control: bool = true
	var armory: bool = false
	var film: bool = false
	var calls: Array[String] = []
	var move: Vector2 = Vector2.ZERO
	var looked: Vector2 = Vector2.ZERO
	var aim: bool = false
	func set_move_input(v: Vector2, _run: bool = false) -> void:
		move = v
	func has_player_control() -> bool:
		return control
	func armory_open() -> bool:
		return armory
	func is_film_skippable() -> bool:
		return film
	func wants_mouse_capture() -> bool:
		return control
	func look(rel: Vector2) -> void:
		looked += rel
		calls.append("look")
	func jump() -> bool:
		calls.append("jump")
		return true
	func reload() -> bool:
		calls.append("reload")
		return true
	func set_aim(on: bool) -> void:
		aim = on
		calls.append("aim_on" if on else "aim_off")
	func shoot() -> bool:
		calls.append("shoot")
		return true
	func walk(_d: float) -> void:
		calls.append("walk")
	func walk_stop() -> void:
		calls.append("walk_stop")
	func take_cover() -> void:
		calls.append("cover")
	func leave_cover() -> void:
		calls.append("uncover")
	func start_rig(_p: String = "") -> bool:
		calls.append("interact")
		return true
	func early_claim() -> bool:
		return false
	func step(_d: float) -> void:
		pass

var _fail: int = 0
var _only: String = ""
var _roots: Array[Node] = []

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

# --- helpers -----------------------------------------------------------------

func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_pos

func _touch(index: int, pressed: bool, pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.pressed = pressed
	t.position = _to_window(pos)
	Input.parse_input_event(t)

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

func _dp() -> float:
	return MobileLayoutManager.metrics().dp

func _go_playing() -> void:
	if StateMachine.is_paused():
		StateMachine.change_state(StateMachine.State.PLAYING)
	if StateMachine.get_state_enum() == StateMachine.State.MENU or StateMachine.get_state_enum() == StateMachine.State.GAME_OVER \
			or StateMachine.get_state_enum() == StateMachine.State.LEVEL_COMPLETE:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	if StateMachine.get_state_enum() == StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.PLAYING)

func _set_screen(size: Vector2i) -> void:
	get_window().size = size
	await _frames(3)

## An armed runner leg far from any chamber, two archers ahead; physics off so the test owns time (step()).
func _runner_plan(chamber: String = "", chamber_z: float = 9000.0) -> Array:
	var seg: Dictionary = {"chamber_z": chamber_z, "obstacles": [], "zip_segments": [],
		"archers": [{"id": "a0", "z": 40.0, "side": 1}, {"id": "a1", "z": 80.0, "side": -1}],
		"armed": true, "gold_principal": 1000, "bears": []}
	if chamber != "":
		seg["chamber"] = chamber
	return [seg]

func _new_root(plan: Array) -> Ep2SessionRoot:
	var r: Ep2SessionRoot = ROOT_SCENE.instantiate()
	add_child(r)
	_roots.append(r)
	r.configure(plan, false)
	return r

func _start_runner(plan: Array = []) -> Ep2SessionRoot:
	TouchActions.release_all()
	var r: Ep2SessionRoot = _new_root(plan if not plan.is_empty() else _runner_plan())
	r.start()
	var g: Node = r.get_active()
	if g != null:
		g.set_physics_process(false)         # the test owns time
	await _frames(3)
	MobileLayoutManager.refresh()
	await _frames(2)
	return r

func _free_roots() -> void:
	TouchActions.release_all()
	for r in _roots:
		if is_instance_valid(r):
			r.queue_free()
	_roots.clear()

func _stub_root() -> Array:
	TouchActions.release_all()
	var r: Ep2SessionRoot = _new_root([])
	var stub := FootStub.new()
	r.add_child(stub)
	r._active = stub
	r._mode = Ep2SessionRoot.Mode.CHAMBER
	return [r, stub]

func _layout() -> TouchLayout:
	return MobileLayoutManager.layout()

func _button(action: StringName) -> VirtualButton:
	var lay: TouchLayout = _layout()
	return lay.find_button(action) if lay != null else null

func _control(type_name: String) -> VirtualControl:
	var lay: TouchLayout = _layout()
	if lay == null:
		return null
	for c in lay.controls():
		if c.get_script() != null and (c.get_script() as Script).get_global_name() == type_name:
			return c
	return null

## Drag a finger from `from` to `to` (canvas units) in small steps; leaves the finger DOWN.
func _drag_path(index: int, from: Vector2, to: Vector2, steps: int = 6) -> void:
	for i in range(1, steps + 1):
		var p: Vector2 = from.lerp(to, float(i) / float(steps))
		_drag(index, p, (to - from) / float(steps))
	await _frames(1)

## A whole swipe on the pad: down, drag, up.
func _swipe(pad: Control, delta_dp: Vector2, hold_s: float = 0.0) -> void:
	var start: Vector2 = _centre(pad)
	_touch(0, true, start)
	await _frames(1)
	await _drag_path(0, start, start + delta_dp * _dp())
	if hold_s > 0.0:
		await _wait(hold_s)
	_touch(0, false, start + delta_dp * _dp())
	await _wait_pulse()

func _step(r: Ep2SessionRoot, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		r.step(1.0 / 60.0)

func _only_ok(section: String) -> bool:
	return _only == "" or _only == section

# --- main --------------------------------------------------------------------

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("only="):
			_only = str(a).substr(5)
	get_window().size = Vector2i(1280, 720)
	await _frames(2)
	print("EP2 TOUCH CONTROLS:")
	MobileLayoutManager.force_touch_ui = true
	MobileLayoutManager.is_touch_device = true
	_go_playing()
	TouchActions.ensure_action(&"ep2_touch_swipe")
	if _only_ok("profile"):
		await _section_profiles()
	if _only_ok("runner"):
		await _section_runner()
	if _only_ok("lifecycle"):
		await _section_lifecycle()
	if _only_ok("foot"):
		await _section_foot()
	if _only_ok("film"):
		await _section_film()
	if _only_ok("portrait"):
		await _section_portrait()
	if _only_ok("entry"):
		await _section_entry()
	if _only_ok("words"):
		await _section_words()
	_free_roots()
	await _frames(2)
	_check("nothing is held at the end", TouchActions.held_count() == 0)
	if _fail == 0:
		print("EP2_TOUCH_CONTROLS: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP2_TOUCH_CONTROLS: %d FAILURE(S)" % _fail)
		get_tree().quit(_fail)

# --- 1. profile table ----------------------------------------------------------

func _section_profiles() -> void:
	print(" -- profile selection")
	_go_playing()
	var pair: Array = _stub_root()
	var r: Ep2SessionRoot = pair[0]
	var stub: FootStub = pair[1]
	_check("the session root joins the touch group (after the scene swap, in _ready)", r.is_in_group(&"touch_controls_wanted"))
	_check("IDLE (nothing running yet) -> none", (await _fresh_idle_profile()) == &"none")
	_check("CHAMBER, free roam, the player in control -> ep2_foot", r.touch_profile() == &"ep2_foot")
	_check("...not suspended", not r.touch_suspended())
	stub.armory = true
	_check("armory open -> ep2_foot (the walking thumb is not orphaned)...", r.touch_profile() == &"ep2_foot")
	_check("...but SUSPENDED", r.touch_suspended())
	stub.armory = false
	stub.control = false
	_check("a scripted beat (no player control) -> none", r.touch_profile() == &"none")
	stub.film = true
	_check("a skippable film -> ep2_film", r.touch_profile() == &"ep2_film")
	stub.film = false
	stub.control = true
	r._mode = Ep2SessionRoot.Mode.TRANSITION
	_check("TRANSITION -> none", r.touch_profile() == &"none")
	r._mode = Ep2SessionRoot.Mode.IDLE
	_check("IDLE (run over) -> none (Ep2Entry owns ep2_end)", r.touch_profile() == &"none")
	r._mode = Ep2SessionRoot.Mode.CHAMBER
	# the real manager follows the real node
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("the manager shows the on-foot layout", MobileLayoutManager.current_profile() == &"ep2_foot" and MobileLayoutManager.controls_visible,
		"%s visible=%s" % [MobileLayoutManager.current_profile(), MobileLayoutManager.controls_visible])
	_check("...and it is the ep2_foot scene (%s)" % MobileLayoutManager.current_layout_key(),
		str(MobileLayoutManager.current_layout_key()).begins_with("ep2_foot_"))
	stub.armory = true
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("armory open: controls stay up but inert (suspended)", MobileLayoutManager.controls_visible and MobileLayoutManager.controls_suspended)
	stub.armory = false
	stub.film = true
	stub.control = false
	r._touch_changed()
	await _frames(2)
	_check("a film: the manager shows the SKIP layout", MobileLayoutManager.current_profile() == &"ep2_film"
		and str(MobileLayoutManager.current_layout_key()).begins_with("ep2_film_"))
	_free_roots()
	await _frames(2)

## A fresh root that has not been started is IDLE.
func _fresh_idle_profile() -> StringName:
	var r: Ep2SessionRoot = _new_root(_runner_plan())
	return r.touch_profile()

# --- 2. runner gestures ---------------------------------------------------------

func _section_runner() -> void:
	print(" -- runner gestures (real fingers on the real ep2_runner layout)")
	_go_playing()
	var r: Ep2SessionRoot = await _start_runner()
	var g: RunnerGraybox = r.get_active() as RunnerGraybox
	_check("the runner is up and running", g != null and g.is_running() and r.get_mode() == Ep2SessionRoot.Mode.RUNNER)
	_check("RUNNER running -> ep2_runner", r.touch_profile() == &"ep2_runner" and MobileLayoutManager.current_profile() == &"ep2_runner",
		str(MobileLayoutManager.current_profile()))
	var pad: VirtualControl = _control("VirtualSwipePad")
	_check("the swipe pad is on screen", pad != null and pad.is_visible_in_tree())
	_check("the Attack and Pickaxe buttons exist", _button(&"attack") != null and _button(&"ep2_touch_swipe") != null)
	if pad == null:
		_free_roots()
		return
	var ammo0: int = g.get_ammo()
	var lane0: int = g.get_lane()
	_check("starts on the middle rail", lane0 == 1)

	await _swipe(pad, Vector2(-34.0, 0.0))
	_check("a swipe LEFT hops one rail left", g.get_lane() == lane0 - 1, str(g.get_lane()))
	_check("...and a gesture on the pad never also fires (ammo unchanged)", g.get_ammo() == ammo0, "%d -> %d" % [ammo0, g.get_ammo()])
	await _swipe(pad, Vector2(34.0, 0.0))
	_check("a swipe RIGHT hops back one rail", g.get_lane() == lane0, str(g.get_lane()))
	await _swipe(pad, Vector2(34.0, 0.0))
	_check("...and one more rail right", g.get_lane() == lane0 + 1, str(g.get_lane()))
	_check("...ammo still unchanged", g.get_ammo() == ammo0)
	await _swipe(pad, Vector2(-34.0, 0.0))

	var y0: float = g.get_cart_y()
	await _swipe(pad, Vector2(0.0, -34.0))
	_step(r, 0.12)
	_check("a swipe UP jumps (airborne)", g.get_cart_y() > y0 + 0.2, str(g.get_cart_y()))
	_step(r, 1.2)
	_check("...and lands again", is_zero_approx(g.get_cart_y()))
	_check("...no round spent by the jump", g.get_ammo() == ammo0)

	# hold DOWN = duck
	var start: Vector2 = _centre(pad)
	_touch(0, true, start)
	await _frames(1)
	await _drag_path(0, start, start + Vector2(0.0, 34.0 * _dp()))
	_check("a swipe DOWN presses the duck (held)", TouchActions.is_held(&"move_down") and g.is_duck_held())
	_step(r, 0.2)
	_check("...and the cart ducks once the hold is long enough", g.is_ducking())
	await _wait(0.2)                       # the pad's 150 ms minimum hold runs on the wall clock
	_touch(0, false, start + Vector2(0.0, 34.0 * _dp()))
	await _wait_pulse()
	_check("lifting the finger releases the duck", not TouchActions.is_held(&"move_down") and not g.is_duck_held())
	# a flick (younger than the 150 ms minimum hold) still ducks for the minimum
	_touch(0, true, start)
	await _frames(1)
	_drag(0, start + Vector2(0.0, 30.0 * _dp()))
	_touch(0, false, start + Vector2(0.0, 30.0 * _dp()))
	await _frames(1)
	_check("a flick keeps the duck for the minimum hold (150 ms)", TouchActions.is_held(&"move_down"))
	await _wait(0.35)
	_check("...then lets go by itself", not TouchActions.is_held(&"move_down"))

	# pickaxe
	var pick: VirtualButton = _button(&"ep2_touch_swipe")
	_check("not swinging before the pickaxe", not g.is_swiping())
	_touch(0, true, _centre(pick))
	await _frames(2)
	_check("the PICKAXE button swings the axe (is_swiping)", g.is_swiping())
	_touch(0, false, _centre(pick))
	await _wait_pulse()

	# attack = auto-aim shot
	_step(r, 1.0)
	var atk: VirtualButton = _button(&"attack")
	var a1: int = g.get_ammo()
	_touch(0, true, _centre(atk))
	await _frames(2)
	_check("the ATTACK button fires one round (ammo -1)", g.get_ammo() == a1 - 1, "%d -> %d" % [a1, g.get_ammo()])
	_touch(0, false, _centre(atk))
	await _wait_pulse()

	# a tap in a FREE area still fires once (emulated left press, outside every pad)
	_step(r, 1.0)
	var free: Vector2 = Vector2(MobileLayoutManager.metrics().viewport_size.x * 0.5, 14.0 * _dp())
	var a2: int = g.get_ammo()
	_touch(0, true, free)
	await _frames(2)
	_touch(0, false, free)
	await _frames(3)
	_check("a tap in a free area fires ONE round (no double fire)", g.get_ammo() == a2 - 1, "%d -> %d" % [a2, g.get_ammo()])

	# steer finger down + a second finger on ATTACK: both work
	_step(r, 1.0)
	var lane_s: int = g.get_lane()
	var a3: int = g.get_ammo()
	_touch(0, true, start)
	await _frames(1)
	_touch(1, true, _centre(atk))
	await _frames(2)
	_check("second finger on ATTACK fires while the steer finger rests", g.get_ammo() == a3 - 1, "%d -> %d" % [a3, g.get_ammo()])
	_touch(1, false, _centre(atk))
	await _drag_path(0, start, start + Vector2(-34.0 * _dp(), 0.0))
	_check("...and the steer finger still hops", g.get_lane() == lane_s - 1, "%d -> %d" % [lane_s, g.get_lane()])
	_touch(0, false, start + Vector2(-34.0 * _dp(), 0.0))
	await _wait_pulse()
	_check("no round was spent by the steer finger", g.get_ammo() == a3 - 1)

	# the runner router also takes the touch-only verbs directly
	var swing_before: bool = g.is_swiping()
	_step(r, 1.0)
	var ev := InputEventAction.new()
	ev.action = &"ep2_touch_swipe"
	ev.pressed = true
	r._unhandled_input(ev)
	_check("ep2_touch_swipe -> runner_swipe()", g.is_swiping() and not swing_before)
	_free_roots()
	await _frames(3)

# --- 3. lifecycle ---------------------------------------------------------------

func _section_lifecycle() -> void:
	print(" -- lifecycle: suspend, mode swap, chained hand-over")
	_go_playing()
	var r: Ep2SessionRoot = await _start_runner()
	var g: RunnerGraybox = r.get_active() as RunnerGraybox
	var pad: VirtualControl = _control("VirtualSwipePad")
	var start: Vector2 = _centre(pad)
	_touch(0, true, start)
	await _frames(1)
	await _drag_path(0, start, start + Vector2(0.0, 34.0 * _dp()))
	_check("(setup) a duck is held by the finger", TouchActions.is_held(&"move_down"))
	# pause (or a death) SUSPENDS the layer: the pad drops its own duck, and the resume does NOT bring it back
	StateMachine.change_state(StateMachine.State.PAUSED)
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("PAUSED: the duck is released", not TouchActions.is_held(&"move_down") and not Input.is_action_pressed(&"move_down"))
	_check("...and the layer is up but suspended", MobileLayoutManager.controls_visible and MobileLayoutManager.controls_suspended)
	StateMachine.change_state(StateMachine.State.PLAYING)
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("resumed: the duck is NOT restored by the resume", not TouchActions.is_held(&"move_down") and not Input.is_action_pressed(&"move_down"))
	_check("...and the cart is not left ducking (the release arrived while the tree was paused; the root re-syncs)", not g.is_duck_held())
	_touch(0, false, start + Vector2(0.0, 34.0 * _dp()))
	await _wait_pulse()
	_check("...and lifting the finger afterwards changes nothing", not Input.is_action_pressed(&"move_down") and not g.is_duck_held())
	_free_roots()
	await _frames(3)

	# runner -> chamber: everything is released
	var plan: Array = _runner_plan("smelting_facility", 40.0)
	r = await _start_runner(plan)
	g = r.get_active() as RunnerGraybox
	pad = _control("VirtualSwipePad")
	start = _centre(pad)
	_touch(0, true, start)
	await _frames(1)
	await _drag_path(0, start, start + Vector2(0.0, 34.0 * _dp()))
	_check("(setup) holding a duck before the swap", Input.is_action_pressed(&"move_down"))
	var guard: int = 0
	while r.get_mode() == Ep2SessionRoot.Mode.RUNNER and guard < 2400:
		guard += 1
		r.step(1.0 / 60.0)
	await _frames(3)
	_check("the runner handed over to the chamber", r.get_mode() == Ep2SessionRoot.Mode.CHAMBER, str(r.get_mode()))
	_check("mode swap releases everything (held_count == 0)", TouchActions.held_count() == 0, str(TouchActions.held_count()))
	_check("...and the duck is not pressed on Input any more", not Input.is_action_pressed(&"move_down"))
	_check("...the runner controls are gone (profile %s)" % MobileLayoutManager.current_profile(),
		MobileLayoutManager.current_profile() != &"ep2_runner")
	_touch(0, false, start)
	await _frames(2)
	_free_roots()
	await _frames(3)

	# the CHAINED foot -> foot hand-over keeps the held walk and the profile
	TouchActions.release_all()
	var chain: Ep2SessionRoot = _new_root([{"chamber_z": 6.0, "obstacles": [], "zip_segments": [], "chamber": "smelting_facility", "gold_principal": 1000}])
	var fac: Node = SMELT.instantiate()
	fac.intro_film = false
	chain.add_child(fac)
	fac.setup(0, [], 0)
	for i in 90:
		fac.step(1.0 / 60.0)
	chain._active = fac
	chain._mode = Ep2SessionRoot.Mode.CHAMBER
	chain._chamber_segment = 0
	chain._wire_chamber(fac)
	MobileLayoutManager.refresh()
	await _frames(3)
	_check("(setup) the Smelting Facility is driven on foot", fac.has_player_control() and chain.touch_profile() == &"ep2_foot",
		"control=%s profile=%s" % [fac.has_player_control(), chain.touch_profile()])
	var stick: VirtualControl = _control("VirtualJoystick")
	if stick != null:
		var sc: Vector2 = _centre(stick)
		_touch(0, true, sc)
		await _frames(1)
		await _drag_path(0, sc, sc + Vector2(0.0, -70.0 * _dp()))
		_check("(setup) the thumb holds FORWARD on the stick", Input.is_action_pressed(&"move_up"))
		var released_before: int = MobileLayoutManager.release_count()
		chain._on_chamber_cleared({"next_chamber": "mine_lift", "story": true, "gold_awarded": 0, "gold_forfeited": 0})
		MobileLayoutManager.refresh()
		await _frames(3)
		_check("(setup) the chained room is a different node", chain.get_active() != fac)
		_check("the chained foot -> foot hand-over keeps the held input", Input.is_action_pressed(&"move_up") and TouchActions.is_held(&"move_up"))
		_check("...and never released the layer (release count unchanged)", MobileLayoutManager.release_count() == released_before,
			"%d -> %d" % [released_before, MobileLayoutManager.release_count()])
		_check("...nor flipped the profile to none", chain.touch_profile() == &"ep2_foot" and MobileLayoutManager.current_profile() == &"ep2_foot",
			"%s / %s" % [chain.touch_profile(), MobileLayoutManager.current_profile()])
		_touch(0, false, sc + Vector2(0.0, -70.0 * _dp()))
		await _frames(2)
	else:
		_check("(setup) the on-foot layout has a stick", false)
	_free_roots()
	await _frames(3)

# --- 4. on foot -----------------------------------------------------------------

func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	return k

func _action(name: StringName, pressed: bool = true) -> InputEventAction:
	var a := InputEventAction.new()
	a.action = name
	a.pressed = pressed
	return a

func _section_foot() -> void:
	print(" -- on foot: router fixes (F5, F6, F8) and the touch verbs")
	_go_playing()
	var pair: Array = _stub_root()
	var r: Ep2SessionRoot = pair[0]
	var stub: FootStub = pair[1]
	MobileLayoutManager.refresh()
	await _frames(3)
	# F5: the stick presses move_* as InputEventAction; they must be swallowed in free roam, not walk/cover
	for name in [&"move_right", &"move_left", &"move_down", &"move_up"]:
		r._unhandled_input(_action(name, true))
		r._unhandled_input(_action(name, false))
	_check("F5: move_* InputEventAction in free roam never calls walk / take_cover / leave_cover",
		not stub.calls.has("walk") and not stub.calls.has("walk_stop") and not stub.calls.has("cover") and not stub.calls.has("uncover"),
		str(stub.calls))
	_check("F5: ...the router reports them handled", r._route_free_roam(_action(&"move_right", true)))
	stub.calls.clear()
	# F6: the touch jump jumps; the W key does not
	r._unhandled_input(_action(&"ep2_touch_jump", true))
	_check("F6: ep2_touch_jump -> jump()", stub.calls == ["jump"], str(stub.calls))
	stub.calls.clear()
	r._unhandled_input(_key(KEY_W, true))
	_check("F6: the W key is movement, never jump", not stub.calls.has("jump"), str(stub.calls))
	r._unhandled_input(_key(KEY_SPACE, true))
	_check("F6: Space still jumps (keyboard map unchanged)", stub.calls == ["jump"], str(stub.calls))
	stub.calls.clear()
	# ADS and reload
	r._unhandled_input(_action(&"ep2_touch_aim", true))
	_check("ep2_touch_aim pressed -> set_aim(true)", stub.aim)
	r._unhandled_input(_action(&"ep2_touch_aim", false))
	_check("ep2_touch_aim released -> set_aim(false)", not stub.aim and stub.calls == ["aim_on", "aim_off"], str(stub.calls))
	stub.calls.clear()
	r._unhandled_input(_action(&"ep2_touch_reload", true))
	_check("ep2_touch_reload -> reload()", stub.calls == ["reload"], str(stub.calls))
	stub.calls.clear()
	r._unhandled_input(_key(KEY_R, true))
	_check("R still reloads (keyboard map unchanged)", stub.calls == ["reload"], str(stub.calls))
	stub.calls.clear()
	# F8: the emulated mouse a finger makes never fires, looks or captures; a real mouse still does
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.device = InputEvent.DEVICE_ID_EMULATION
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	r._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, 10.0)
	motion.device = InputEvent.DEVICE_ID_EMULATION
	r._unhandled_input(motion)
	_check("F8: an emulated left press does not fire", not stub.calls.has("shoot"), str(stub.calls))
	_check("F8: ...an emulated drag does not look", not stub.calls.has("look") and stub.looked == Vector2.ZERO)
	_check("F8: ...and nothing captures the pointer", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	var real_press := InputEventMouseButton.new()
	real_press.button_index = MOUSE_BUTTON_LEFT
	real_press.pressed = true
	real_press.device = 0
	r._unhandled_input(real_press)
	_check("F8: a REAL mouse (device 0) still fires", stub.calls.has("shoot"), str(stub.calls))
	var real_move := InputEventMouseMotion.new()
	real_move.relative = Vector2(12.0, 0.0)
	real_move.device = 0
	r._unhandled_input(real_move)
	_check("F8: ...and still looks", stub.looked == Vector2(12.0, 0.0), str(stub.looked))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	stub.calls.clear()
	# attack (the FIRE button) still reaches the shot
	r._unhandled_input(_action(&"attack", true))
	_check("the FIRE button's `attack` action still fires", stub.calls == ["shoot"], str(stub.calls))
	stub.calls.clear()
	# F13: on a phone the persistent RUN toggle must not pick the Diamond-burn payment
	_check("(setup) touch is forced, so keys are hidden", not TouchUi.keys_shown())
	# the look pad: a real finger drag on the real pad -> the stub is told once a frame
	var look_pad: VirtualControl = _control("VirtualLookPad")
	_check("the look pad is on the on-foot layout", look_pad != null)
	if look_pad != null:
		var p0: Vector2 = look_pad.global_position + Vector2(look_pad.size.x * 0.4, look_pad.size.y * 0.5)
		_touch(0, true, p0)
		await _frames(1)
		await _drag_path(0, p0, p0 + Vector2(60.0 * _dp(), 0.0), 5)
		await _frames(2)
		_check("a drag on the look pad turns the view (look called, yaw delta > 0)", stub.calls.has("look") and stub.looked.x > 20.0, "%s %s" % [stub.calls, stub.looked])
		_check("...and the accumulator was drained (nothing banked)", TouchActions.look_pending() == Vector2.ZERO)
		_touch(0, false, p0 + Vector2(60.0 * _dp(), 0.0))
		await _frames(1)
	_free_roots()
	await _frames(3)

	# the REAL facility: look, jump, ADS and reload act on the real room
	TouchActions.release_all()
	var rr: Ep2SessionRoot = _new_root([])
	var fac: Node = SMELT.instantiate()
	fac.intro_film = false
	rr.add_child(fac)
	fac.setup(0, [], 0)
	for i in 120:
		fac.step(1.0 / 60.0)
	rr._active = fac
	rr._mode = Ep2SessionRoot.Mode.CHAMBER
	rr._wire_chamber(fac)
	MobileLayoutManager.refresh()
	await _frames(3)
	_check("(setup) the real facility is driven by the player", fac.has_player_control(), fac.get_beat_name())
	var yaw0: float = fac.get_look_yaw()
	TouchActions.add_look(Vector2(120.0, 0.0))
	rr._poll_free_roam()
	_check("look pad -> the camera yaw changes", absf(fac.get_look_yaw() - yaw0) > 0.1, "%f -> %f" % [yaw0, fac.get_look_yaw()])
	_check("...drained once", TouchActions.look_pending() == Vector2.ZERO)
	rr._unhandled_input(_action(&"ep2_touch_jump", true))
	_check("the Jump button lifts the real hero", fac._vel_y > 0.0, str(fac._vel_y))
	_free_roots()
	fac.queue_free()
	await _frames(3)

# --- 5. films -------------------------------------------------------------------

func _section_film() -> void:
	print(" -- films: the SKIP button")
	_go_playing()
	TouchActions.release_all()
	var pair: Array = _stub_root()
	var r: Ep2SessionRoot = pair[0]
	var stub: FootStub = pair[1]
	stub.control = false
	var vf := Ep2VideoFilm.new()
	vf.name = "Ep2VideoFilm"
	var prepared: bool = vf.prepare(SmeltingFacilityChamber.FILM_VIDEO, SmeltingFacilityChamber.FILM_SECONDS)
	_check("(setup) the real cliff film decodes", prepared)
	if not prepared:
		vf.free()
		_free_roots()
		return
	vf.drive_externally()
	stub.add_child(vf)
	vf.start()
	var done: Array = []
	vf.finished.connect(func() -> void: done.append(true))
	for i in 30:
		vf.step(1.0 / 60.0)
		stub.film = vf.is_skippable()
	r._touch_changed()
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("before 1 s the film is NOT skippable", not vf.is_skippable() and stub.film == false)
	_check("...so no SKIP layout is up", MobileLayoutManager.current_profile() != &"ep2_film")
	for i in 45:
		vf.step(1.0 / 60.0)
	stub.film = vf.is_skippable()
	r._touch_changed()
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("after 1 s the film is skippable", vf.is_skippable() and stub.film)
	_check("...and the SKIP layout is up (profile ep2_film, layer above the film)", MobileLayoutManager.current_profile() == &"ep2_film"
		and MobileLayoutManager.controls_visible)
	var skip: VirtualButton = _button(&"jump")
	_check("...its one button presses `jump` and carries the hold ring", skip != null and skip.hold_seconds > 0.0 and absf(skip.hold_seconds - Ep2VideoFilm.SKIP_HOLD) < 0.01,
		"hold_seconds=%s" % (str(skip.hold_seconds) if skip != null else "-"))
	if skip != null:
		# a short press does not skip
		_touch(0, true, _centre(skip))
		await _frames(2)
		_check("the SKIP button holds `jump`", Input.is_action_pressed(&"jump"))
		for i in 30:
			vf.step(1.0 / 60.0)
		_touch(0, false, _centre(skip))
		await _frames(2)
		for i in 5:
			vf.step(1.0 / 60.0)
		_check("a 0.5 s press does NOT skip the film", not vf.is_done() and done.is_empty())
		# a full hold does
		_touch(0, true, _centre(skip))
		await _frames(2)
		for i in 60:
			vf.step(1.0 / 60.0)
			if vf.is_done():
				break
		_check("holding SKIP for 0.9 s skips the film", vf.is_done() and vf.finish_reason == "skip_hold", vf.finish_reason)
		stub.film = vf.is_skippable()
		_check("...and a finished film is no longer skippable (the button goes)", not vf.is_skippable() and stub.film == false)
		r._touch_changed()
		MobileLayoutManager.refresh()
		await _frames(2)
		_check("...the manager drops the SKIP layout and releases `jump`", MobileLayoutManager.current_profile() != &"ep2_film"
			and not Input.is_action_pressed(&"jump"))
		_touch(0, false, _centre(skip))
		await _frames(2)
	for i in 6:
		vf.step(1.0 / 60.0)
	_check("...and `finished` was emitted once the picture was black", done.size() == 1, str(done.size()))

	# the in-engine fallback film
	_free_roots()
	await _frames(3)
	pair = _stub_root()
	r = pair[0]
	stub = pair[1]
	stub.control = false
	var cj := CliffJumpCinematic.new()
	stub.add_child(cj)
	await _frames(2)
	cj.start()
	cj.step(0.2)
	stub.film = cj.is_skippable()
	_check("the fallback film is not skippable in its first second", not cj.is_skippable())
	for i in 70:
		cj.step(1.0 / 60.0)
	stub.film = cj.is_skippable()
	r._touch_changed()
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("...and skippable after it", cj.is_skippable() and MobileLayoutManager.current_profile() == &"ep2_film")
	var skip2: VirtualButton = _button(&"jump")
	if skip2 != null:
		_touch(0, true, _centre(skip2))
		await _frames(2)
		for i in 60:
			cj.step(1.0 / 60.0)
			if cj.is_finished():
				break
		_check("holding SKIP skips the in-engine film", cj.is_finished())
		_touch(0, false, _centre(skip2))
		await _frames(2)
	cj.queue_free()
	_free_roots()
	await _frames(3)

# --- 6. portrait ----------------------------------------------------------------

func _section_portrait() -> void:
	print(" -- portrait: the rotate cue and the pause")
	_go_playing()
	var r: Ep2SessionRoot = await _start_runner()
	var g: RunnerGraybox = r.get_active() as RunnerGraybox
	_check("(setup) landscape runner", r.touch_profile() == &"ep2_runner" and not get_tree().paused)
	await _set_screen(Vector2i(390, 844))
	MobileLayoutManager.refresh()
	await _frames(3)
	_check("upright on a touch device -> ep2_rotate", r.touch_profile() == &"ep2_rotate", str(r.touch_profile()))
	_check("...the sim is paused (tree paused, StateMachine still PLAYING)", get_tree().paused and r.is_rotate_paused() and StateMachine.is_playing())
	_check("...the manager shows the cue layout", MobileLayoutManager.current_profile() == &"ep2_rotate"
		and str(MobileLayoutManager.current_layout_key()).begins_with("ep2_rotate_") and MobileLayoutManager.controls_visible,
		"%s %s" % [MobileLayoutManager.current_profile(), MobileLayoutManager.current_layout_key()])
	var d0: float = g.get_distance()
	await _frames(5)
	_check("...and the runner does not advance", is_equal_approx(g.get_distance(), d0))
	await _set_screen(Vector2i(1280, 720))
	MobileLayoutManager.refresh()
	await _frames(3)
	_check("back to landscape: the sim resumes", not get_tree().paused and not r.is_rotate_paused())
	_check("...and the runner profile returns", r.touch_profile() == &"ep2_runner" and MobileLayoutManager.current_profile() == &"ep2_runner")
	# nobody else's pause is taken or released
	StateMachine.change_state(StateMachine.State.PAUSED)
	await _set_screen(Vector2i(390, 844))
	_check("a pause that is not ours is never taken over", not r.is_rotate_paused())
	await _set_screen(Vector2i(1280, 720))
	_check("...and left alone when the screen turns back", get_tree().paused and StateMachine.is_paused())
	StateMachine.change_state(StateMachine.State.PLAYING)
	# a desktop (no touch) window taller than wide never pauses
	MobileLayoutManager.is_touch_device = false
	MobileLayoutManager.force_touch_ui = false
	await _set_screen(Vector2i(390, 844))
	_check("a desktop window taller than wide does NOT pause or show the cue", not get_tree().paused and r.touch_profile() == &"ep2_runner")
	await _set_screen(Vector2i(1280, 720))
	MobileLayoutManager.is_touch_device = true
	MobileLayoutManager.force_touch_ui = true
	_free_roots()
	await _frames(3)

# --- 7. Ep2Entry ----------------------------------------------------------------

func _section_entry() -> void:
	print(" -- Ep2Entry: PLAYING on the menu route, the pause card, the run-over profile")
	TouchActions.release_all()
	# the menu route leaves the StateMachine in TRANSITIONING and nothing set PLAYING
	if StateMachine.is_paused():
		StateMachine.change_state(StateMachine.State.PLAYING)
	if StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	_check("(setup) the state is TRANSITIONING as after SceneRouter.load_scene", StateMachine.is_state(StateMachine.State.TRANSITIONING))
	_check("(setup) the director is idle", TransitionDirector.state == TransitionDirector.S.IDLE)
	GameManager.ep2_story_unlocked = true         # the earned bypass, so the access gate stays out of the test
	var entry: Node = ENTRY.instantiate()
	add_child(entry)
	await _frames(3)
	_check("the access gate is not up", entry._gate == null)
	_check("_begin() moves TRANSITIONING -> PLAYING when the director is idle", StateMachine.is_playing())
	var er: Ep2SessionRoot = entry._root as Ep2SessionRoot
	_check("the session started a runner", er != null and er.get_mode() == Ep2SessionRoot.Mode.RUNNER)
	var run: Node = er.get_active()
	if run != null:
		run.set_physics_process(false)
	MobileLayoutManager.refresh()
	await _frames(3)
	_check("the touch layer shows the RUNNER controls on the menu route", MobileLayoutManager.controls_visible and MobileLayoutManager.current_profile() == &"ep2_runner",
		"%s visible=%s" % [MobileLayoutManager.current_profile(), MobileLayoutManager.controls_visible])
	# the pause button -> the wordless card
	var pause_btn: VirtualButton = _button(&"pause")
	_check("the runner layout has a Pause button", pause_btn != null)
	if pause_btn != null:
		_touch(0, true, _centre(pause_btn))
		await _frames(2)
		_touch(0, false, _centre(pause_btn))
		await _frames(2)
		var ov: Ep2TouchOverlay = entry.get_overlay()
		_check("the PAUSE button opens the pause card", entry.is_pause_open() and ov != null and ov.is_open() and ov.mode() == Ep2TouchOverlay.Mode.PAUSE)
		_check("...the sim is paused (StateMachine PAUSED, tree paused)", StateMachine.is_paused() and get_tree().paused)
		_check("...pause_menu.tscn is NOT used", entry.find_children("*", "CanvasLayer", true, false).all(func(n: Node) -> bool: return n.get_script() == null or str(n.get_script().resource_path).find("pause_menu") < 0))
		_check("...the layer underneath is suspended (dim, inert)", MobileLayoutManager.controls_suspended)
		_check("PLAY and HOME hit areas are both >= 72 dp", ov.play_hit_radius() * 2.0 >= 72.0 * _dp() and ov.home_hit_radius() * 2.0 >= 72.0 * _dp(),
			"%f %f" % [ov.play_hit_radius() * 2.0, ov.home_hit_radius() * 2.0])
		_check("...and they do not overlap", ov.play_center().distance_to(ov.home_center()) > ov.play_hit_radius() + ov.home_hit_radius())
		_check("home is wired to the Escape path", ov.home_pressed.is_connected(entry._go_home) and ov.resume_pressed.is_connected(entry._close_pause))
		# a real finger on PLAY (down and up on the pad) resumes
		_touch(0, true, ov.play_center())
		await _frames(2)
		_touch(0, false, ov.play_center())
		await _frames(3)
		_check("a tap on PLAY resumes the sim", not entry.is_pause_open() and StateMachine.is_playing() and not get_tree().paused and not ov.is_open())
		# a second finger works while a thumb rests (touch trap 11)
		_touch(0, true, _centre(pause_btn))
		await _frames(2)
		_touch(0, false, _centre(pause_btn))
		await _frames(2)
		_check("(setup) paused again", entry.is_pause_open())
		_touch(3, true, ov.play_center())
		await _frames(2)
		_touch(3, false, ov.play_center())
		await _frames(3)
		_check("a SECOND finger (index 3, no emulated click) can tap PLAY", not entry.is_pause_open() and StateMachine.is_playing())
	# the run ends: ep2_end, retry
	if run != null:
		entry._on_session_failed()
		await _frames(2)
		MobileLayoutManager.refresh()
		await _frames(3)
		_check("the run over -> the ep2_end profile (Ep2Entry joined the group)", MobileLayoutManager.current_profile() == &"ep2_end"
			and entry.is_in_group(&"touch_controls_wanted"), str(MobileLayoutManager.current_profile()))
		_check("...no banner text", entry._banner.text == "")
		_check("...a dim last frame stands behind the buttons (the screen is not black)", entry.has_scrim())
		var retry: VirtualButton = _button(&"jump")
		var home: VirtualButton = _button(&"ui_cancel")
		_check("...retry (jump) and home (ui_cancel) buttons", retry != null and home != null)
		if retry != null:
			var retry_at: Vector2 = _centre(retry)         # (the layout is rebuilt the moment retry works: keep the point)
			_touch(0, true, retry_at)
			await _frames(2)
			_touch(0, false, retry_at)
			await _frames(2)
			_check("a tap on retry too early (arm delay) does nothing", entry.is_ended())
			await _wait(0.9)
			_touch(0, true, retry_at)
			await _frames(2)
			_touch(0, false, retry_at)
			await _frames(3)
			_check("retry after the arm delay restarts the run", not entry.is_ended() and entry._root.get_mode() == Ep2SessionRoot.Mode.RUNNER,
				"ended=%s mode=%s" % [entry.is_ended(), entry._root.get_mode()])
			_check("...the scrim is gone and the group is left", not entry.has_scrim() and not entry.is_in_group(&"touch_controls_wanted"))
			MobileLayoutManager.refresh()
			await _frames(3)
			_check("...and the runner controls are back", MobileLayoutManager.current_profile() == &"ep2_runner", str(MobileLayoutManager.current_profile()))
	entry.queue_free()
	GameManager.ep2_story_unlocked = false
	TouchActions.release_all()
	await _frames(3)
	_go_playing()

# --- 8. wordless ------------------------------------------------------------------

## Words that name a key or give a control instruction (the audit-F9 list and the neighbours it missed).
const BAD_WORDS: Array[String] = ["SPACE", "SKIP", "R - reload", "R — reload", "RELOAD", "RELOADING", "[E]", "[R]", "Tab", "HOLD", "PRESS",
	"CLICK", "click", "RIGHT MOUSE", "LEFT CLICK", "ESC", "WASD", "right-click", "SWIPE", "try again", "play again", "OUT OF ROUNDS",
	"JUMP", "DUCK", "HOP", "SHOOT"]

## The first bad word in `text` ("" = clean). Plain words match as WHOLE words ("DESCENT" is not "ESC"); phrases with symbols match as is.
func _has_bad(text: String) -> String:
	for w in BAD_WORDS:
		var plain: bool = w.strip_edges().is_valid_identifier() or w.replace(" ", "").is_valid_identifier()
		if plain and not " " in w:
			var re := RegEx.new()
			re.compile("\\b%s\\b" % w)
			if re.search(text) != null:
				return w
		elif w in text:
			return w
	return ""

func _collect_texts(node: Node, out: Array) -> void:
	if node is Label:
		if (node as Label).visible and (node as Label).text != "":
			out.append(["Label " + str(node.name), (node as Label).text])
	elif node is Label3D:
		if (node as Label3D).text != "":
			out.append(["Label3D " + str(node.name), (node as Label3D).text])
	elif node is Button:
		if (node as Button).visible and (node as Button).text != "":
			out.append(["Button " + str(node.name), (node as Button).text])
	for c in node.get_children():
		_collect_texts(c, out)

func _section_words() -> void:
	print(" -- wordless on touch (and the desktop words are still there)")
	_go_playing()
	TouchActions.release_all()
	# --- the runner view: telegraph labels, reload words
	var plan: Array = [{"chamber_z": 9000.0, "obstacles": [
		{"z": 60.0, "lane": 1, "type": "box"}, {"z": 90.0, "lane": 0, "type": "arrow"}, {"z": 120.0, "lane": 2, "type": "boulder"},
		{"z": 150.0, "lane": 1, "type": "boarder"}], "zip_segments": [{"start_z": 200.0, "end_z": 230.0}],
		"archers": [{"id": "a0", "z": 70.0, "side": 1}], "armed": true, "gold_principal": 1000, "bears": []}]
	var r: Ep2SessionRoot = await _start_runner(plan)
	var g: RunnerGraybox = r.get_active() as RunnerGraybox
	var view: RunnerView = g.get_node("View") as RunnerView
	_step(r, 0.1)
	await _frames(4)
	_check("(setup) touch is forced, so the view is in cue-glyph mode", view.is_cue_wordless())
	var texts: Array = []
	_collect_texts(view, texts)
	var bad: Array = []
	for t in texts:
		var w: String = _has_bad(str(t[1]))
		if w != "":
			bad.append("%s '%s' (%s)" % [t[0], str(t[1]).replace("\n", " "), w])
	_check("runner_view on touch: no instruction / key word in any label (%d texts scanned)" % texts.size(), bad.is_empty(), str(bad))
	var glyphs: int = 0
	for l in view._cue_labels:
		if is_instance_valid(l) and l.get_node_or_null("CueGlyph") != null:
			glyphs += 1
	_check("...the telegraphs carry cue glyphs instead (%d)" % glyphs, glyphs >= 4, str(glyphs))
	# the reload hint / label are hidden at low ammo; the cylinder pips pulse
	g._ammo = 1
	await _frames(3)
	_check("low ammo: 'R - reload' is hidden on touch", not view._hint_label.visible)
	g._reloading = true
	g._reload_t = 0.3
	await _frames(3)
	_check("reloading: 'RELOADING' is hidden on touch (the bar says it)", not view._reload_label.visible)
	g._reloading = false
	g._ammo = 6
	# the reticle: no resting reticle at (0,0); a brief ring at the last tap only
	await _frames(2)
	_check("no resting reticle on touch (hidden before any tap)", not view._reticle.visible)
	_check("the gun arm keeps its forward default (no aim point)", not view._aim_ok)
	var tap_pos := Vector2(900.0, 300.0)
	_touch(0, true, tap_pos)
	await _frames(2)
	_touch(0, false, tap_pos)
	await _frames(1)
	_check("a tap in a free area shows a brief ring at the tap point", view._reticle.visible and view._reticle.position.distance_to(tap_pos - view._reticle.size * 0.5) < 2.0,
		str(view._reticle.position))
	_check("...and aims the gun arm there for a moment", view._aim_ok)
	await _wait(0.8)
	_check("...then the ring is gone", not view._reticle.visible)
	_check("...and the gun arm is forward again", not view._aim_ok)
	# desktop: the words are back when the touch flag is off
	MobileLayoutManager.is_touch_device = false
	MobileLayoutManager.force_touch_ui = false
	_step(r, 0.1)
	await _frames(3)
	_check("flag off (desktop): the cue words return", not view.is_cue_wordless())
	var words_back: bool = false
	for l in view._cue_labels:
		if is_instance_valid(l) and str(l.text) != "":
			words_back = true
	_check("...the telegraph labels read their words again", words_back)
	g._ammo = 1
	await _frames(3)
	_check("...and 'R - reload' shows at low ammo", view._hint_label.visible)
	_check("...the reticle is the mouse crosshair again", view._reticle.visible)
	MobileLayoutManager.is_touch_device = true
	MobileLayoutManager.force_touch_ui = true
	_free_roots()
	await _frames(3)

	# --- the HUD of the hideout: holster label, search button, objective, toasts
	var hud := Ep2FpsHud.new()
	add_child(hud)
	hud.armory = Ep2ArmoryState.new()
	await _frames(3)
	hud.set_search_prompt("Search bear [E]")
	hud._update_armory()
	_check("fps_hud on touch: the holster button carries no key label ('HOLD Tab')", hud._hold_button.text == "", hud._hold_button.text)
	_check("...'Search bear [E]' is hidden", not hud._search.visible)
	hud.objective = "PRESS  R  TO LOAD THE WINCHESTER   (2 / 4)"
	hud.lesson_token = Ep2FpsHud.Token.CYLINDER
	hud.lesson_count = 2
	hud.lesson_count_max = 4
	hud.toast("OUT OF ROUNDS  -  PRESS R", 1.0, Ep2FpsHud.Token.CYLINDER)
	await _frames(2)
	var drawn: Array = []
	_collect_texts(hud, drawn)
	var hud_bad: Array = []
	for t in drawn:
		if _has_bad(str(t[1])) != "":
			hud_bad.append(t)
	_check("...no Label / Button of the HUD names a key", hud_bad.is_empty(), str(hud_bad))
	hud.queue_free()
	await _frames(2)

	# --- the lesson objective strings stay (desktop) and the touch path is token-only
	var fac: Node = SMELT.instantiate()
	add_child(fac)
	fac.setup(0, [], 0)
	fac.set_physics_process(false)
	await _frames(1)
	fac._on_video_film_finished()                  # the founder's film ends here: the real hand-off into the lesson
	for i in 30:
		fac.step(1.0 / 60.0)
	fac._lesson = fac.Lesson.LOAD
	fac._push_hud(0.0)
	var h: Ep2FpsHud = fac._hud_ctl
	_check("smelting_facility pushes the lesson as an icon (LOAD -> cylinder, 'n of 4')", h != null and h.lesson_token == Ep2FpsHud.Token.CYLINDER
		and h.lesson_count_max == 4, str(h.lesson_token) if h != null else "no hud")
	fac._lesson = fac.Lesson.PRACTICE
	fac._push_hud(0.0)
	_check("PRACTICE -> targets, with the plates left", h.lesson_token == Ep2FpsHud.Token.TARGETS and h.lesson_count == fac._molds_left)
	fac._lesson = fac.Lesson.AIM
	fac._push_hud(0.0)
	_check("AIM -> scope", h.lesson_token == Ep2FpsHud.Token.SCOPE)
	fac._lesson = fac.Lesson.FIRE
	fac._push_hud(0.0)
	_check("FIRE -> burst", h.lesson_token == Ep2FpsHud.Token.BURST)
	fac._lesson = fac.Lesson.LEAD
	fac._push_hud(0.0)
	_check("LEAD -> boot", h.lesson_token == Ep2FpsHud.Token.BOOT)
	_check("the desktop objective strings are untouched ('PRESS R', 'RIGHT MOUSE', 'LEFT CLICK')",
		_lesson_words(fac, fac.Lesson.LOAD).contains("PRESS") and _lesson_words(fac, fac.Lesson.AIM).contains("RIGHT MOUSE")
		and _lesson_words(fac, fac.Lesson.FIRE).contains("LEFT CLICK"))
	fac.queue_free()
	await _frames(2)

	# --- the films: no hint words on touch, hint on desktop
	var vf := Ep2VideoFilm.new()
	if vf.prepare(SmeltingFacilityChamber.FILM_VIDEO, SmeltingFacilityChamber.FILM_SECONDS):
		vf.drive_externally()
		add_child(vf)
		vf.start()
		for i in 120:
			vf.step(1.0 / 60.0)
		await _frames(2)
		var ft: Array = []
		_collect_texts(vf, ft)
		var film_bad: Array = []
		for t in ft:
			if _has_bad(str(t[1])) != "":
				film_bad.append(t)
		_check("Ep2VideoFilm on touch: no 'HOLD SPACE TO SKIP' (visible labels: %d)" % ft.size(), film_bad.is_empty(), str(film_bad))
		MobileLayoutManager.is_touch_device = false
		MobileLayoutManager.force_touch_ui = false
		await _frames(3)
		var hint_visible: bool = false
		for c in vf.get_children():
			if c is Label and (c as Label).text.contains("SKIP") and (c as Label).visible:
				hint_visible = true
		_check("...and the desktop hint is still there with the flag off", hint_visible)
		MobileLayoutManager.is_touch_device = true
		MobileLayoutManager.force_touch_ui = true
		vf.queue_free()
	else:
		_check("(setup) the cliff film decodes", false)
	var cj := CliffJumpCinematic.new()
	add_child(cj)
	await _frames(2)
	cj.start()
	cj.step(0.1)
	var hint: Label = cj.find_children("SkipHint", "Label", true, false)[0] as Label
	_check("CliffJumpCinematic on touch: the 'hold SPACE to skip' hint is hidden", not hint.visible)
	MobileLayoutManager.is_touch_device = false
	MobileLayoutManager.force_touch_ui = false
	cj.step(0.1)
	_check("...and shown on a desktop", hint.visible)
	MobileLayoutManager.is_touch_device = true
	MobileLayoutManager.force_touch_ui = true
	cj.queue_free()
	await _frames(2)

	# --- Ep2Entry strings: banners and the K strip are never produced on touch
	if StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	GameManager.ep2_story_unlocked = true
	var entry: Node = ENTRY.instantiate()
	add_child(entry)
	await _frames(3)
	entry._keys_t = 5.0
	entry._on_session_complete()
	entry._refresh_hud()
	var et: Array = []
	_collect_texts(entry, et)
	var entry_bad: Array = []
	for t in et:
		if _has_bad(str(t[1])) != "":
			entry_bad.append(t)
	_check("Ep2Entry on touch: the run-over banner and the K control strip are empty", entry_bad.is_empty() and entry._banner.text == "", str(entry_bad))
	MobileLayoutManager.is_touch_device = false
	MobileLayoutManager.force_touch_ui = false
	entry._on_session_failed()
	_check("...and the desktop banner still names its keys with the flag off", entry._banner.text.contains("SPACE") and entry._banner.text.contains("ESC"))
	MobileLayoutManager.is_touch_device = true
	MobileLayoutManager.force_touch_ui = true
	entry.queue_free()
	GameManager.ep2_story_unlocked = false
	await _frames(2)
	_go_playing()
	_check("Episode2Mode.control_hint is intact (the interlude test asserts it)", Episode2Mode.control_hint(Episode2Mode.Mode.FPS).contains("WASD"))

func _lesson_words(fac: Node, lesson: int) -> String:
	fac._lesson = lesson
	return fac._lesson_objective()
