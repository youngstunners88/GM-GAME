class_name VirtualLookPad
extends VirtualControl
## First-person look by dragging a thumb (Episode 2 on foot).
##
## A real Control with per-finger ownership, drawn with a faint corner-bracket cue (so it
## is a visible pad, not an invisible zone). It sits FIRST in the layout so every button
## drawn after it wins its own touches. The first finger that presses it owns it; its
## `InputEventScreenDrag.relative` becomes a look delta in `TouchActions.add_look()`, and
## the first-person room drains that once a frame with `TouchActions.take_look()` and
## feeds the very same `look(relative)` verb the mouse uses.
##
## Units: finger travel is measured in dp (a drag of the same physical length turns the
## camera the same amount on a phone and on a tablet). `gain` is the spec's 1.6 canvas
## units of mouse-look per canvas unit of drag at the reference phone density
## (REFERENCE_UNITS_PER_DP); a 4 dp slop swallows a resting thumb's tremor, then the
## accumulated travel is applied so the camera never lags the thumb by the slop.
##
## It never adopts a finger it did not press (orphan rule) and drops its finger on hide /
## rotation / focus loss via release(). `TouchActions.add_look` itself ignores input
## while injection is suspended, so a pause never banks a camera jump.

## Finger travel before it counts as a look, in dp.
const SLOP_DP := 4.0
## One drag event can turn at most this many dp (a lag spike must not whip the camera).
const MAX_STEP_DP := 48.0
## Canvas units per dp on the reference phone (844x390 landscape).
const REFERENCE_UNITS_PER_DP := 1.85
const BRACKET_ARM_DP := 22.0

## Look gain: mouse-look units per canvas unit of drag at the reference density.
@export var gain: float = 1.6
## Active region as fractions (x, y, w, h) of the safe rectangle.
@export var region: Rect2 = Rect2(0.42, 0.0, 0.58, 0.80)

var _finger: int = -1
var _slop_acc: Vector2 = Vector2.ZERO
var _past_slop: bool = false
var _touch_pos: Vector2 = Vector2.ZERO
var _active_amount: float = 0.0 : set = _set_active_amount
var _tween: Tween

func apply_layout(m: TouchMetrics, unit_scale: float) -> void:
	unit = m.dp * unit_scale
	dp = m.dp
	var rect: Rect2 = m.safe_rect
	position = rect.position + rect.size * region.position
	size = rect.size * region.size
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _finger == -1:
				_finger = touch.index
				_slop_acc = Vector2.ZERO
				_past_slop = false
				_touch_pos = touch.position
				_animate_active(1.0)
			accept_event()
		elif touch.index == _finger:
			_finger = -1
			_animate_active(0.0)
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_touch_pos = drag.position
			_apply_drag(drag.relative)
		accept_event()

## Turn one drag step (canvas units) into a look delta.
func _apply_drag(relative: Vector2) -> void:
	var step_dp: Vector2 = relative / maxf(dp, 0.001)
	if not _past_slop:
		_slop_acc += step_dp
		if _slop_acc.length() < SLOP_DP:
			return
		_past_slop = true
		step_dp = _slop_acc
	step_dp = step_dp.limit_length(MAX_STEP_DP)
	TouchActions.add_look(step_dp * (gain * REFERENCE_UNITS_PER_DP))
	queue_redraw()

## Is a finger dragging on this pad right now?
func is_active() -> bool:
	return _finger != -1

func release() -> void:
	_finger = -1
	_slop_acc = Vector2.ZERO
	_past_slop = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_active_amount = 0.0

func _animate_active(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_active_amount = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "_active_amount", target, 0.10)

func _set_active_amount(v: float) -> void:
	_active_amount = v
	queue_redraw()

func _draw() -> void:
	var col: Color = tint()
	var idle: float = hint_alpha() if hint_active else idle_alpha()
	var alpha: float = lerpf(idle * 0.7, pressed_alpha() * 0.7, _active_amount)
	var stroke: float = maxf((touch_theme.ring_width_dp if touch_theme != null else 2.5) * unit, 1.5)
	# four corner brackets of a viewfinder in the free upper-left of the pad (the buttons
	# live at its right and bottom, so the cue never hides behind one)
	var half := Vector2(size.x * 0.20, size.y * 0.27)
	var centre := Vector2(size.x * 0.30, size.y * 0.42)
	var arm: float = BRACKET_ARM_DP * unit
	var line_col := Color(col.r, col.g, col.b, alpha)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner: Vector2 = centre + Vector2(half.x * sx, half.y * sy)
			draw_polyline(PackedVector2Array([corner + Vector2(-arm * sx, 0.0), corner, corner + Vector2(0.0, -arm * sy)]), line_col, stroke, true)
	# a small ring under the dragging thumb
	if _finger != -1:
		draw_arc(_touch_pos, 16.0 * unit, 0.0, TAU, 32, Color(col.r, col.g, col.b, alpha * 1.3), stroke, true)
