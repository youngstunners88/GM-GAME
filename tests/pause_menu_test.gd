extends Node
## Gate for the in-run pause menu (src/ui/pause_menu.gd).
##
## Regression for the long-dead menu: `_unhandled_input` called
## `event.is_action_just_pressed("ui_cancel")` - an `Input` singleton method, not an
## `InputEvent` one - so it threw "Nonexistent function 'is_action_just_pressed' in
## base 'InputEventKey'" on EVERY event that reached it and the StateMachine could
## never enter PAUSED (pause_menu.gd is the only caller of change_state(PAUSED)).
##
## Drives the REAL thing, no mocks: synthetic keys / fingers -> Viewport -> the real
## pause_menu.tscn -> StateMachine -> SceneTree.paused, and the same inside the real
## Stage 1 and the real Smoke Lounge scenes. Also pins what switching a dead menu on
## exposes: the touch pause button, power-up timers (GameManager is PROCESS_MODE_ALWAYS
## and used to drain Blaze while paused), other modals that already hold the pause,
## the Talk panel, and the level pacing clock.
##
## Run: godot --headless res://tests/pause_menu_test.tscn
## Console must show no "SCRIPT ERROR" (CI greps for it).

const PAUSE_MENU := preload("res://src/ui/pause_menu.tscn")
const STAGE_1 := preload("res://src/level/level_01_smoke_realm.tscn")
const LOUNGE := preload("res://src/level/secret_realm.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	# The headless window defaults to 64x64; pin the project's own 1280x720 so touch
	# coordinates and layouts are deterministic.
	get_window().size = Vector2i(1280, 720)
	await _frames(2)
	print("PAUSE MENU:")
	await _test_keyboard_toggle()
	await _test_action_routes()
	await _test_state_guards()
	await _test_other_modal_owns_the_pause()
	await _test_hidden_menu_never_resumes_on_escape()
	await _test_talk_panel_owns_escape()
	await _test_power_up_timers_freeze()
	await _test_pacing_clock_skips_paused_time()
	await _test_focus_and_layer()
	await _test_pause_button_in_layouts()
	await _test_pause_button_clears_the_hud()
	await _test_touch_pause_button()
	await _test_touch_resume_with_a_thumb_still_down()
	await _test_one_tap_is_one_activation()
	await _test_real_stage_1()
	await _test_smoke_lounge()
	print("PAUSE_MENU: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	_reset_to_playing()
	get_tree().quit(_fail)

# --- helpers -----------------------------------------------------------------

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

## Any state -> TRANSITIONING -> PLAYING, tree unpaused (what SceneRouter + LevelBase do).
func _reset_to_playing() -> void:
	get_tree().paused = false
	if StateMachine.get_state_enum() != StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)

func _key(code: Key, pressed: bool = true, echo: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	Input.parse_input_event(ev)

func _action(name: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tap_escape() -> void:
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	await _frames(2)

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

func _make_menu(parent: Node = null) -> CanvasLayer:
	var pm := PAUSE_MENU.instantiate() as CanvasLayer
	(parent if parent != null else self).add_child(pm)
	return pm

func _state() -> String:
	return StateMachine.get_current_state()

# --- keyboard ----------------------------------------------------------------

func _test_keyboard_toggle() -> void:
	print(" keyboard Escape:")
	_reset_to_playing()
	var pm := _make_menu()
	await _frames(2)
	_check("starts hidden, PLAYING, unpaused", not pm.visible and _state() == "PLAYING" and not get_tree().paused)

	_key(KEY_ESCAPE, true)
	await _frames(2)
	_check("Escape pauses: state PAUSED", _state() == "PAUSED", _state())
	_check("Escape pauses: scene tree is paused", get_tree().paused)
	_check("Escape pauses: menu is visible", pm.visible)
	_check("the Resume button has keyboard focus", get_viewport().gui_get_focus_owner() == pm.get_node("VBox/ResumeBtn"))

	_key(KEY_ESCAPE, true, true)   # key-repeat while the key is held
	await _frames(2)
	_check("key-repeat (echo) does not flap the menu", _state() == "PAUSED" and pm.visible)

	_key(KEY_ESCAPE, false)
	await _frames(2)
	_check("key release does not resume", _state() == "PAUSED")

	_key(KEY_ESCAPE, true)
	await _frames(2)
	_check("second Escape resumes: state PLAYING", _state() == "PLAYING", _state())
	_check("second Escape resumes: tree unpaused", not get_tree().paused)
	_check("second Escape resumes: menu hidden", not pm.visible)
	_check("a hidden menu keeps no keyboard focus (Space is ui_accept AND jump)",
			get_viewport().gui_get_focus_owner() == null)
	_key(KEY_ESCAPE, false)
	await _frames(2)

	# the Resume button does the same job
	await _tap_escape()
	_check("pauses again", _state() == "PAUSED")
	pm.get_node("VBox/ResumeBtn").pressed.emit()
	await _frames(2)
	_check("Resume button resumes", _state() == "PLAYING" and not get_tree().paused and not pm.visible)
	pm.queue_free()
	await _frames(2)

# --- actions (touch button, gamepad) -----------------------------------------

func _test_action_routes() -> void:
	print(" ui_cancel / pause actions (touch button, gamepad):")
	_reset_to_playing()
	var pm := _make_menu()
	await _frames(2)
	_check("the `pause` action exists in the InputMap", InputMap.has_action(&"pause"))

	_action(&"ui_cancel", true)
	await _frames(2)
	_check("an InputEventAction ui_cancel pauses", _state() == "PAUSED", _state())
	_action(&"ui_cancel", false)
	await _frames(2)
	_action(&"ui_cancel", true)
	await _frames(2)
	_check("and resumes", _state() == "PLAYING", _state())
	_action(&"ui_cancel", false)
	await _frames(2)

	_action(&"pause", true)
	await _frames(2)
	_check("the `pause` action (touch button / gamepad Start) pauses", _state() == "PAUSED", _state())
	_action(&"pause", false)
	await _frames(2)
	_action(&"pause", true)
	await _frames(2)
	_check("and resumes", _state() == "PLAYING", _state())
	_action(&"pause", false)
	await _frames(2)
	pm.queue_free()
	await _frames(2)

# --- state guards ------------------------------------------------------------

func _test_state_guards() -> void:
	print(" only pauses a game that is being played:")
	var pm := _make_menu()
	for s in [StateMachine.State.TRANSITIONING, StateMachine.State.GAME_OVER, StateMachine.State.LEVEL_COMPLETE]:
		_reset_to_playing()
		StateMachine.change_state(s)
		var name: String = StateMachine.State.keys()[s]
		await _tap_escape()
		_check("Escape during %s does nothing" % name, _state() == name and not pm.visible and not get_tree().paused, _state())
	# MENU is the boot state; nothing may leave it except via TRANSITIONING
	get_tree().paused = false
	pm.queue_free()
	await _frames(2)
	_reset_to_playing()

func _test_other_modal_owns_the_pause() -> void:
	print(" a panel that already holds the pause keeps it:")
	# oracle / lore / onboarding panels set tree.paused = true and leave the StateMachine
	# in PLAYING. Pausing on top would let Resume unpause the game under an open panel.
	_reset_to_playing()
	var pm := _make_menu()
	await _frames(2)
	get_tree().paused = true
	await _tap_escape()
	_check("Escape under another modal does not open the pause menu", _state() == "PLAYING" and not pm.visible, _state())
	_check("and does not touch the modal's pause", get_tree().paused)
	get_tree().paused = false
	pm.queue_free()
	await _frames(2)

func _test_hidden_menu_never_resumes_on_escape() -> void:
	print(" a hidden-but-paused menu ignores Escape:")
	# The Talk panel hides the menu but the state stays PAUSED. Whatever opened it, an
	# Escape the menu receives in that state must not resume the game from under it.
	_reset_to_playing()
	var pm := _make_menu()
	await _frames(2)
	await _tap_escape()
	pm.hide()
	await _tap_escape()
	_check("Escape with the menu hidden leaves the game PAUSED", _state() == "PAUSED" and get_tree().paused, _state())
	pm.show()
	await _tap_escape()
	_check("and resumes as soon as the menu is the thing on screen", _state() == "PLAYING")
	pm.queue_free()
	await _frames(2)

func _test_talk_panel_owns_escape() -> void:
	print(" Talk to Lil Blunt panel:")
	_reset_to_playing()
	var pm := _make_menu()
	await _frames(2)
	await _tap_escape()
	_check("paused", _state() == "PAUSED")
	pm._on_talk_pressed()
	await _frames(2)
	_check("the menu hides while the Talk panel is up", not pm.visible and _state() == "PAUSED" and get_tree().paused)
	# Escape must close the PANEL and come back to the menu, never resume the game under it
	await _tap_escape()
	_check("Escape closes the Talk panel and returns to the pause menu",
			pm.visible and _state() == "PAUSED" and get_tree().paused, "visible=%s state=%s paused=%s" % [pm.visible, _state(), get_tree().paused])
	await _tap_escape()
	_check("the next Escape resumes", _state() == "PLAYING" and not get_tree().paused and not pm.visible)
	pm.queue_free()
	await _frames(2)

# --- what pausing must not cost the player -----------------------------------

func _test_power_up_timers_freeze() -> void:
	print(" power-up timers do not drain while paused:")
	# GameManager is PROCESS_MODE_ALWAYS; its _process kept ticking through the menu.
	_reset_to_playing()
	var pm := _make_menu()
	await _frames(2)
	GameManager.activate_power_up("blaze", 30.0)
	await _frames(2)
	await _tap_escape()
	var before: float = GameManager.power_up_timer
	await get_tree().create_timer(0.5, true, false, true).timeout   # half a second of real time
	var after: float = GameManager.power_up_timer
	_check("Blaze timer holds still while paused", is_equal_approx(before, after), "%.3f -> %.3f" % [before, after])
	await _tap_escape()
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check("and drains again after resume", GameManager.power_up_timer < before - 0.1, "%.3f" % GameManager.power_up_timer)
	GameManager.deactivate_power_up()
	pm.queue_free()
	await _frames(2)

func _test_pacing_clock_skips_paused_time() -> void:
	print(" the level pacing clock skips paused time:")
	# 'level_complete' seconds feed adaptive difficulty; menu time is not play time.
	_reset_to_playing()
	var stub := GDScript.new()   # stands in for LevelBase: only its `level_start_ms` matters here
	stub.source_code = "extends Node\nvar level_start_ms: int = 0\n"
	stub.reload()
	var level := Node.new()
	level.set_script(stub)
	add_child(level)
	var pm := _make_menu(level)
	await _frames(2)
	var start: int = level.level_start_ms
	await _tap_escape()
	await get_tree().create_timer(0.4, true, false, true).timeout
	await _tap_escape()
	var credited: int = level.level_start_ms - start
	_check("0.4 s in the menu moves the level start forward by ~0.4 s", credited >= 350 and credited <= 800, "credited %d ms" % credited)
	level.queue_free()
	await _frames(2)

func _test_focus_and_layer() -> void:
	print(" layering:")
	var pm := _make_menu()
	_check("menu sits above the touch layer (18) and the modal panels (20-30)", pm.layer > MobileLayoutManager.LAYER and pm.layer > 30, "layer=%d" % pm.layer)
	_check("menu stays below the how-to-play card (80)", pm.layer < 80)
	_check("menu keeps running while the tree is paused", pm.process_mode == Node.PROCESS_MODE_ALWAYS)
	pm.queue_free()
	await _frames(2)

# --- touch -------------------------------------------------------------------

func _test_pause_button_in_layouts() -> void:
	print(" touch pause button is in every layout:")
	for key in MobileLayoutManager.LAYOUT_SCENES:
		var lay := (MobileLayoutManager.LAYOUT_SCENES[key] as PackedScene).instantiate() as TouchLayout
		add_child(lay)
		var btn := lay.find_button(&"pause")
		_check("%s has a pause button" % key, btn != null)
		if btn != null:
			_check("%s pause button is a plain HOLD button on the pause action" % key, btn.mode == VirtualButton.Mode.HOLD and btn.glyph == VirtualButton.Glyph.PAUSE)
		lay.queue_free()
	await _frames(1)

## The top-right already holds the lives counter and the fullscreen button. The pause
## button must sit clear of both on every screen the layouts are tested on, measured
## against the REAL HUD nodes (their right-edge distances), not copied constants.
func _test_pause_button_clears_the_hud() -> void:
	print(" pause button does not crowd the HUD (top-right):")
	var hud := preload("res://src/ui/hud.tscn").instantiate()
	add_child(hud)
	await _frames(3)
	var vp0: Vector2 = get_viewport().get_visible_rect().size
	var fs_rect: Rect2 = (hud.get_node("FullscreenButton") as Control).get_global_rect()
	var lives_rect: Rect2 = (hud._lives_label as Control).get_global_rect()
	# both hug the right edge: remember them as distances from it
	var hud_boxes: Array[Rect2] = [
		Rect2(Vector2(vp0.x - fs_rect.end.x, fs_rect.position.y), fs_rect.size),
		Rect2(Vector2(vp0.x - lives_rect.end.x, lives_rect.position.y), lives_rect.size)]
	var screens := [
		{"name": "iPhone 844x390 @3", "win": Vector2(2532, 1170), "dpr": 3.0, "ins": Vector4(132, 0, 132, 102)},
		{"name": "small Android 640x360 @2.6", "win": Vector2(1664, 936), "dpr": 2.6, "ins": Vector4.ZERO},
		{"name": "wide Android 915x412 @2.6", "win": Vector2(2379, 1071), "dpr": 2.6, "ins": Vector4.ZERO},
		{"name": "iPad 1024x768 @2", "win": Vector2(2048, 1536), "dpr": 2.0, "ins": Vector4.ZERO},
		{"name": "iPad Pro 1366x1024 @2", "win": Vector2(2732, 2048), "dpr": 2.0, "ins": Vector4.ZERO},
		{"name": "phone portrait 390x844 @3", "win": Vector2(1170, 2532), "dpr": 3.0, "ins": Vector4.ZERO},
		{"name": "desktop emulation 1280x720 @1", "win": Vector2(1280, 720), "dpr": 1.0, "ins": Vector4.ZERO},
	]
	for sc in screens:
		var win: Vector2 = sc["win"]
		var aspect: float = win.x / win.y
		var vp: Vector2 = Vector2(720.0 * aspect, 720.0) if aspect >= 1280.0 / 720.0 else Vector2(1280.0, 1280.0 / aspect)
		var m := TouchMetrics.compute(vp, win, sc["dpr"], sc["ins"], true)
		var key: StringName = TouchMetrics.layout_key(m.device_class, m.orientation)
		var lay := (MobileLayoutManager.LAYOUT_SCENES[key] as PackedScene).instantiate() as TouchLayout
		add_child(lay)
		lay.apply(m, 1.0, MobileLayoutManager.DEFAULT_THEME)
		var btn := lay.find_button(&"pause")
		var c: Vector2 = btn.global_position + btn.size * 0.5
		var hit_r: float = btn.size.x * 0.5
		var clear := true
		var why := ""
		for box in hud_boxes:
			var r := Rect2(Vector2(vp.x - box.position.x - box.size.x, box.position.y), box.size)
			# distance from the hit circle's centre to the box
			var nearest := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
			if c.distance_to(nearest) < hit_r + 4.0:
				clear = false
				why = "hit circle %s r=%.0f touches HUD box %s" % [str(c), hit_r, str(r)]
		_check("%s: the whole tap target clears the lives counter and fullscreen button" % sc["name"], clear, why)
		lay.queue_free()
	hud.queue_free()
	await _frames(2)

func _arm_touch_controls() -> Node:
	var marker := Node.new()
	marker.add_to_group(MobileLayoutManager.GROUP_WANTED)
	add_child(marker)
	MobileLayoutManager.force_touch_ui = true
	MobileLayoutManager.is_touch_device = true
	MobileLayoutManager._keyboard_mode = false   # the Escape presses above flipped it
	MobileLayoutManager.refresh()
	return marker

func _test_touch_pause_button() -> void:
	print(" touch pause button, real finger:")
	_reset_to_playing()
	var marker := _arm_touch_controls()
	var pm := _make_menu()
	await _frames(3)
	var lay: TouchLayout = MobileLayoutManager.layout()
	var btn: VirtualButton = lay.find_button(&"pause")
	_check("touch controls are up with a pause button", MobileLayoutManager.controls_visible and btn != null)
	var centre: Vector2 = btn.global_position + btn.size * 0.5

	_touch(0, true, centre)
	await _frames(2)
	_check("tapping the pause button pauses the game", _state() == "PAUSED" and get_tree().paused, _state())
	_check("the touch layer goes dim and suspended", MobileLayoutManager.controls_suspended)
	_touch(0, false, centre)
	await _frames(2)
	_check("lifting the finger leaves no `pause` action stuck down", not Input.is_action_pressed(&"pause") and not TouchActions.is_held(&"pause"))
	_check("the game is still paused after the finger lifts", _state() == "PAUSED")

	# Resume with a single finger on the menu's Resume button (emulated mouse from touch)
	var resume: Button = pm.get_node("VBox/ResumeBtn")
	var rc: Vector2 = resume.get_global_rect().get_center()
	_touch(0, true, rc)
	await _frames(1)
	_touch(0, false, rc)
	await _frames(3)
	_check("tapping Resume with a finger resumes", _state() == "PLAYING" and not get_tree().paused and not pm.visible, "state=%s" % _state())
	_check("the touch layer comes back to full strength", not MobileLayoutManager.controls_suspended)

	# The menu must win a tap even where the dimmed joystick region lies underneath it.
	await _tap_pause_via_button(centre)
	var stick_region: Rect2 = Rect2(lay.find_role(&"stick").global_position, lay.find_role(&"stick").size)
	var left_edge: Vector2 = Vector2(resume.get_global_rect().position.x + 8.0, rc.y)
	_check("(setup) the menu's left edge lies inside the joystick region", stick_region.has_point(left_edge), str(stick_region))
	_touch(0, true, left_edge)
	await _frames(1)
	_touch(0, false, left_edge)
	await _frames(3)
	_check("a tap on Resume's far-left edge still resumes (menu is above the stick)", _state() == "PLAYING", _state())

	marker.queue_free()
	pm.queue_free()
	MobileLayoutManager.force_touch_ui = false
	await _frames(2)

func _tap_pause_via_button(centre: Vector2) -> void:
	_touch(0, true, centre)
	await _frames(2)
	_touch(0, false, centre)
	await _frames(2)

func _test_touch_resume_with_a_thumb_still_down() -> void:
	print(" touch: Resume while the other thumb is still on the stick:")
	_reset_to_playing()
	var marker := _arm_touch_controls()
	var pm := _make_menu()
	await _frames(3)
	var lay: TouchLayout = MobileLayoutManager.layout()
	var btn: VirtualButton = lay.find_button(&"pause")
	var centre: Vector2 = btn.global_position + btn.size * 0.5
	var stick_at := Vector2(200.0, 520.0)

	_touch(0, true, stick_at)         # left thumb lands on the stick and keeps running
	await _frames(1)
	_drag(0, stick_at + Vector2(60, 0))
	await _frames(2)
	_check("(setup) the stick is steering right", Input.is_action_pressed(&"move_right"))
	_touch(1, true, centre)           # right thumb taps pause
	await _frames(2)
	_touch(1, false, centre)
	await _frames(2)
	_check("pause works with the other thumb down", _state() == "PAUSED", _state())
	_check("a held stick injects nothing while paused", not Input.is_action_pressed(&"move_right"))

	var resume: Button = pm.get_node("VBox/ResumeBtn")
	var rc: Vector2 = resume.get_global_rect().get_center()
	_touch(1, true, rc)               # right thumb taps Resume; the left thumb is STILL on the stick
	await _frames(1)
	_touch(1, false, rc)
	await _frames(3)
	_check("Resume works while the first thumb is still down", _state() == "PLAYING", _state())
	_touch(0, false, stick_at)
	await _frames(2)
	TouchActions.release_all()
	marker.queue_free()
	pm.queue_free()
	MobileLayoutManager.force_touch_ui = false
	await _frames(2)

## A first-finger tap reaches a button as a raw finger event AND as the mouse click Godot
## emulates from it, in the same frame. Talk must open ONE panel, not two.
func _test_one_tap_is_one_activation() -> void:
	print(" touch: one tap is one activation:")
	_reset_to_playing()
	var pm := _make_menu()
	await _frames(2)
	_action(&"pause", true)
	await _frames(2)
	_action(&"pause", false)
	await _frames(2)
	var talk: Button = pm.get_node("VBox/TalkBtn")
	var tc: Vector2 = talk.get_global_rect().get_center()
	_touch(0, true, tc)
	await _frames(1)
	_touch(0, false, tc)
	await _frames(3)
	var panels: int = 0
	for child in get_children():
		if child.scene_file_path == "res://src/ui/companion_panel.tscn":
			panels += 1
	_check("a single finger tap on Talk opens exactly one Talk panel", panels == 1, "panels=%d" % panels)
	await _tap_escape()    # closes the panel, back to the menu
	await _tap_escape()    # resumes
	_check("(cleanup) back to PLAYING", _state() == "PLAYING", _state())
	pm.queue_free()
	await _frames(2)

# --- the real scenes ---------------------------------------------------------

func _test_real_stage_1() -> void:
	print(" real Stage 1:")
	get_tree().paused = false
	if StateMachine.get_state_enum() != StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	var level := STAGE_1.instantiate()
	add_child(level)
	await _frames(6)
	var bt := level.get_node_or_null("BossTrigger")
	if bt != null:
		bt.set_deferred("monitoring", false)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var pm := level.get_node_or_null("PauseMenu") as CanvasLayer
	_check("Stage 1 is PLAYING with a player and a pause menu", _state() == "PLAYING" and player != null and pm != null, "state=%s" % _state())
	if player == null or pm == null:
		level.queue_free()
		return
	# settle on the ground, then walk right
	await get_tree().create_timer(1.0, true, false, true).timeout
	Input.action_press(&"move_right")
	await get_tree().create_timer(0.5, true, false, true).timeout
	var walking_x: float = player.global_position.x
	await _tap_escape()
	_check("Escape pauses Stage 1", _state() == "PAUSED" and get_tree().paused and pm.visible, _state())
	var frozen_x: float = player.global_position.x
	await get_tree().create_timer(0.6, true, false, true).timeout
	_check("Lil Blunt stays frozen while paused (even with right held)", is_equal_approx(frozen_x, player.global_position.x),
			"%.2f -> %.2f" % [frozen_x, player.global_position.x])
	var health_before: int = GameManager.player_health
	await _tap_escape()
	_check("Escape resumes Stage 1", _state() == "PLAYING" and not get_tree().paused and not pm.visible, _state())
	await get_tree().create_timer(0.5, true, false, true).timeout
	_check("and Lil Blunt walks on", player.global_position.x > frozen_x + 5.0, "%.2f -> %.2f (before pause %.2f)" % [frozen_x, player.global_position.x, walking_x])
	_check("health untouched by pausing", GameManager.player_health == health_before)
	Input.action_release(&"move_right")
	level.queue_free()
	await _frames(3)
	get_tree().paused = false

func _test_smoke_lounge() -> void:
	print(" real Smoke Lounge:")
	get_tree().paused = false
	if StateMachine.get_state_enum() != StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	var lounge := LOUNGE.instantiate()
	add_child(lounge)
	await _frames(6)
	var pm := lounge.get_node_or_null("PauseMenu") as CanvasLayer
	_check("the lounge has a pause menu", pm != null)
	if pm == null:
		lounge.queue_free()
		return
	_check("lounge: Talk is wired (it used to be a dead button)", (pm.get_node("VBox/TalkBtn") as Button).pressed.get_connections().size() > 0)
	_check("lounge: Resume and Quit are wired too",
			(pm.get_node("VBox/ResumeBtn") as Button).pressed.get_connections().size() > 0 and (pm.get_node("VBox/QuitBtn") as Button).pressed.get_connections().size() > 0)
	_check("lounge: Restart is hidden (it would wipe the run inside a side room)", not (pm.get_node("VBox/RestartBtn") as Button).visible)
	await _tap_escape()
	_check("Escape pauses the lounge", _state() == "PAUSED" and pm.visible, _state())
	await _tap_escape()
	_check("Escape resumes the lounge", _state() == "PLAYING" and not pm.visible, _state())
	lounge.queue_free()
	await _frames(3)
	get_tree().paused = false
