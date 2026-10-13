class_name VirtualButton
extends VirtualControl
## A large round thumb button that holds one InputMap action.
##
## HOLD  - the action is held exactly while a finger is on the button. Right for
##         JUMP (variable jump height needs the release), ATK (fire-breath hold)
##         and DASH (just_pressed on touch-down).
## TOGGLE - a tap flips it on or off and it stays on with both thumbs free. Right
##         for RUN: sprinting while still reaching JUMP with the same thumb was
##         the one thing the old held RUN button could not do.
##
## A button with no `action` (the "?" hint button) just emits `activated`.
## Sliding the finger off does NOT release (the Kimi F4 lesson): the press ends
## when the finger lifts, because the GUI keeps delivering that finger's release
## to this control wherever it ends up.

signal activated
signal pressed
signal released
signal toggled(is_on: bool)

enum Mode { HOLD, TOGGLE }
enum Glyph { NONE, JUMP, ATTACK, DASH, RUN, GRAB, HINT }

@export var action: StringName = &""
@export var mode: Mode = Mode.HOLD
@export var glyph: Glyph = Glyph.NONE
## Short ASCII word shown while the first-time hint is up.
@export var label: String = ""

var _finger: int = -1
var _is_on: bool = false
var _press_amount: float = 0.0 : set = _set_press_amount
var _tween: Tween

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _finger == -1:
				_finger = touch.index
				_begin_press()
			accept_event()
		elif touch.index == _finger:
			_finger = -1
			_end_press()
			accept_event()
	elif event is InputEventScreenDrag:
		accept_event()

func _begin_press() -> void:
	_animate_press(1.0, 0.05)
	TouchActions.buzz()
	match mode:
		Mode.HOLD:
			if action != &"":
				TouchActions.press(action)
		Mode.TOGGLE:
			_is_on = not _is_on
			if action != &"":
				if _is_on:
					TouchActions.press(action)
				else:
					TouchActions.release(action)
			toggled.emit(_is_on)
	pressed.emit()
	activated.emit()
	queue_redraw()

func _end_press() -> void:
	_animate_press(0.0, 0.12)
	if mode == Mode.HOLD and action != &"":
		TouchActions.release(action)
	released.emit()
	queue_redraw()

## Is a finger on this button right now?
func is_down() -> bool:
	return _finger != -1

## TOGGLE state (always false for HOLD buttons).
func is_on() -> bool:
	return _is_on

func release() -> void:
	var was_active: bool = _finger != -1 or _is_on
	_finger = -1
	_is_on = false
	if action != &"":
		TouchActions.release(action)
	# kill a press-in tween still running, or it lands AFTER this and leaves the
	# button drawn pressed with nothing held
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_press_amount = 0.0
	if was_active:
		released.emit()

func _animate_press(target: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_press_amount = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "_press_amount", target, seconds)

func _set_press_amount(v: float) -> void:
	_press_amount = v
	queue_redraw()

# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var th: TouchTheme = touch_theme
	var base_alpha: float = hint_alpha() if hint_active else idle_alpha()
	var engaged: float = maxf(_press_amount, 1.0 if _is_on else 0.0)
	var alpha: float = lerpf(base_alpha, pressed_alpha(), engaged)
	var col: Color = tint()
	var c: Vector2 = local_center()
	var r: float = radius_dp * unit * (1.0 + 0.07 * _press_amount)
	var fill: float = th.fill_strength if th != null else 0.4
	var ring_w: float = maxf((th.ring_width_dp if th != null else 2.5) * unit, 1.5)

	# disc + ring
	draw_circle(c, r, Color(col.r, col.g, col.b, alpha * fill))
	draw_arc(c, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, alpha), ring_w, true)
	# a lit TOGGLE gets a second outer ring so "RUN is on" reads at a glance
	if _is_on:
		draw_arc(c, r + ring_w * 1.8, 0.0, TAU, 48, Color(col.r, col.g, col.b, alpha * 0.8), ring_w, true)

	var white := Color(1, 1, 1, clampf(alpha + 0.12, 0.0, 1.0))
	var stroke: float = maxf((th.glyph_width_dp if th != null else 3.6) * unit, 2.0)
	var g: float = r * 0.5   # glyph half-size
	var lift: float = -r * 0.14 if hint_active and label != "" else 0.0
	var gc := c + Vector2(0.0, lift)
	_draw_glyph(gc, g, stroke, white)

	if hint_active and label != "":
		var fpx: float = (th.label_size_dp if th != null else 11.0) * unit
		_draw_label(label, c + Vector2(0.0, r * 0.52), fpx, clampf(alpha + 0.1, 0.0, 1.0))

func _draw_glyph(c: Vector2, g: float, stroke: float, col: Color) -> void:
	match glyph:
		Glyph.JUMP:
			# two stacked chevrons: "lift" (and a nod to the double jump)
			draw_polyline(PackedVector2Array([c + Vector2(-g, g * 0.15), c + Vector2(0, -g * 0.55), c + Vector2(g, g * 0.15)]), col, stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(-g, g * 0.85), c + Vector2(0, g * 0.15), c + Vector2(g, g * 0.85)]), Color(col.r, col.g, col.b, col.a * 0.7), stroke, true)
		Glyph.ATTACK:
			# starburst: a puff going off
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(c + d * g * 0.38, c + d * g * (1.0 if i % 2 == 0 else 0.72), col, stroke, true)
			draw_circle(c, g * 0.2, col)
		Glyph.DASH:
			draw_polyline(PackedVector2Array([c + Vector2(-g, -g * 0.7), c + Vector2(-g * 0.1, 0), c + Vector2(-g, g * 0.7)]), Color(col.r, col.g, col.b, col.a * 0.7), stroke, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, -g * 0.7), c + Vector2(g * 0.9, 0), c + Vector2(0, g * 0.7)]), col, stroke, true)
		Glyph.RUN:
			# lightning bolt
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(g * 0.2, -g), c + Vector2(-g * 0.6, g * 0.15), c + Vector2(-g * 0.05, g * 0.15),
				c + Vector2(-g * 0.25, g), c + Vector2(g * 0.6, -g * 0.2), c + Vector2(g * 0.05, -g * 0.2)]), col)
		Glyph.GRAB:
			# diamond: the DIAMONDS shard doubles as "interact"
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g * 0.95), c + Vector2(g * 0.68, 0), c + Vector2(0, g * 0.95), c + Vector2(-g * 0.68, 0)]),
				Color(col.r, col.g, col.b, col.a * 0.9))
		Glyph.HINT:
			_draw_label("?", c - Vector2(0, g * 0.05), g * 2.1, col.a)
		_:
			pass
