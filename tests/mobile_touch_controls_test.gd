extends Node
## Gate for the on-screen touch controls (src/input/mobile/).
##
## Drives the REAL pipeline end to end on the shipped engine, no mocks:
##   synthetic finger events -> Godot GUI -> VirtualJoystick / VirtualButton
##   -> TouchActions -> InputMap -> the real player.tscn
## and also pins the pure parts (device classification, dp maths, stick shaping,
## layout geometry on phone / tablet / notch / portrait / tiny screens).
##
## What it proves, in the order of the founder's acceptance list:
##   * movement is ANALOG (a light tilt walks slower than a firm one)
##   * stick + JUMP + ATK work AT THE SAME TIME (independent fingers)
##   * a finger that slides off a control still releases it (no stuck inputs)
##   * hiding the controls (pause / lock / keyboard) releases every held action
##   * keyboard still reaches the same actions untouched
##   * no two buttons overlap and nothing lands off-screen at any screen size
##   * the profile layouts (blaze, ep2_runner, ep2_foot, ep2_film, ep2_end, ep2_rotate) hold
##     the same geometry rules on every screen, keep clear of the Episode 2 HUD, and have no text
##
## Run: godot --headless res://tests/mobile_touch_controls_test.tscn

const PLAYER := preload("res://src/player/player.tscn")

var _fail: int = 0
var _seen_actions: Array[String] = []

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _near(a: float, b: float, eps: float = 0.03) -> bool:
	return absf(a - b) <= eps

func _input(event: InputEvent) -> void:
	# records the InputEventActions TouchActions pushes (the _input / _unhandled_input path)
	if event is InputEventAction:
		var a := event as InputEventAction
		_seen_actions.append("%s:%s" % [a.action, "down" if a.pressed else "up"])

func _ready() -> void:
	# The headless window defaults to 64x64; pin the project's own 1280x720 so the
	# layout chosen (and the maths below) is deterministic.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	print("MOBILE TOUCH CONTROLS:")
	_test_metrics()
	_test_stick_shaping()
	await _test_layout_geometry()
	await _test_profile_layout_geometry()
	await _test_context_cue()
	await _test_touch_actions()
	await _test_live_controls()
	await _test_visibility_rules()
	await _test_stick_edges_and_orphans()
	await _test_film_opt_in()
	await _test_player_integration()
	print("MOBILE_TOUCH_CONTROLS: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	TouchActions.release_all()
	get_tree().quit(_fail)

# --- helpers -----------------------------------------------------------------

## Events injected through Input are in WINDOW pixels; our controls live in canvas
## units. The viewport's final transform is exactly that mapping, so the test is
## correct at any window size (it is 1:1 only at the base 1280x720).
func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_pos

func _touch(index: int, pressed: bool, pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.pressed = pressed
	t.position = _to_window(pos)
	Input.parse_input_event(t)

func _drag(index: int, pos: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = _to_window(pos)
	d.relative = Vector2.ZERO
	Input.parse_input_event(d)

func _centre(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5

## Game viewport for a window under project stretch "canvas_items" + "expand".
func _expand_viewport(window: Vector2) -> Vector2:
	var aspect: float = window.x / window.y
	if aspect >= 1280.0 / 720.0:
		return Vector2(720.0 * aspect, 720.0)
	return Vector2(1280.0, 1280.0 / aspect)

# --- pure: device + dp -------------------------------------------------------

func _test_metrics() -> void:
	print(" metrics:")
	_check("phone below 600dp short side", TouchMetrics.classify(390.0, true) == TouchMetrics.CLASS_PHONE)
	_check("tablet at 768dp", TouchMetrics.classify(768.0, true) == TouchMetrics.CLASS_TABLET)
	_check("no touchscreen is always desktop", TouchMetrics.classify(390.0, false) == TouchMetrics.CLASS_DESKTOP)
	_check("landscape detected", TouchMetrics.orientation_of(Vector2(2532, 1170)) == TouchMetrics.LANDSCAPE)
	_check("portrait detected", TouchMetrics.orientation_of(Vector2(1170, 2532)) == TouchMetrics.PORTRAIT)
	_check("layout key: phone landscape", TouchMetrics.layout_key(&"phone", &"landscape") == &"phone_landscape")
	_check("layout key: tablet landscape", TouchMetrics.layout_key(&"tablet", &"landscape") == &"tablet_landscape")
	_check("layout key: any portrait", TouchMetrics.layout_key(&"tablet", &"portrait") == &"phone_portrait")

	# iPhone-class: 844x390 CSS px at device pixel ratio 3
	var win := Vector2(2532, 1170)
	var m := TouchMetrics.compute(_expand_viewport(win), win, 3.0, Vector4.ZERO, true)
	_check("phone: classified phone", m.device_class == TouchMetrics.CLASS_PHONE)
	_check("phone: 1dp = 720/390 canvas units", _near(m.dp, 720.0 / 390.0, 0.01), "dp=%f" % m.dp)
	# iPad-class: 1024x768 CSS px at DPR 2
	var win2 := Vector2(2048, 1536)
	var m2 := TouchMetrics.compute(_expand_viewport(win2), win2, 2.0, Vector4.ZERO, true)
	_check("tablet: classified tablet", m2.device_class == TouchMetrics.CLASS_TABLET)
	_check("tablet: 1dp = 960/768 canvas units", _near(m2.dp, 960.0 / 768.0, 0.01), "dp=%f" % m2.dp)
	# a notch: 132px left cutout on a 2532px wide phone
	var m3 := TouchMetrics.compute(_expand_viewport(win), win, 3.0, Vector4(132, 0, 0, 102), true)
	_check("notch inset shrinks the safe rect", m3.safe_rect.position.x > m.safe_rect.position.x + 20.0)
	_check("home bar inset shrinks the bottom", m3.safe_rect.end.y < m.safe_rect.end.y - 10.0)
	# an absurd inset report is capped, never swallowing the screen
	var m4 := TouchMetrics.compute(_expand_viewport(win), win, 3.0, Vector4(99999, 99999, 99999, 99999), true)
	_check("junk insets are capped", m4.safe_rect.size.x > m4.viewport_size.x * 0.55 and m4.safe_rect.size.y > m4.viewport_size.y * 0.55)
	_check("web (no insets) still keeps a minimum edge margin", m.safe_rect.position.x > 0.0 and m.safe_rect.end.y < m.viewport_size.y)

# --- pure: stick shaping -----------------------------------------------------

func _test_stick_shaping() -> void:
	print(" stick shaping:")
	_check("dead zone is silent", VirtualJoystick.shape_horizontal(0.10) == 0.0)
	var light: float = VirtualJoystick.shape_horizontal(0.29)
	var firm: float = VirtualJoystick.shape_horizontal(0.80)
	_check("light tilt walks gently (0.3..0.6)", light > 0.3 and light < 0.6, "got %f" % light)
	_check("firm tilt is faster than light", firm > light + 0.25, "light=%f firm=%f" % [light, firm])
	_check("full speed before the physical rim", VirtualJoystick.shape_horizontal(0.90) == 1.0)
	_check("left is the mirror of right", _near(VirtualJoystick.shape_horizontal(-0.5), -VirtualJoystick.shape_horizontal(0.5), 0.0001))
	_check("monotonic up the whole range", _monotonic())
	_check("vertical needs a deliberate push", VirtualJoystick.vertical_state(Vector2(0.0, -0.40), 0) == 0)
	_check("straight up engages", VirtualJoystick.vertical_state(Vector2(0.0, -0.80), 0) == -1)
	_check("straight down engages", VirtualJoystick.vertical_state(Vector2(0.0, 0.80), 0) == 1)
	_check("running right with thumb drifting up never climbs", VirtualJoystick.vertical_state(Vector2(0.90, -0.50), 0) == 0)
	_check("a steep diagonal still climbs", VirtualJoystick.vertical_state(Vector2(0.30, -0.80), 0) == -1)
	_check("hysteresis: stays up a bit below the engage level", VirtualJoystick.vertical_state(Vector2(0.0, -0.50), -1) == -1)
	_check("hysteresis: but a fresh press at that level does not", VirtualJoystick.vertical_state(Vector2(0.0, -0.50), 0) == 0)

func _monotonic() -> bool:
	var prev: float = -1.0
	for i in 101:
		var v: float = VirtualJoystick.shape_horizontal(float(i) / 100.0)
		if v < prev - 0.00001:
			return false
		prev = v
	return true

# --- pure-ish: layout geometry -----------------------------------------------

func _test_layout_geometry() -> void:
	print(" layout geometry (every layout, every screen):")
	var screens := [
		{"name": "iPhone 844x390 @3", "win": Vector2(2532, 1170), "dpr": 3.0, "ins": Vector4(132, 0, 132, 102)},
		{"name": "small Android 640x360 @2.6", "win": Vector2(1664, 936), "dpr": 2.6, "ins": Vector4.ZERO},
		{"name": "wide Android 915x412 @2.6", "win": Vector2(2379, 1071), "dpr": 2.6, "ins": Vector4.ZERO},
		{"name": "iPad 1024x768 @2", "win": Vector2(2048, 1536), "dpr": 2.0, "ins": Vector4.ZERO},
		{"name": "iPad Pro 1366x1024 @2", "win": Vector2(2732, 2048), "dpr": 2.0, "ins": Vector4.ZERO},
		{"name": "phone portrait 390x844 @3", "win": Vector2(1170, 2532), "dpr": 3.0, "ins": Vector4.ZERO},
		{"name": "desktop emulation 1280x720 @1", "win": Vector2(1280, 720), "dpr": 1.0, "ins": Vector4.ZERO},
	]
	for s in screens:
		var win: Vector2 = s["win"]
		var vp: Vector2 = _expand_viewport(win)
		var m := TouchMetrics.compute(vp, win, s["dpr"], s["ins"], true)
		var key: StringName = TouchMetrics.layout_key(m.device_class, m.orientation)
		var scene: PackedScene = MobileLayoutManager.LAYOUT_SCENES[key]
		var lay := scene.instantiate() as TouchLayout
		add_child(lay)
		lay.apply(m, 1.0, MobileLayoutManager.DEFAULT_THEME)
		var label: String = "%s -> %s" % [s["name"], key]
		var inside := true
		var overlap := ""
		var stick: VirtualJoystick = null
		var buttons: Array[VirtualButton] = []
		for c in lay.controls():
			if c is VirtualJoystick:
				stick = c
			elif c is VirtualButton:
				buttons.append(c)
		var view := Rect2(Vector2.ZERO, vp).grow(0.5)
		for b in buttons:
			if not view.encloses(Rect2(b.global_position, b.size)):
				inside = false
		for i in buttons.size():
			for j in range(i + 1, buttons.size()):
				var d: float = _centre(buttons[i]).distance_to(_centre(buttons[j]))
				if d < buttons[i].size.x * 0.5 + buttons[j].size.x * 0.5:
					overlap = "%s x %s" % [buttons[i].name, buttons[j].name]
		_check("%s: every button fully on screen" % label, inside)
		_check("%s: no two buttons overlap" % label, overlap == "", overlap)
		var region := Rect2(stick.global_position, stick.size)
		var centres_clear := true
		for b in buttons:
			if region.has_point(_centre(b)):
				centres_clear = false
		_check("%s: no button sits inside the stick region" % label, centres_clear)
		_check("%s: stick region is on screen" % label, view.encloses(region))
		# thumb-size sanity: the JUMP disc is >= 9mm-ish (>= 48dp across)
		var jump := lay.find_button(&"jump")
		_check("%s: JUMP target >= 48dp" % label, jump.size.x / m.dp >= 48.0, "%f dp" % (jump.size.x / m.dp))
		lay.queue_free()
		await get_tree().process_frame

## Screens the profile loop runs on (the same list as the platformer loop above).
const GEOMETRY_SCREENS := [
	{"name": "iPhone 844x390 @3", "win": Vector2(2532, 1170), "dpr": 3.0, "ins": Vector4(132, 0, 132, 102)},
	{"name": "small Android 640x360 @2.6", "win": Vector2(1664, 936), "dpr": 2.6, "ins": Vector4.ZERO},
	{"name": "wide Android 915x412 @2.6", "win": Vector2(2379, 1071), "dpr": 2.6, "ins": Vector4.ZERO},
	{"name": "iPad 1024x768 @2", "win": Vector2(2048, 1536), "dpr": 2.0, "ins": Vector4.ZERO},
	{"name": "iPad Pro 1366x1024 @2", "win": Vector2(2732, 2048), "dpr": 2.0, "ins": Vector4.ZERO},
	{"name": "phone portrait 390x844 @3", "win": Vector2(1170, 2532), "dpr": 3.0, "ins": Vector4.ZERO},
	{"name": "desktop emulation 1280x720 @1", "win": Vector2(1280, 720), "dpr": 1.0, "ins": Vector4.ZERO},
]
const PROFILES_UNDER_TEST: Array[StringName] = [&"blaze", &"ep2_runner", &"ep2_foot", &"ep2_film", &"ep2_end", &"ep2_rotate"]
## Episode 2 HUD keep-outs, in CANVAS units (the HUD is drawn in canvas units, not dp; at the
## reference phone 150 x 96 units are the 81 x 52 dp of the brief): the ammo pips + reload bar
## at the bottom-right, and the holster hold button at the bottom-centre (140 x 80, scaled by
## width / 390 in portrait exactly as ep2_fps_hud.gd does).
const AMMO_HUD_UNITS := Vector2(150.0, 96.0)
const HOLSTER_UNITS := Vector2(140.0, 80.0)

## Does any node under `root` carry written words? (Label-like classes, or a non-empty
## `text` / `tooltip_text`.) Returns the first offender's description, or "".
func _first_text_node(root: Node) -> String:
	var text_classes := ["Label", "RichTextLabel", "Button", "LinkButton", "CheckBox", "CheckButton", "MenuButton",
		"OptionButton", "LineEdit", "TextEdit", "CodeEdit"]
	for cls in text_classes:
		if root.is_class(cls):
			return "%s is a %s" % [root.name, cls]
	for prop in ["text", "tooltip_text"]:
		if prop in root and str(root.get(prop)) != "":
			return "%s.%s = '%s'" % [root.name, prop, str(root.get(prop))]
	for child in root.get_children():
		var found: String = _first_text_node(child)
		if found != "":
			return found
	return ""

## The profile layouts, on every screen: on screen, no overlaps, >= 44 dp hit areas, inside
## the safe rect, the Episode 2 HUD keep-outs, the left-edge inset of the swipe pad, no words,
## and the profile's own content.
func _test_profile_layout_geometry() -> void:
	print(" profile layouts (every profile, every screen):")
	var available: Array = MobileLayoutManager.LAYOUT_SCENES.keys() + MobileLayoutManager.PROFILE_SCENES.keys()
	for s in GEOMETRY_SCREENS:
		var win: Vector2 = s["win"]
		var vp: Vector2 = _expand_viewport(win)
		var m := TouchMetrics.compute(vp, win, s["dpr"], s["ins"], true)
		var view := Rect2(Vector2.ZERO, vp).grow(0.5)
		var safe: Rect2 = m.safe_rect.grow(0.5)
		var portrait: bool = m.orientation == TouchMetrics.PORTRAIT
		var hud := Rect2(vp - AMMO_HUD_UNITS, AMMO_HUD_UNITS)
		var holster_scale: float = vp.x / 390.0 if portrait else 1.0
		var holster_size: Vector2 = HOLSTER_UNITS * holster_scale
		var holster := Rect2(Vector2(vp.x * 0.5 - holster_size.x * 0.5, vp.y - holster_size.y), holster_size)
		for profile in PROFILES_UNDER_TEST:
			var key: StringName = TouchMetrics.profile_layout_key(profile, m.device_class, m.orientation, available)
			var label: String = "%s / %s -> %s" % [s["name"], profile, key]
			_check("%s: the profile has its own scene for this screen" % label, MobileLayoutManager.PROFILE_SCENES.has(key))
			if not MobileLayoutManager.PROFILE_SCENES.has(key):
				continue
			var lay := (MobileLayoutManager.PROFILE_SCENES[key] as PackedScene).instantiate() as TouchLayout
			add_child(lay)
			lay.apply(m, 1.0, MobileLayoutManager.DEFAULT_THEME)
			var problems: PackedStringArray = []
			if lay.profile != profile or lay.layout_name != key:
				problems.append("scene says profile=%s layout=%s" % [lay.profile, lay.layout_name])
			var buttons: Array[VirtualButton] = []
			var regions: Array[Control] = []
			for c in lay.controls():
				if c is VirtualButton:
					buttons.append(c)
				elif c is VirtualJoystick or c is VirtualSwipePad or c is VirtualLookPad:
					regions.append(c)
			for b in buttons:
				var rect := Rect2(b.global_position, b.size)
				if not view.encloses(rect):
					problems.append("%s hit area off screen" % b.name)
				if b.size.x / m.dp < 44.0 - 0.01:
					problems.append("%s hit %.1f dp < 44" % [b.name, b.size.x / m.dp])
				var disc := Rect2(_centre(b) - Vector2.ONE * b.radius_dp * b.unit, Vector2.ONE * b.radius_dp * b.unit * 2.0)
				if not safe.encloses(disc):
					problems.append("%s disc leaves the safe rect" % b.name)
				if b.action != &"" and not InputMap.has_action(b.action):
					problems.append("%s action '%s' is not in the InputMap" % [b.name, b.action])
				if profile == &"ep2_runner" or profile == &"ep2_foot":
					if _circle_hits_rect(_centre(b), b.radius_dp * b.unit, hud):
						problems.append("%s covers the ammo HUD box" % b.name)
				if profile == &"ep2_foot" and _circle_hits_rect(_centre(b), b.size.x * 0.5, holster):
					problems.append("%s covers the holster button" % b.name)
			for i in buttons.size():
				for j in range(i + 1, buttons.size()):
					if _centre(buttons[i]).distance_to(_centre(buttons[j])) < buttons[i].size.x * 0.5 + buttons[j].size.x * 0.5:
						problems.append("%s x %s overlap" % [buttons[i].name, buttons[j].name])
			for r in regions:
				var area := Rect2(r.global_position, r.size)
				if not safe.encloses(area):
					problems.append("region %s leaves the safe rect" % r.name)
				if profile == &"ep2_foot" and area.intersects(holster):
					problems.append("region %s covers the holster button" % r.name)
				if r is VirtualSwipePad and area.position.x < VirtualSwipePad.EDGE_INBOARD_DP * m.dp - 0.5:
					problems.append("swipe pad is %.1f dp from the screen edge (< 24)" % (area.position.x / m.dp))
				if r is VirtualJoystick or r is VirtualSwipePad:
					for b in buttons:
						if area.has_point(_centre(b)):
							problems.append("%s sits inside region %s" % [b.name, r.name])
			var words: String = _first_text_node(lay)
			if words != "":
				problems.append("written words: %s" % words)
			problems.append_array(_profile_content_problems(profile, lay, m))
			_check("%s: geometry, keep-outs, no words" % label, problems.is_empty(), "; ".join(problems))
			lay.queue_free()
			await get_tree().process_frame

## The wordless context cue: while a verb is in range the HUD lights the one button bound to
## INTERACT, and nothing else (audit 2026-10-29 P2-2). Also checks the null-safe static.
func _test_context_cue() -> void:
	print(" context cue:")
	var scene: PackedScene = MobileLayoutManager.PROFILE_SCENES.get(&"ep2_foot_phone_landscape")
	_check("the foot layout is registered for the cue test", scene != null)
	if scene == null:
		return
	var lay: TouchLayout = scene.instantiate() as TouchLayout
	add_child(lay)
	lay.apply(MobileLayoutManager.metrics(), 1.0, MobileLayoutManager.DEFAULT_THEME)
	var interact: VirtualButton = lay.find_button(&"interact")
	var fire: VirtualButton = lay.find_button(&"attack")
	_check("the foot layout has an interact button to cue", interact != null)
	lay.set_cue(&"interact", true)
	_check("the cue lights the interact button", interact != null and interact.cue_active)
	_check("...and leaves the fire button alone", fire != null and not fire.cue_active)
	lay.set_cue(&"interact", false)
	_check("the cue clears when the verb goes", interact != null and not interact.cue_active)
	TouchUi.cue(&"interact", true)    # no live manager layout here: must stay a safe no-op
	TouchUi.cue(&"interact", false)
	_check("TouchUi.cue is safe with no live touch layout", true)
	lay.queue_free()
	await get_tree().process_frame

## Circle vs rectangle overlap (canvas units).
func _circle_hits_rect(centre: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(centre.x, rect.position.x, rect.end.x), clampf(centre.y, rect.position.y, rect.end.y))
	return centre.distance_to(nearest) < radius

## What each profile's layout must contain (and must not).
func _profile_content_problems(profile: StringName, lay: TouchLayout, m: TouchMetrics) -> PackedStringArray:
	var out: PackedStringArray = []
	var cs: Array[VirtualControl] = lay.controls()
	match profile:
		&"blaze":
			if cs.is_empty() or not (cs[0] is VirtualTapField):
				out.append("TapField must be the FIRST control (below every button)")
			if lay.find_button(&"pause") == null:
				out.append("no pause button")
			if cs.size() != 2:
				out.append("expected TapField + Pause, got %d controls" % cs.size())
			if lay.find_button(&"blaze_exit") != null:
				out.append("an EXIT button in the layout (the exit lives in the pause overlay)")
		&"ep2_runner":
			var pads: int = 0
			for c in cs:
				if c is VirtualSwipePad:
					pads += 1
				if c is VirtualJoystick or c is VirtualLookPad:
					out.append("%s has no place in the runner" % c.name)
			if pads != 1:
				out.append("expected exactly one SwipePad, got %d" % pads)
			if lay.find_button(&"attack") == null:
				out.append("no attack button (the auto-aim runner_shoot)")
			var pick: VirtualButton = lay.find_button(&"ep2_touch_swipe")
			if pick == null or pick.glyph != VirtualButton.Glyph.PICKAXE or pick.size.x / m.dp < 56.0:
				out.append("pickaxe button missing or < 56 dp")
			if lay.find_button(&"ep2_touch_reload") != null:
				out.append("a reload button in the runner (auto-reload exists)")
			if lay.find_button(&"pause") == null:
				out.append("no pause button")
		&"ep2_foot":
			var stick: VirtualJoystick = lay.find_role(&"stick") as VirtualJoystick
			if stick == null or not stick.analog_vertical:
				out.append("the stick must be analog_vertical")
			var look_index: int = -1
			var stick_index: int = -1
			for i in cs.size():
				if cs[i] is VirtualLookPad:
					look_index = i
				if cs[i] is VirtualJoystick:
					stick_index = i
			if look_index == -1 or look_index > 1 or stick_index == -1:
				out.append("LookPad must come first (under the stick and every button)")
			for action in [&"attack", &"ep2_touch_jump", &"ep2_touch_aim", &"ep2_touch_reload", &"interact", &"sprint", &"pause", &"dash"]:
				if lay.find_button(action) == null:
					out.append("no button on '%s'" % action)
			for action in [&"ep2_touch_jump", &"ep2_touch_aim", &"ep2_touch_reload"]:
				var b: VirtualButton = lay.find_button(action)
				if b != null and not b.touch_only:
					out.append("%s must be touch_only (registered empty in the InputMap)" % action)
		&"ep2_film":
			if cs.size() != 1 or not (cs[0] is VirtualButton):
				out.append("exactly one SKIP button expected")
			else:
				var skip := cs[0] as VirtualButton
				if skip.glyph != VirtualButton.Glyph.SKIP or skip.action != &"jump" or skip.hold_seconds <= 0.0:
					out.append("the film button must be SKIP on jump with a hold ring")
		&"ep2_end":
			var retry: VirtualButton = lay.find_button(&"jump")
			var home: VirtualButton = lay.find_button(&"ui_cancel")
			if retry == null or home == null or cs.size() != 2:
				out.append("retry (jump) and home (ui_cancel) expected")
			elif retry.arm_delay_s < 0.5 or home.arm_delay_s < 0.5:
				out.append("retry/home must be armed after a beat (arm_delay_s >= 0.5)")
		&"ep2_rotate":
			if cs.size() != 1 or not (cs[0] is VirtualRotateCue):
				out.append("the rotate cue alone expected")
	return out

# --- TouchActions ------------------------------------------------------------

func _test_touch_actions() -> void:
	print(" TouchActions:")
	_seen_actions.clear()
	TouchActions.press(&"jump")
	_check("press holds the polled action", Input.is_action_pressed("jump"))
	_check("press is a just_pressed edge", Input.is_action_just_pressed("jump"))
	TouchActions.press(&"jump")
	await get_tree().process_frame
	var downs: int = _seen_actions.count("jump:down")
	_check("an InputEventAction is pushed once on the press edge", downs == 1, "downs=%d seen=%s" % [downs, str(_seen_actions)])
	TouchActions.release(&"jump")
	await get_tree().process_frame
	_check("release clears the polled action", not Input.is_action_pressed("jump"))
	_check("release pushes the up event", _seen_actions.has("jump:up"))
	TouchActions.set_axis(&"move_left", &"move_right", 0.5)
	_check("set_axis +0.5 gives get_axis 0.5", _near(Input.get_axis("move_left", "move_right"), 0.5, 0.001), "axis=%f" % Input.get_axis("move_left", "move_right"))
	TouchActions.set_axis(&"move_left", &"move_right", -0.25)
	_check("set_axis -0.25 swaps sides", _near(Input.get_axis("move_left", "move_right"), -0.25, 0.001))
	TouchActions.set_axis(&"move_left", &"move_right", 0.0)
	_check("set_axis 0 releases both", Input.get_axis("move_left", "move_right") == 0.0 and not TouchActions.is_held(&"move_left"))
	TouchActions.press(&"sprint")
	TouchActions.press(&"dash")
	TouchActions.release_all()
	_check("release_all lets go of everything", TouchActions.held_count() == 0 and not Input.is_action_pressed("sprint"))
	TouchActions.press(&"not_a_real_action")
	_check("unknown actions are ignored", TouchActions.held_count() == 0)

# --- live controls, real fingers --------------------------------------------

func _go_playing() -> void:
	# MENU -> TRANSITIONING -> PLAYING, tolerant of whatever state a prior step left
	if StateMachine.get_state_enum() != StateMachine.State.TRANSITIONING and StateMachine.get_state_enum() != StateMachine.State.PLAYING:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	if StateMachine.get_state_enum() == StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.PLAYING)

func _test_live_controls() -> void:
	print(" live fingers:")
	var marker := Node.new()
	marker.add_to_group(MobileLayoutManager.GROUP_WANTED)
	add_child(marker)
	MobileLayoutManager.force_touch_ui = true
	MobileLayoutManager.is_touch_device = true
	_go_playing()
	MobileLayoutManager.refresh()
	await get_tree().process_frame
	_check("controls appear when PLAYING with a wanting scene", MobileLayoutManager.controls_visible)
	var lay: TouchLayout = MobileLayoutManager.layout()
	_check("a layout is built", lay != null and lay.controls().size() == 7, "controls=%d" % (lay.controls().size() if lay else -1))
	_check("touch layer sits below the modal panels (layer < 20)", MobileLayoutManager.LAYER < 20)
	var stick := lay.find_role(&"stick") as VirtualJoystick
	var jump := lay.find_button(&"jump")
	var atk := lay.find_button(&"attack")
	var dash := lay.find_button(&"dash")
	var run := lay.find_button(&"sprint")
	var radius: float = stick.base_radius_dp * stick.unit
	var origin: Vector2 = stick.global_position + stick.size * Vector2(0.5, 0.45)

	# --- analog movement
	_touch(0, true, origin)
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	_check("full tilt right = axis 1.0", _near(Input.get_axis("move_left", "move_right"), 1.0), "axis=%f" % Input.get_axis("move_left", "move_right"))
	_drag(0, origin + Vector2(radius * 0.29, 0.0))
	await get_tree().process_frame
	var light: float = Input.get_axis("move_left", "move_right")
	_check("light tilt = gentle analog axis", light > 0.3 and light < 0.6, "axis=%f" % light)
	_drag(0, origin + Vector2(-radius * 2.0, 0.0))
	await get_tree().process_frame
	_check("dragging far past the rim clamps to full left", _near(Input.get_axis("move_left", "move_right"), -1.0))
	_drag(0, origin + Vector2(0.0, -radius))
	await get_tree().process_frame
	_check("straight up presses move_up, no horizontal", Input.is_action_pressed("move_up") and Input.get_axis("move_left", "move_right") == 0.0)
	_drag(0, origin + Vector2(0.0, radius))
	await get_tree().process_frame
	_check("straight down presses move_down and releases move_up", Input.is_action_pressed("move_down") and not Input.is_action_pressed("move_up"))
	_drag(0, origin + Vector2(radius * 0.5, -radius * 0.5))
	await get_tree().process_frame
	_check("running with a drifting thumb does not climb", not Input.is_action_pressed("move_up") and Input.get_axis("move_left", "move_right") > 0.5)

	# --- multi-touch combo: stick (finger 0) held while JUMP + ATK + DASH use other fingers
	_drag(0, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	_touch(1, true, _centre(jump))
	await get_tree().process_frame
	_check("combo: JUMP pressed while the stick is held", Input.is_action_pressed("jump") and _near(Input.get_axis("move_left", "move_right"), 1.0))
	_touch(2, true, _centre(atk))
	await get_tree().process_frame
	_check("combo: ATK joins (3 fingers, 3 actions)", Input.is_action_pressed("attack") and Input.is_action_pressed("jump"))
	_touch(1, false, _centre(jump))
	await get_tree().process_frame
	_check("combo: lifting JUMP leaves stick and ATK alone", not Input.is_action_pressed("jump") and Input.is_action_pressed("attack") and _near(Input.get_axis("move_left", "move_right"), 1.0))
	_touch(2, false, _centre(atk))
	await get_tree().process_frame
	_check("combo: lifting ATK releases only ATK", not Input.is_action_pressed("attack") and Input.get_axis("move_left", "move_right") > 0.9)

	# --- a finger that slides off its button still releases it
	_touch(1, true, _centre(dash))
	await get_tree().process_frame
	_check("DASH pressed", Input.is_action_pressed("dash"))
	_drag(1, Vector2(5.0, 5.0))
	await get_tree().process_frame
	_touch(1, false, Vector2(5.0, 5.0))
	await get_tree().process_frame
	_check("slid-off finger still releases DASH (no stuck input)", not Input.is_action_pressed("dash"))

	# --- RUN is a toggle: both thumbs stay free
	_touch(1, true, _centre(run))
	await get_tree().process_frame
	_touch(1, false, _centre(run))
	await get_tree().process_frame
	_check("RUN tap turns sprint ON and it stays on", Input.is_action_pressed("sprint") and run.is_on())
	_touch(1, true, _centre(run))
	await get_tree().process_frame
	_touch(1, false, _centre(run))
	await get_tree().process_frame
	_check("second RUN tap turns it OFF", not Input.is_action_pressed("sprint") and not run.is_on())

	# --- releasing the stick releases everything it held
	_touch(0, false, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	_check("lifting the stick finger zeroes every direction", Input.get_axis("move_left", "move_right") == 0.0 and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"))

	# --- a second finger landing in the stick region is ignored, not double-driven
	_touch(0, true, origin)
	await get_tree().process_frame
	_touch(5, true, origin + Vector2(30, 0))
	await get_tree().process_frame
	_drag(5, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	_check("a second finger in the stick region does not steer it", Input.get_axis("move_left", "move_right") == 0.0)
	_touch(5, false, origin)
	_touch(0, false, origin)
	await get_tree().process_frame

# --- visibility / safety rules ----------------------------------------------

func _test_visibility_rules() -> void:
	print(" visibility + safety:")
	var lay: TouchLayout = MobileLayoutManager.layout()
	var stick := lay.find_role(&"stick") as VirtualJoystick
	var radius: float = stick.base_radius_dp * stick.unit
	var origin: Vector2 = stick.global_position + stick.size * Vector2(0.5, 0.45)

	var jump := lay.find_button(&"jump")
	var run := lay.find_button(&"sprint")

	# PAUSE with a finger down: injection SUSPENDS (controls stay up, dimmed) - nothing may stay held
	_touch(0, true, origin)
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	_check("held right before pause", Input.get_axis("move_left", "move_right") > 0.9)
	StateMachine.change_state(StateMachine.State.PAUSED)
	await get_tree().process_frame
	_check("pause keeps the controls up but SUSPENDED", MobileLayoutManager.controls_visible and MobileLayoutManager.controls_suspended)
	_check("pause releases every held action", Input.get_axis("move_left", "move_right") == 0.0 and TouchActions.held_count() == 0)
	_touch(0, false, origin)   # the thumb lifts during the pause
	await get_tree().process_frame
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_check("resume: live again, no longer suspended", MobileLayoutManager.controls_visible and not MobileLayoutManager.controls_suspended)
	_check("a thumb that lifted during the pause is NOT restored", Input.get_axis("move_left", "move_right") == 0.0)

	# DEATH with the thumb still down: GAME_OVER suspends, the thumb stays tracked, and its
	# output comes back the moment the hero respawns - no lift, no re-push, not even a jitter
	_touch(0, true, origin)
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	StateMachine.change_state(StateMachine.State.GAME_OVER)
	await get_tree().process_frame
	_check("death keeps the controls up (no flicker), suspended and silent", MobileLayoutManager.controls_visible and MobileLayoutManager.controls_suspended and Input.get_axis("move_left", "move_right") == 0.0)
	_drag(0, origin + Vector2(radius, 5.0))
	await get_tree().process_frame
	_check("while suspended, the thumb's drags press nothing", Input.get_axis("move_left", "move_right") == 0.0)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_check("respawn: the held thumb's output returns AT ONCE", MobileLayoutManager.controls_visible and Input.get_axis("move_left", "move_right") > 0.95, "axis=%f" % Input.get_axis("move_left", "move_right"))
	_touch(0, false, origin)
	await get_tree().process_frame
	_check("lifting it releases", Input.get_axis("move_left", "move_right") == 0.0)

	# a thumb that touches down DURING the death animation counts (it used to be ignored)
	StateMachine.change_state(StateMachine.State.GAME_OVER)
	await get_tree().process_frame
	_touch(0, true, origin)
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	_check("a press made during the death animation is tracked, nothing pressed yet", stick.is_active() and Input.get_axis("move_left", "move_right") == 0.0)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_check("...and takes effect at respawn", Input.get_axis("move_left", "move_right") > 0.95)
	_touch(0, false, origin)
	await get_tree().process_frame

	# a JUMP held through a death must NOT fire on respawn (a held key would not either)
	StateMachine.change_state(StateMachine.State.GAME_OVER)
	await get_tree().process_frame
	_touch(1, true, _centre(jump))
	await get_tree().process_frame
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_check("a button held through a death does not fire on respawn", not Input.is_action_pressed("jump"))
	_touch(1, false, _centre(jump))
	await get_tree().process_frame

	# RUN is a toggle: it survives a death (the controls never hid) and still turns off
	_touch(3, true, _centre(run))
	await get_tree().process_frame
	_touch(3, false, _centre(run))
	await get_tree().process_frame
	StateMachine.change_state(StateMachine.State.GAME_OVER)
	await get_tree().process_frame
	_check("death suspends RUN (sprint released while dead)", not Input.is_action_pressed("sprint") and run.is_on())
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_check("RUN comes back on at respawn", Input.is_action_pressed("sprint"))
	_touch(3, true, _centre(run))
	await get_tree().process_frame
	_touch(3, false, _centre(run))
	await get_tree().process_frame
	_check("and a tap still turns it off", not Input.is_action_pressed("sprint") and not run.is_on())

	# a lock (modal panel / cutscene) hides + releases, unlock restores
	MobileLayoutManager.set_locked(&"test_modal", true)
	_check("lock hides the controls", not MobileLayoutManager.controls_visible and MobileLayoutManager.is_locked())
	MobileLayoutManager.set_locked(&"test_modal", false)
	_check("unlock restores them", MobileLayoutManager.controls_visible)

	# not in a menu / transition
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	await get_tree().process_frame
	_check("hidden during a scene transition", not MobileLayoutManager.controls_visible)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame

	# no wanting scene -> no controls (e.g. Episode 2 FPS, menus)
	var marker: Node = get_tree().get_first_node_in_group(MobileLayoutManager.GROUP_WANTED)
	marker.remove_from_group(MobileLayoutManager.GROUP_WANTED)
	MobileLayoutManager.refresh()
	_check("hidden when the scene wants no platformer controls", not MobileLayoutManager.controls_visible)
	marker.add_to_group(MobileLayoutManager.GROUP_WANTED)
	MobileLayoutManager.refresh()
	_check("shown again when it does", MobileLayoutManager.controls_visible)

	# keyboard parity: a real key press on a hybrid device hides the touch UI, a finger brings it back
	MobileLayoutManager.force_touch_ui = false
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	_check("typing on a hybrid device hides the touch controls", not MobileLayoutManager.controls_visible)
	_touch(0, true, Vector2(5, 5))
	_touch(0, false, Vector2(5, 5))
	await get_tree().process_frame
	_check("touching the screen brings them back", MobileLayoutManager.controls_visible)
	MobileLayoutManager.force_touch_ui = true

	# a rebuilt layout (rotation) never leaves a held input behind
	TouchActions.press(&"move_right", 1.0)
	MobileLayoutManager.get_viewport().get_window().size = Vector2i(1170, 2532)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("rotating to portrait swaps to the portrait layout", MobileLayoutManager.current_layout_key() == &"phone_portrait", str(MobileLayoutManager.current_layout_key()))
	_check("a layout swap released the held action", not TouchActions.is_held(&"move_right"))
	MobileLayoutManager.get_viewport().get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("rotating back restores a landscape layout", MobileLayoutManager.current_layout_key() != &"phone_portrait")

# --- regressions found by the adversarial review ---------------------------------

func _test_stick_edges_and_orphans() -> void:
	print(" stick edges, ladder intent, orphan fingers:")
	_go_playing()
	MobileLayoutManager.refresh()
	await get_tree().process_frame
	var lay: TouchLayout = MobileLayoutManager.layout()
	var stick := lay.find_role(&"stick") as VirtualJoystick
	var radius: float = stick.base_radius_dp * stick.unit
	var origin: Vector2 = stick.global_position + stick.size * Vector2(0.5, 0.45)

	# touching down near the region EDGE used to read as a full push (the base was
	# clamped onto the screen and the clamp shift was read as displacement)
	for spot in [Vector2(6.0, stick.size.y * 0.5), Vector2(stick.size.x * 0.5, stick.size.y - 6.0), Vector2(stick.size.x * 0.5, 6.0)]:
		_touch(0, true, stick.global_position + spot)
		await get_tree().process_frame
		var quiet: bool = Input.get_axis("move_left", "move_right") == 0.0 and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down")
		_check("touch-down at region offset %s reads ZERO (no phantom push)" % str(spot), quiet)
		_touch(0, false, stick.global_position + spot)
		await get_tree().process_frame

	# a push a few degrees off vertical is a CLIMB, not a sidestep (ladder drift)
	_touch(0, true, origin)
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius * 0.17, -radius * 0.9))
	await get_tree().process_frame
	_check("near-vertical push climbs and adds NO horizontal drift", Input.is_action_pressed("move_up") and Input.get_axis("move_left", "move_right") == 0.0, "axis=%f" % Input.get_axis("move_left", "move_right"))
	_drag(0, origin + Vector2(radius * 0.7, -radius * 0.7))
	await get_tree().process_frame
	_check("a true diagonal still keeps its horizontal part", Input.get_axis("move_left", "move_right") > 0.5)
	_touch(0, false, origin)
	await get_tree().process_frame

	# a finger that PRESSED WHILE HIDDEN gets drags but never a release: it must NOT be adopted
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	await get_tree().process_frame
	_touch(0, true, origin)
	await get_tree().process_frame
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius + 20.0, 0.0))
	await get_tree().process_frame
	_check("a finger that never pressed the stick is NOT adopted (its release would never arrive)", Input.get_axis("move_left", "move_right") == 0.0 and not stick.is_active())
	_touch(0, false, origin)
	await get_tree().process_frame

	# an owned finger that LIFTS while the controls are hidden must not be adopted later
	_touch(0, true, origin)
	await get_tree().process_frame
	_drag(0, origin + Vector2(radius, 0.0))
	await get_tree().process_frame
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	await get_tree().process_frame
	_check("a real hide (scene transition) remembers the owned finger", stick._orphan == 0)
	_touch(0, false, origin)
	await get_tree().process_frame
	_check("its release (delivered even while hidden) clears the memory", stick._orphan == -1)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_touch(0, true, origin + Vector2(0, 40))   # a different finger lands... after show it works normally
	await get_tree().process_frame
	_drag(0, origin + Vector2(0, 40) + Vector2(radius, 0.0))
	await get_tree().process_frame
	_check("a normal press after all that steers normally", Input.get_axis("move_left", "move_right") > 0.9)
	_touch(0, false, origin)
	await get_tree().process_frame
	_check("and releases cleanly", Input.get_axis("move_left", "move_right") == 0.0 and stick._orphan == -1)

	# a button pressed then hidden within its press-in tween must not stay DRAWN pressed
	var jump := lay.find_button(&"jump")
	_touch(1, true, _centre(jump))
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	await get_tree().create_timer(0.25).timeout
	_check("a press cut short by hiding leaves the button drawn idle", jump._press_amount == 0.0, "press_amount=%f" % jump._press_amount)
	_touch(1, false, _centre(jump))
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame

func _test_film_opt_in() -> void:
	print(" boss-defeat film / victory screens:")
	_go_playing()
	var marker: Node = get_tree().get_first_node_in_group(MobileLayoutManager.GROUP_WANTED)
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	await get_tree().process_frame
	_check("LEVEL_COMPLETE with an opted-in scene (the Stage 3 film) keeps the controls", MobileLayoutManager.controls_visible)
	marker.remove_from_group(MobileLayoutManager.GROUP_WANTED)
	MobileLayoutManager.refresh()
	_check("LEVEL_COMPLETE without opt-in (victory screen) hides them", not MobileLayoutManager.controls_visible)
	marker.add_to_group(MobileLayoutManager.GROUP_WANTED)
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	await get_tree().process_frame
	_check("back to PLAYING shows them again", MobileLayoutManager.controls_visible)

# --- the real player ---------------------------------------------------------

func _test_player_integration() -> void:
	print(" real player:")
	MobileLayoutManager.force_touch_ui = true
	MobileLayoutManager.is_touch_device = true
	_go_playing()
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20000, 200)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.global_position = Vector2(0, 140)   # top face at y = 40
	add_child(floor_body)
	var player: CharacterBody2D = PLAYER.instantiate()
	add_child(player)
	player.global_position = Vector2(0, 0)
	for i in 30:
		await get_tree().physics_frame
	_check("player stands on the floor", player.is_on_floor())

	var lay: TouchLayout = MobileLayoutManager.layout()
	MobileLayoutManager.refresh()
	var stick := lay.find_role(&"stick") as VirtualJoystick
	var jump := lay.find_button(&"jump")
	var dash := lay.find_button(&"dash")
	var radius: float = stick.base_radius_dp * stick.unit
	var origin: Vector2 = stick.global_position + stick.size * Vector2(0.5, 0.45)

	_touch(0, true, origin)
	_drag(0, origin + Vector2(radius * 0.29, 0.0))
	for i in 40:
		await get_tree().physics_frame
	var vx_light: float = player.velocity.x
	_drag(0, origin + Vector2(radius, 0.0))
	for i in 40:
		await get_tree().physics_frame
	var vx_full: float = player.velocity.x
	print("    vx light=%.1f  vx full=%.1f" % [vx_light, vx_full])
	_check("firm tilt reaches full walk speed", vx_full > 150.0, "vx=%f" % vx_full)
	_check("light tilt walks, but slower (30%..70% of full)", vx_light > 0.30 * vx_full and vx_light < 0.70 * vx_full, "light=%f full=%f" % [vx_light, vx_full])

	# jump with a thumb on the button while the stick is held
	var y_before: float = player.global_position.y
	_touch(1, true, _centre(jump))
	var rose: bool = false
	for i in 12:
		await get_tree().physics_frame
		if player.global_position.y < y_before - 6.0:
			rose = true
	_check("JUMP touch makes the real player leave the floor", rose and not player.is_on_floor())

	# air dash with only a LIGHT tilt must still dash at full punch
	_drag(0, origin + Vector2(radius * 0.29, 0.0))
	await get_tree().physics_frame
	_touch(1, true, _centre(dash))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_touch(1, false, _centre(dash))
	var dash_speed: float = InputHandler.AIR_DASH_SPEED
	print("    dash vx=%.1f (AIR_DASH_SPEED=%.1f)" % [player.velocity.x, dash_speed])
	_check("light-tilt air dash is still a full dash (sign only)", absf(player.velocity.x) > 0.85 * dash_speed, "vx=%f" % player.velocity.x)

	_touch(1, false, _centre(jump))
	_touch(0, false, origin)
	await get_tree().process_frame
	player.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame
