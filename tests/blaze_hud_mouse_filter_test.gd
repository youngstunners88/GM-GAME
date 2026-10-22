extends Node
## Blaze Rush HUD must never EAT a tap.
##
## The run is "tap anywhere to jump", and the jump reads the tap in
## `_unhandled_input` — which a Control in the way never lets it reach. The HUD
## spacer was a bare `Control.new()` (default mouse_filter STOP) stretched across
## the top centre of the row: a ~400-470 u (215-250 dp) wide, ~72 u tall dead strip
## on a landscape phone where the thumb silently did NOT jump (engine-measured with a
## replica of the HUD: no ScreenTouch, no emulated mouse ever reached
## `_unhandled_input`). Labels are IGNORE and containers / TextureRects are PASS by
## default, which is why only the one hand-made Control was a trap.
##
## This walks EVERY Control in a live run (the HUD CanvasLayer, the backdrop and
## void layers, the toast and the portrait extras) and requires
##   * mouse_filter IGNORE or PASS, OR
##   * an intentional BUTTON (BaseButton) — the TAP OUT exit.
## It also drives a REAL emulated tap at the HUD spacer's centre through the
## viewport and checks it reaches the run's input handler.
##
## Run: godot --headless res://tests/blaze_hud_mouse_filter_test.tscn
## Verdict: BLAZE_HUD_MOUSE_FILTER: ALL PASS | N FAILURE(S)

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")

var _fail: int = 0
var _checks: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE HUD MOUSE FILTER:")
	get_window().size = Vector2i(1280, 720)
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500.0, 400.0),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame
	_walk(run)
	await _tap_through_spacer(run)
	run.queue_free()
	await get_tree().process_frame
	if _checks < 4:
		_fail += 1
		print("  [FAIL] only %d checks ran - a false green" % _checks)
	print("BLAZE_HUD_MOUSE_FILTER: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _controls_under(n: Node, out: Array[Control]) -> void:
	if n is Control:
		out.append(n)
	for c in n.get_children():
		_controls_under(c, out)

func _filter_name(f: int) -> String:
	match f:
		Control.MOUSE_FILTER_STOP:
			return "STOP"
		Control.MOUSE_FILTER_PASS:
			return "PASS"
		_:
			return "IGNORE"

func _walk(run: Node) -> void:
	var controls: Array[Control] = []
	_controls_under(run, controls)
	_check("the run builds Controls to inspect (HUD row, labels, face, spacer, button, void)", controls.size() >= 8,
		"found %d" % controls.size())
	var offenders: Array[String] = []
	var buttons: int = 0
	for c in controls:
		var f: int = c.mouse_filter
		if c is BaseButton:
			buttons += 1
			continue
		if f == Control.MOUSE_FILTER_STOP:
			offenders.append("%s (%s) filter STOP" % [c.name, c.get_class()])
	_check("no non-button Control in the run STOPs a tap", offenders.is_empty(), "; ".join(offenders))
	_check("the exit is the only intentional button", buttons == 1, "buttons=%d" % buttons)
	var spacer: Control = run.find_child("HudSpacer", true, false) as Control
	_check("the HUD spacer exists and IGNOREs the mouse",
		spacer != null and spacer.mouse_filter == Control.MOUSE_FILTER_IGNORE)

## Real taps through the viewport (the GUI path a finger takes) at the HUD spacer
## and at points over the sky, the floor band, a candle and the void layer. The
## run's physics is frozen so a landed jump cannot consume the buffer before it is
## read.
func _tap_through_spacer(run: Node) -> void:
	var spacer: Control = run.find_child("HudSpacer", true, false) as Control
	if spacer == null or spacer.size.x < 10.0:
		_check("the spacer has room for a tap", false, "size=%s" % (spacer.size if spacer != null else Vector2.ZERO))
		return
	var centre: Vector2 = spacer.global_position + spacer.size * 0.5
	await _tap_at(run, "the centre of the HUD spacer", centre)
	var view: Vector2 = get_viewport().get_visible_rect().size
	for spot in [
		["the sky", Vector2(view.x * 0.5, view.y * 0.30)],
		["the floor band top", Vector2(view.x * 0.5, view.y * 0.72)],
		["the floor band body", Vector2(view.x * 0.25, view.y * 0.95)],
		["the bottom-right corner", Vector2(view.x - 20.0, view.y - 20.0)],
		["beside the first candle", Vector2(view.x * 0.31, view.y * 0.66)],
	]:
		await _tap_at(run, str(spot[0]), spot[1])
	# Portrait phone: 390x844 @2 -> a 1280x2770 canvas.
	get_window().size = Vector2i(780, 1688)
	await get_tree().process_frame
	await get_tree().process_frame
	view = get_viewport().get_visible_rect().size
	await _tap_at(run, "portrait: the sky", Vector2(view.x * 0.5, view.y * 0.20))
	await _tap_at(run, "portrait: the floor band", Vector2(view.x * 0.5, view.y * 0.85))
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

func _tap_at(run: Node, where: String, canvas_pos: Vector2) -> void:
	run.set_physics_process(false)
	run.set("_jump_buffer", 0.0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = get_viewport().get_final_transform() * canvas_pos
	ev.global_position = ev.position
	get_viewport().push_input(ev)
	await get_tree().process_frame
	_check("a tap on %s reaches the run (buffers a jump)" % where,
		float(run.get("_jump_buffer")) > 0.0, "buffer=%f at canvas %s" % [float(run.get("_jump_buffer")), canvas_pos])
	run.set("_jump_buffer", 0.0)
	run.set_physics_process(true)
