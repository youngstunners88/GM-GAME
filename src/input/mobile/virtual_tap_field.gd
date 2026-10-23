class_name VirtualTapField
extends VirtualControl
## A whole-screen "tap anywhere" field (Blaze Rush: the cube has ONE verb, jump).
##
## It is a real Control with per-finger ownership like the stick and the buttons, NOT an
## invisible gesture zone bolted on beside the touch layer: it sits in the layout scene
## (first child, so every button after it wins its own touches), it releases on hide /
## rotation / focus loss, and it never adopts a finger it did not press itself.
##
## Every NEW finger down is a fresh `action` edge (`TouchActions.tap`): a thumb resting
## anywhere must never swallow the next finger's tap (press() only pushes an event on
## the not-held -> held edge, so a plain hold would). The action stays held while ANY
## finger is down and is released when the last one lifts.
##
## It draws nothing at rest; a tap leaves a 0.18 s ring (the visible acknowledgement).
## Emulated mouse events (device -1, the first finger echoed as a click) are swallowed
## here; a REAL mouse click (a touch laptop with the layer up) counts as one finger so
## it is never swallowed without effect.

const RING_SECONDS := 0.18
const RING_MIN_DP := 14.0
const RING_MAX_DP := 46.0
## Finger key for a real (non-emulated) left mouse button.
const MOUSE_FINGER := -7

## The InputMap action this field presses (Blaze reads `jump`).
@export var action: StringName = &"jump"
## Haptic tick on every tap (Android browsers / native; nothing on iOS Safari).
@export var buzz_ms: int = 8

var _fingers: Dictionary = {}   # finger key -> true
var _rings: Array = []          # [{"pos": Vector2, "age": float}]

func _ready() -> void:
	super()
	set_process(false)

## The whole viewport listens.
func apply_layout(m: TouchMetrics, unit_scale: float) -> void:
	unit = m.dp * unit_scale
	dp = m.dp
	position = Vector2.ZERO
	size = m.viewport_size
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_finger_down(touch.index, touch.position)
		else:
			_finger_up(touch.index)
		accept_event()
	elif event is InputEventScreenDrag:
		accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.device != InputEvent.DEVICE_ID_EMULATION:
			if click.pressed:
				_finger_down(MOUSE_FINGER, click.position)
			else:
				_finger_up(MOUSE_FINGER)
		accept_event()

func _finger_down(key: int, pos: Vector2) -> void:
	if _fingers.has(key):
		return
	_fingers[key] = true
	TouchActions.tap(action)
	TouchActions.buzz(buzz_ms)
	_rings.append({"pos": pos, "age": 0.0})
	set_process(true)
	queue_redraw()

func _finger_up(key: int) -> void:
	if not _fingers.erase(key):
		return   # a finger we never pressed (orphan rule): nothing to release
	if _fingers.is_empty():
		TouchActions.release(action)

## Fingers currently down on this field.
func finger_count() -> int:
	return _fingers.size()

## BUG FIX (blaze_touch, flagged to the foundation owner). A suspension (the Blaze pause card
## is up) makes this field inert, and a finger that lifts WHILE it is inert is delivered to
## the overlay, never to the field - so `_fingers` kept a stale key and swallowed the next
## real tap of that finger index (`_finger_down` returns early on a known key): after
## PLAY the first tap of finger 0 did nothing. Forget every finger when the suspension
## starts. TouchActions.set_suspended() has already released `action`; a finger that was
## down before is never adopted again (the orphan rule).
func on_suspended(on: bool) -> void:
	if on:
		_fingers.clear()
		_rings.clear()
		set_process(false)
		queue_redraw()

func release() -> void:
	_fingers.clear()
	_rings.clear()
	if action != &"":
		TouchActions.release(action)
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	for ring: Dictionary in _rings:
		ring["age"] = float(ring["age"]) + delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["age"]) < RING_SECONDS)
	if _rings.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var col: Color = tint()
	for ring: Dictionary in _rings:
		var t: float = clampf(float(ring["age"]) / RING_SECONDS, 0.0, 1.0)
		var r: float = lerpf(RING_MIN_DP, RING_MAX_DP, t) * dp
		var a: float = 0.4 * (1.0 - t)
		draw_arc(ring["pos"] as Vector2, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, a), maxf(2.5 * dp, 2.0), true)
