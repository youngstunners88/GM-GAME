extends Node2D
## Gate for the vault NPC dialogues on a touch screen (Gideon / Fort Knox first).
##
## Gideon's LAST step moves value: the terminal press stakes 25% of the player's
## GOLD into Fort Knox. His panel sits on canvas layer 30, above the touch layer
## (18) and its GRAB button, so a touch player needs real buttons on the panel -
## and a stray tap must NEVER be able to stake. Everything below is driven through
## the REAL pipeline (synthetic mouse clicks and finger taps -> Godot GUI -> Button
## -> the vault's own functions -> GoldMineSystem), no mocks:
##
##   1. the buttons exist, are >= 96px tall, and never take keyboard focus
##   2. NEXT advances exactly ONE line per tap (mouse and touch), NEXT / CONFIRM
##      STAKE are never visible together, and neither shares a spot
##   3. NO tap path stakes GOLD without the explicit CONFIRM STAKE press: taps on
##      the panel background, on the hidden CONFIRM, on NEXT after the last line,
##      a double tap rolling through NEXT, and CONFIRM inside its arming window
##   4. CONFIRM STAKE does exactly what the keyboard's terminal E does (same
##      balances, same signals) and cannot fire twice
##   5. LEAVE does what Escape does and never stakes
##   6. the keyboard (E / ui_accept / Escape) behaves exactly as before
##   7. no key names or keyboard hint lines on a touch device (founder rule 2026-10-13); the
##      panel buttons keep their words
##   8. while a dialogue panel is up the touch layer is locked (so GRAB, which is
##      the same `interact` action as E, cannot reach the terminal stake), and the
##      lock is always released (close, confirm, leave, scene freed while open)
##
## Run: godot --headless res://tests/vault_touch_dialogue_test.tscn

const FORT_KNOX := preload("res://src/level/fort_knox_realm.tscn")
const DIAMOND_VAULT := preload("res://src/level/diamond_vault_realm.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	# The headless window is 64x64 by default; pin the project's own 1280x720 so the
	# panel (centred) and the stretch transform are deterministic.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	print("VAULT TOUCH DIALOGUE (Gideon):")
	await _test_buttons_exist()
	await _test_next_one_line_per_tap()
	await _test_no_stray_tap_stakes()
	await _test_confirm_matches_keyboard()
	await _test_leave_matches_escape()
	await _test_keyboard_unchanged()
	await _test_touch_layer_lock()
	await _test_prompts_follow_the_device()
	await _test_no_leaked_signal_links()
	print("VAULT_TOUCH_DIALOGUE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	MobileLayoutManager.is_touch_device = false
	MobileLayoutManager.force_touch_ui = false
	get_tree().quit(_fail)

# --- helpers -----------------------------------------------------------------

## Events injected through Input are in WINDOW pixels; the panel lives in canvas
## units. The viewport's final transform is exactly that mapping.
func _to_window(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_pos

func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _frames(n: int = 2) -> void:
	for _i in range(n):
		await get_tree().process_frame

## A desktop click: hover, press, release (a Button fires on release inside).
func _click(canvas_pos: Vector2) -> void:
	var w := _to_window(canvas_pos)
	var m := InputEventMouseMotion.new()
	m.position = w
	m.global_position = w
	Input.parse_input_event(m)
	await _frames(1)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = w
	d.global_position = w
	d.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(d)
	await _frames(1)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = w
	u.global_position = w
	u.button_mask = 0
	Input.parse_input_event(u)
	await _frames(2)

## A finger tap (finger 0 is the one Godot also turns into an emulated mouse
## click, which is what a Button actually answers).
func _tap(canvas_pos: Vector2) -> void:
	var w := _to_window(canvas_pos)
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = w
	Input.parse_input_event(t)
	await _frames(1)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.pressed = false
	u.position = w
	Input.parse_input_event(u)
	await _frames(2)

## Press and release a keyboard-style action for exactly one physics tick each.
func _key(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame
	await get_tree().physics_frame

## MENU -> TRANSITIONING -> PLAYING, tolerant of whatever state a prior step left
## (the touch layer only shows while PLAYING).
func _go_playing() -> void:
	if StateMachine.get_state_enum() != StateMachine.State.TRANSITIONING and StateMachine.get_state_enum() != StateMachine.State.PLAYING:
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	if StateMachine.get_state_enum() == StateMachine.State.TRANSITIONING:
		StateMachine.change_state(StateMachine.State.PLAYING)

func _new_realm(gold: int = 400) -> Node:
	GoldMineSystem.reset_session()
	GoldMineSystem.gold_balance = gold
	var realm: Node = FORT_KNOX.instantiate()
	add_child(realm)
	await _frames(2)
	return realm

func _free_realm(realm: Node) -> void:
	realm.queue_free()
	GoldMineSystem.reset_session()
	await _frames(2)

## What a stake would change: [gold, shares, the realm's one-shot flag].
func _snap(realm: Node) -> Array:
	return [GoldMineSystem.gold_balance, GoldMineSystem.fort_knox_shares, realm.get("_gideon_staked")]

func _idx(realm: Node) -> int:
	return (realm.get("_gideon_dlg") as RefCounted).get("idx")

func _lines(realm: Node) -> int:
	return ((realm.get("_gideon_dlg") as RefCounted).get("lines") as Array).size()

func _at_end(realm: Node) -> bool:
	return (realm.get("_gideon_dlg") as RefCounted).call("at_end")

func _btn(realm: Node, which: String) -> Button:
	return realm.get("_gideon_%s_btn" % which) as Button

func _arm_wait(realm: Node) -> void:
	await get_tree().create_timer(float(realm.get("GIDEON_CONFIRM_ARM_SEC")) + 0.25).timeout

## Open Gideon and walk to the last line with real NEXT presses.
func _open_to_last_line(realm: Node) -> void:
	realm.call("gideon_open")
	await _frames(2)
	var guard := 0
	while not _at_end(realm) and guard < 12:
		await _click(_centre(_btn(realm, "next")))
		guard += 1

# --- 1. the buttons exist ----------------------------------------------------

func _test_buttons_exist() -> void:
	print(" buttons:")
	var realm := await _new_realm()
	realm.call("gideon_open")
	await _frames(2)
	var nxt := _btn(realm, "next")
	var cfm := _btn(realm, "confirm")
	var lv := _btn(realm, "leave")
	_check("NEXT, CONFIRM STAKE and LEAVE are real Buttons on the panel",
		nxt != null and cfm != null and lv != null)
	if nxt == null or cfm == null or lv == null:
		await _free_realm(realm)
		return
	_check("labels are clear: NEXT / CONFIRM STAKE / LEAVE",
		nxt.text == "NEXT" and cfm.text == "CONFIRM STAKE" and lv.text == "LEAVE",
		"'%s' '%s' '%s'" % [nxt.text, cfm.text, lv.text])
	_check("every button is at least 96px tall (like the other vault buttons)",
		nxt.size.y >= 96.0 and cfm.size.y >= 96.0 and lv.size.y >= 96.0,
		"heights %.0f %.0f %.0f" % [nxt.size.y, cfm.size.y, lv.size.y])
	_check("no button takes keyboard focus (a focused Button answers ui_accept AND the vault reads it: double fire)",
		nxt.focus_mode == Control.FOCUS_NONE and cfm.focus_mode == Control.FOCUS_NONE and lv.focus_mode == Control.FOCUS_NONE)
	_check("first line: NEXT is shown, CONFIRM STAKE is not",
		nxt.visible and not cfm.visible)
	var hint: Label = realm.get("_gideon_hint")
	_check("hint names BOTH the key and the button (mid line)",
		hint.text.contains("[E]") and hint.text.contains("NEXT") and hint.text.contains("[ESC]") and hint.text.contains("LEAVE"),
		hint.text)

	# Geometry: inside the viewport, inside the panel, and NEXT / CONFIRM never share a
	# spot (so a double tap on NEXT cannot land on CONFIRM when the last line swaps them).
	var view := get_viewport().get_visible_rect()
	var panel := Rect2(nxt.get_parent().global_position + Vector2(-260, -110), Vector2(780, 300))
	for b: Button in [nxt, cfm, lv]:
		_check("%s sits inside the screen and inside the panel" % b.text,
			view.encloses(b.get_global_rect()) and panel.encloses(b.get_global_rect()),
			"rect %s panel %s" % [b.get_global_rect(), panel])
	_check("NEXT and CONFIRM STAKE do not overlap",
		not nxt.get_global_rect().intersects(cfm.get_global_rect()))
	_check("LEAVE keeps >= 40px from CONFIRM STAKE (mis-tapping the harmless one)",
		cfm.get_global_rect().position.x - lv.get_global_rect().end.x >= 40.0,
		"gap %.0f" % (cfm.get_global_rect().position.x - lv.get_global_rect().end.x))
	await _free_realm(realm)

# --- 2. NEXT is one line per tap ---------------------------------------------

func _test_next_one_line_per_tap() -> void:
	print(" NEXT:")
	var realm := await _new_realm()
	realm.call("gideon_open")
	await _frames(2)
	var total := _lines(realm)
	var base := _snap(realm)
	_check("opens on line 1", _idx(realm) == 0, "idx=%d" % _idx(realm))

	# A real mouse click: exactly one line.
	var before := _idx(realm)
	await _click(_centre(_btn(realm, "next")))
	_check("one mouse click on NEXT advances exactly one line", _idx(realm) == before + 1,
		"%d -> %d" % [before, _idx(realm)])
	var label: Label = realm.get("_gideon_line")
	var dlg: RefCounted = realm.get("_gideon_dlg")
	_check("the line shown is the line the dialogue is on",
		label.text == "GIDEON: " + str((dlg.get("lines") as Array)[_idx(realm)]), label.text)

	# A real finger tap (touch + its emulated mouse click): still exactly one line.
	before = _idx(realm)
	await _tap(_centre(_btn(realm, "next")))
	_check("one finger tap on NEXT advances exactly one line (no double fire)", _idx(realm) == before + 1,
		"%d -> %d" % [before, _idx(realm)])

	# Walk the rest with taps; at every step nothing is staked.
	var guard := 0
	while not _at_end(realm) and guard < 12:
		await _tap(_centre(_btn(realm, "next")))
		guard += 1
	_check("NEXT reaches the last line in exactly lines-1 steps", _idx(realm) == total - 1 and guard <= 2,
		"idx=%d of %d, extra taps %d" % [_idx(realm), total, guard])
	_check("walking the dialogue with NEXT never stakes", _snap(realm) == base, str(_snap(realm)))
	var nxt := _btn(realm, "next")
	var cfm := _btn(realm, "confirm")
	_check("last line: NEXT is hidden, CONFIRM STAKE is shown", not nxt.visible and cfm.visible)
	_check("last line: CONFIRM STAKE starts disabled (arming)", cfm.disabled)
	var hint: Label = realm.get("_gideon_hint")
	_check("last-line hint names BOTH key and button",
		hint.text.contains("[E]") and hint.text.contains("CONFIRM STAKE") and hint.text.contains("[ESC]"), hint.text)
	await _free_realm(realm)

# --- 3. no stray tap stakes --------------------------------------------------

func _test_no_stray_tap_stakes() -> void:
	print(" stray taps cannot stake:")
	var realm := await _new_realm()
	realm.call("gideon_open")
	await _frames(2)
	var base := _snap(realm)
	var nxt := _btn(realm, "next")
	var cfm := _btn(realm, "confirm")
	var panel := Rect2(nxt.get_parent().global_position + Vector2(-260, -110), Vector2(780, 300))

	# Panel background taps (corners, text area, the gaps between buttons) on a mid line:
	# nothing advances (explicit buttons only) and nothing stakes.
	var spots: Array[Vector2] = [
		panel.position + Vector2(14, 20), panel.position + Vector2(380, 40),
		panel.position + Vector2(700, 20), panel.position + Vector2(240, 200),
		panel.position + Vector2(764, 284), panel.position + Vector2(16, 284),
		Vector2(cfm.get_global_rect().end.x + 8.0, cfm.get_global_rect().get_center().y),
	]
	var idx0 := _idx(realm)
	for sp in spots:
		await _tap(sp)
		await _click(sp)
	_check("taps on the panel background do not advance a mid line", _idx(realm) == idx0,
		"idx %d -> %d" % [idx0, _idx(realm)])
	_check("taps on the panel background do not stake", _snap(realm) == base)
	# The hidden CONFIRM STAKE is not tappable on a mid line.
	await _tap(_centre(cfm))
	await _click(_centre(cfm))
	_check("tapping where CONFIRM STAKE will appear (it is hidden) does nothing",
		_idx(realm) == idx0 and _snap(realm) == base and bool(realm.get("_gideon_open")))

	# CONFIRM STAKE has no business on a mid line: even called directly it must neither
	# stake nor skip a line (it is the terminal step, nothing else).
	for _i in range(3):
		realm.call("gideon_press_confirm")
	_check("CONFIRM pressed on a mid line neither skips a line nor stakes",
		_idx(realm) == idx0 and _snap(realm) == base, "idx %d -> %d %s" % [idx0, _idx(realm), _snap(realm)])

	# Penultimate line, then a DOUBLE TAP on NEXT with no pause: the 1st tap shows the last
	# line, the 2nd lands on the same screen spot - which is empty now (NEXT hid, CONFIRM
	# is elsewhere) - so it must not roll through to the stake.
	var guard := 0
	while _idx(realm) < _lines(realm) - 2 and guard < 12:
		await _click(_centre(nxt))
		guard += 1
	_check("positioned on the line before the last", _idx(realm) == _lines(realm) - 2)
	var spot := _centre(nxt)
	await _tap(spot)
	await _tap(spot)
	_check("double tap on NEXT lands on the last line", _at_end(realm) and bool(realm.get("_gideon_open")))
	_check("double tap on NEXT does NOT stake", _snap(realm) == base, str(_snap(realm)))

	# Last line: every non-CONFIRM route stays inert.
	for sp in spots:
		await _tap(sp)
	for _i in range(6):
		realm.call("gideon_press_next")
	_check("NEXT can never confirm: extra NEXT presses on the last line do nothing",
		_snap(realm) == base and bool(realm.get("_gideon_open")) and _at_end(realm), str(_snap(realm)))

	# CONFIRM STAKE inside its arming window: a finger and a direct call both do nothing.
	_check("CONFIRM STAKE is not armed straight after the last line appears",
		Time.get_ticks_msec() < int(realm.get("_gideon_confirm_armed_msec")) and cfm.disabled)
	await _tap(_centre(cfm))
	realm.call("gideon_press_confirm")
	_check("CONFIRM STAKE pressed inside the arming window does nothing",
		_snap(realm) == base and bool(realm.get("_gideon_open")), str(_snap(realm)))
	await _free_realm(realm)

# --- 4. CONFIRM == the keyboard's terminal E ---------------------------------

func _test_confirm_matches_keyboard() -> void:
	print(" CONFIRM STAKE:")
	# Reference run: the keyboard way (gideon_step to the end), counting gold_changed.
	var kb_changed: Array = [0]
	var kb_cb := func(_g: int) -> void: kb_changed[0] += 1
	var realm_kb := await _new_realm()
	var kb_score_before: int = GameManager.total_score
	GoldMineSystem.gold_changed.connect(kb_cb)
	realm_kb.call("gideon_open")
	await _frames(2)
	for _i in range(10):
		realm_kb.call("gideon_step")
	GoldMineSystem.gold_changed.disconnect(kb_cb)
	var kb_gold: int = GoldMineSystem.gold_balance
	var kb_shares: int = GoldMineSystem.fort_knox_shares
	var kb_score: int = GameManager.total_score - kb_score_before
	var kb_closed: bool = not bool(realm_kb.get("_gideon_open"))
	await _free_realm(realm_kb)
	_check("reference (keyboard) run staked 25%% of 400 GOLD and closed", kb_gold == 300 and kb_shares > 0 and kb_closed,
		"gold=%d shares=%d closed=%s" % [kb_gold, kb_shares, kb_closed])

	# The on-screen way: NEXT to the end, wait for the arm window, one finger tap.
	var tap_changed: Array = [0]
	var tap_cb := func(_g: int) -> void: tap_changed[0] += 1
	var realm := await _new_realm()
	var score_before: int = GameManager.total_score
	await _open_to_last_line(realm)
	_check("reached the last line with NEXT only", _at_end(realm))
	await _arm_wait(realm)
	var cfm := _btn(realm, "confirm")
	_check("CONFIRM STAKE is enabled once armed", not cfm.disabled)
	GoldMineSystem.gold_changed.connect(tap_cb)
	await _tap(_centre(cfm))
	GoldMineSystem.gold_changed.disconnect(tap_cb)
	_check("ONE tap on CONFIRM STAKE stakes exactly what the keyboard does (gold and shares identical)",
		GoldMineSystem.gold_balance == kb_gold and GoldMineSystem.fort_knox_shares == kb_shares,
		"gold %d vs %d, shares %d vs %d" % [GoldMineSystem.gold_balance, kb_gold, GoldMineSystem.fort_knox_shares, kb_shares])
	_check("... through the same GoldMineSystem call (same number of gold_changed signals)",
		int(tap_changed[0]) == int(kb_changed[0]) and int(tap_changed[0]) >= 1,
		"tap %d vs keyboard %d" % [tap_changed[0], kb_changed[0]])
	_check("... and the same score award", GameManager.total_score - score_before == kb_score and kb_score > 0,
		"tap +%d vs keyboard +%d" % [GameManager.total_score - score_before, kb_score])
	_check("the panel closed after CONFIRM", not bool(realm.get("_gideon_open")) and realm.get("_gideon_panel") == null)
	# Cannot fire twice: more taps where the button was, and direct presses, change nothing.
	var after := _snap(realm)
	await _tap(_centre(cfm) if is_instance_valid(cfm) else Vector2(640, 400))
	realm.call("gideon_press_confirm")
	realm.call("gideon_press_next")
	_check("a second tap / press after CONFIRM cannot stake again", _snap(realm) == after, str(_snap(realm)))
	await _free_realm(realm)

	# Re-visit after staking: no live-looking button that cannot act.
	var again := await _new_realm()
	again.set("_gideon_staked", true)
	await _open_to_last_line(again)
	var b := _btn(again, "confirm")
	_check("after a stake the button says so and is disabled (no dead control)",
		b.text == "ALREADY STAKED" and b.disabled, "'%s' disabled=%s" % [b.text, b.disabled])
	await _free_realm(again)

# --- 5. LEAVE == Escape ------------------------------------------------------

func _test_leave_matches_escape() -> void:
	print(" LEAVE:")
	var realm := await _new_realm()
	var base := _snap(realm)
	realm.call("gideon_open")
	await _frames(2)
	await _click(_centre(_btn(realm, "leave")))
	_check("LEAVE on a mid line closes the panel without staking",
		not bool(realm.get("_gideon_open")) and realm.get("_gideon_panel") == null and _snap(realm) == base)
	# And from the last line (where CONFIRM is the neighbour).
	await _open_to_last_line(realm)
	await _arm_wait(realm)
	await _tap(_centre(_btn(realm, "leave")))
	_check("LEAVE on the last line closes without staking (even once CONFIRM is armed)",
		not bool(realm.get("_gideon_open")) and _snap(realm) == base, str(_snap(realm)))
	await _free_realm(realm)

# --- 6. keyboard unchanged ---------------------------------------------------

func _test_keyboard_unchanged() -> void:
	print(" keyboard (E / ui_accept / Escape):")
	var realm := await _new_realm()
	realm.set("_at_gideon", true)
	await _key(&"interact")
	_check("E near Gideon opens the dialogue on line 1", bool(realm.get("_gideon_open")) and _idx(realm) == 0,
		"open=%s idx=%d" % [realm.get("_gideon_open"), _idx(realm)])
	await _key(&"interact")
	_check("E advances one line", _idx(realm) == 1, "idx=%d" % _idx(realm))
	await _key(&"ui_accept")
	_check("ui_accept advances one line", _idx(realm) == 2, "idx=%d" % _idx(realm))
	await _key(&"interact")
	_check("E reaches the last line", _at_end(realm) and bool(realm.get("_gideon_open")))
	_check("... and nothing is staked yet", GoldMineSystem.gold_balance == 400)
	var hint: Label = realm.get("_gideon_hint")
	_check("last-line hint is the new two-way copy", hint.text == "[E] / CONFIRM STAKE   [ESC] / LEAVE", hint.text)
	await _key(&"interact")
	_check("the TERMINAL E still confirms the stake (25%% of 400) and closes",
		GoldMineSystem.gold_balance == 300 and GoldMineSystem.fort_knox_shares > 0 and not bool(realm.get("_gideon_open")),
		"gold=%d shares=%d" % [GoldMineSystem.gold_balance, GoldMineSystem.fort_knox_shares])
	await _free_realm(realm)

	var esc := await _new_realm()
	esc.set("_at_gideon", true)
	await _key(&"interact")
	await _key(&"interact")
	await _key(&"ui_cancel")
	_check("Escape leaves without staking", not bool(esc.get("_gideon_open")) and GoldMineSystem.gold_balance == 400,
		"open=%s gold=%d" % [esc.get("_gideon_open"), GoldMineSystem.gold_balance])
	await _free_realm(esc)

# --- 7. the touch layer is locked under a dialogue panel ---------------------

func _test_touch_layer_lock() -> void:
	print(" touch layer lock (GRAB == interact == E):")
	MobileLayoutManager.force_touch_ui = true
	MobileLayoutManager.is_touch_device = true
	_go_playing()
	var realm := await _new_realm()
	_go_playing()
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("in the vault the touch controls are shown (a platformer Player is present)",
		MobileLayoutManager.controls_visible)
	var grab := MobileLayoutManager.layout().find_button(&"interact")
	_check("the layout has the GRAB (interact) button", grab != null)

	# Open Gideon with a real finger on GRAB, exactly as a touch player does.
	realm.set("_at_gideon", true)
	if grab != null:
		var c := _centre(grab)
		var t := InputEventScreenTouch.new()
		t.index = 1
		t.pressed = true
		t.position = _to_window(c)
		Input.parse_input_event(t)
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check("a GRAB tap opens Gideon on line 1",
			bool(realm.get("_gideon_open")) and _idx(realm) == 0, "open=%s idx=%d" % [realm.get("_gideon_open"), _idx(realm)])
		# The thumb is STILL down on GRAB. With the layer locked it is released, so holding
		# it cannot advance the dialogue - and in particular cannot reach the terminal stake.
		for _i in range(30):
			await get_tree().physics_frame
		_check("the held GRAB does not advance the dialogue", _idx(realm) == 0, "idx=%d" % _idx(realm))
		var up := InputEventScreenTouch.new()
		up.index = 1
		up.pressed = false
		up.position = t.position
		Input.parse_input_event(up)
		await _frames(2)
	_check("while Gideon is up the touch layer is locked and hidden",
		MobileLayoutManager.is_locked() and not MobileLayoutManager.controls_visible)
	_check("... so `interact` is not held by a finger", not Input.is_action_pressed("interact"))
	await _arm_wait(realm)
	# Leave by the on-screen button: the lock is released and the controls come back.
	await _click(_centre(_btn(realm, "leave")))
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("LEAVE releases the lock and the controls return",
		not MobileLayoutManager.is_locked() and MobileLayoutManager.controls_visible)

	# CONFIRM releases it too.
	await _open_to_last_line(realm)
	_check("reopened: locked again", MobileLayoutManager.is_locked())
	await _arm_wait(realm)
	await _tap(_centre(_btn(realm, "confirm")))
	MobileLayoutManager.refresh()
	await _frames(2)
	_check("CONFIRM STAKE releases the lock", not MobileLayoutManager.is_locked())

	# A scene freed while the panel is still up must not leave the layer locked for the next scene.
	var realm2 := await _new_realm()
	realm2.call("gideon_open")
	await _frames(2)
	_check("(second realm) open: locked", MobileLayoutManager.is_locked())
	await _free_realm(realm2)
	_check("freeing the realm with the panel open releases the lock", not MobileLayoutManager.is_locked())
	await _free_realm(realm)

	# The Diamond Vault clerk shares the hazard (E / GRAB reaches her confirm): same lock.
	GoldMineSystem.reset_session()
	GoldMineSystem.diamonds_balance = 100
	var dv: Node = DIAMOND_VAULT.instantiate()
	add_child(dv)
	await _frames(2)
	dv.call("clerk_open")
	await _frames(2)
	_check("clerk panel open: touch layer locked", MobileLayoutManager.is_locked())
	dv.call("clerk_close")
	_check("clerk panel closed: lock released", not MobileLayoutManager.is_locked())
	dv.call("clerk_open")
	dv.call("clerk_confirm")
	_check("clerk CONFIRM: lock released", not MobileLayoutManager.is_locked())
	dv.queue_free()
	GoldMineSystem.reset_session()
	await _frames(2)
	MobileLayoutManager.force_touch_ui = false
	MobileLayoutManager.is_touch_device = false

# --- prompts: founder rule, no key names on a touch device --------------------

func _test_prompts_follow_the_device() -> void:
	print(" prompts (no key names / keyboard hint lines on a touch device):")
	MobileLayoutManager.is_touch_device = false
	var kb := await _new_realm()
	kb.call("gideon_open")
	await _frames(2)
	_check("keyboard machine: plate and readout name the key",
		_talk_plate(kb).contains("[E] TALK") and _readout(kb).contains("Walk to an altar, press E to STAKE 25%"),
		"%s | %s" % [_talk_plate(kb), _readout(kb)])
	_check("keyboard machine: Gideon's hint line is shown", (kb.get("_gideon_hint") as Label).visible)
	await _free_realm(kb)

	MobileLayoutManager.is_touch_device = true
	var touch := await _new_realm()
	touch.call("gideon_open")
	await _frames(2)
	_check("touch device: plate says TALK with no key name or button name",
		_talk_plate(touch).ends_with("\nTALK") and not _talk_plate(touch).contains("[") and not _talk_plate(touch).contains("GRAB"),
		_talk_plate(touch))
	_check("touch device: readout has no 'press' / key name",
		not _readout(touch).contains("press") and _readout(touch).contains("Walk to an altar to STAKE 25%"), _readout(touch))
	_check("touch device: Gideon's key-hint line is hidden on a mid line", not (touch.get("_gideon_hint") as Label).visible)
	for _i in range(6):
		touch.call("gideon_press_next")
	_check("touch device: ... and on the last line (the buttons carry the words)",
		_at_end(touch) and not (touch.get("_gideon_hint") as Label).visible
		and _btn(touch, "confirm").text == "CONFIRM STAKE")
	await _free_realm(touch)

	# The Diamond Vault clerk's existing "[E] / tap: next" hint follows the same rule.
	GoldMineSystem.reset_session()
	var dv: Node = DIAMOND_VAULT.instantiate()
	add_child(dv)
	await _frames(2)
	dv.call("clerk_open")
	await _frames(2)
	var found: Array = []
	_find_labels(dv.get("_clerk_panel"), "[E] / tap: next", found)
	_check("touch device: the clerk's '[E] / tap: next' hint is hidden",
		found.size() == 1 and not (found[0] as Label).visible, "found %d" % found.size())
	dv.call("clerk_close")
	dv.queue_free()
	MobileLayoutManager.is_touch_device = false
	await _frames(2)
	var dv2: Node = DIAMOND_VAULT.instantiate()
	add_child(dv2)
	await _frames(2)
	dv2.call("clerk_open")
	await _frames(2)
	found.clear()
	_find_labels(dv2.get("_clerk_panel"), "[E] / tap: next", found)
	_check("keyboard machine: the clerk's hint is shown", found.size() == 1 and (found[0] as Label).visible)
	dv2.call("clerk_close")
	dv2.queue_free()
	GoldMineSystem.reset_session()
	await _frames(2)

func _find_labels(n: Node, text: String, acc: Array) -> void:
	if n == null:
		return
	if n is Label and (n as Label).text == text:
		acc.append(n)
	for c in n.get_children():
		_find_labels(c, text, acc)

func _talk_plate(realm: Node) -> String:
	var g := realm.get_node_or_null("GideonVale")
	if g == null:
		return ""
	for c in g.get_children():
		if c is Label:
			return (c as Label).text
	return ""

func _readout(realm: Node) -> String:
	var r: Label = realm.get("_readout")
	return r.text if r != null else ""

# --- the realm leaves no listeners on the autoload behind it -------------------

## GoldMineSystem outlives the vault. The realm used to connect lambdas to its signals
## and never drop them, so every visit left dead listeners ("Lambda capture ... was
## freed" on every later gold change). Freed realms must leave the counts unchanged.
func _test_no_leaked_signal_links() -> void:
	print(" autoload signal links:")
	GoldMineSystem.reset_session()
	await _frames(1)
	var gold0: int = GoldMineSystem.gold_changed.get_connections().size()
	var dia0: int = GoldMineSystem.diamonds_changed.get_connections().size()
	var shares0: int = GoldMineSystem.diamond_shares_changed.get_connections().size()
	var fk: Node = FORT_KNOX.instantiate()
	add_child(fk)
	var dv: Node = DIAMOND_VAULT.instantiate()
	add_child(dv)
	await _frames(2)
	_check("a live realm does listen (the HUD / scale need it)",
		GoldMineSystem.gold_changed.get_connections().size() > gold0
		and GoldMineSystem.diamonds_changed.get_connections().size() > dia0)
	fk.queue_free()
	dv.queue_free()
	await _frames(3)
	_check("freed realms leave gold_changed exactly as they found it",
		GoldMineSystem.gold_changed.get_connections().size() == gold0,
		"%d -> %d" % [gold0, GoldMineSystem.gold_changed.get_connections().size()])
	_check("... and diamonds_changed / diamond_shares_changed",
		GoldMineSystem.diamonds_changed.get_connections().size() == dia0
		and GoldMineSystem.diamond_shares_changed.get_connections().size() == shares0)
	GoldMineSystem.reset_session()
