class_name VirtualJoystick
extends VirtualControl
## Analog thumb stick for the left hand.
##
## Output goes ONLY to InputMap actions through TouchActions:
##   * `move_left` / `move_right` are pressed with an ANALOG strength, so
##     `Input.get_axis("move_left", "move_right")` - which player.gd already uses
##     as `direction * walk_speed` - gives a gentle walk at a light tilt and full
##     speed at a firm one. Precise platforming without touching player.gd.
##   * `move_up` / `move_down` are DIGITAL (ladders, drop-through, ground pound):
##     they only engage on a deliberate, mostly-vertical push, with hysteresis, so
##     a thumb drifting upward while running never grabs a ladder.
##
## Modes
##   FIXED      the base stays at its rest spot; only touches near it count.
##   DYNAMIC    the base appears under the first touch anywhere in the region and
##              the stick measures from there (default: no hunting for the stick).
##   FOLLOWING  like DYNAMIC, and when the finger is dragged past the rim the base
##              chases it, so the neutral point never drifts away from the thumb.
##
## The region is a fraction of the safe area so it adapts to any aspect ratio.

signal value_changed(value: Vector2)

enum Mode { FIXED, DYNAMIC, FOLLOWING }

## Share of the base radius that is dead (no output).
const AXIS_DEAD := 0.14
## Tilt at which horizontal output reaches full strength (before the physical rim).
const AXIS_SAT := 0.86
## First step past the dead zone is a gentle walk, not a crawl.
const AXIS_FLOOR := 0.30
## Vertical engages above V_ON, disengages below V_OFF (hysteresis).
const V_ON := 0.58
const V_OFF := 0.42
## |y| * V_CONE must exceed |x|: the push has to be within ~53 degrees of vertical.
const V_CONE := 1.35

@export var mode: Mode = Mode.DYNAMIC
## Active region as fractions (x, y, w, h) of the safe rectangle.
@export var region: Rect2 = Rect2(0.0, 0.24, 0.47, 0.76)
## Base centre when idle, in dp inward from the bottom-left corner.
@export var rest_offset_dp: Vector2 = Vector2(112, 98)
@export var base_radius_dp: float = 58.0
@export var knob_radius_dp: float = 27.0

var _finger: int = -1
var _orphan: int = -1                   # finger this stick owned when it was hidden/released from outside
var _orphan_origin: Vector2 = Vector2.ZERO  # that finger's base centre, restored on resume
var _rest: Vector2 = Vector2.ZERO       # local coords
## LOGICAL base centre (local coords): exactly where the thumb landed (or the rest
## spot in FIXED mode). Output is measured from here, so touching down anywhere
## reads zero. Only the DRAWN base is clamped onto the screen (_draw_origin()).
var _origin: Vector2 = Vector2.ZERO
var _shown: Vector2 = Vector2.ZERO      # knob displacement from the base, clamped to the rim
var _v_state: int = 0                   # -1 up, 0 none, +1 down
var _value: Vector2 = Vector2.ZERO
var _active_amount: float = 0.0 : set = _set_active_amount
var _tween: Tween

# --- pure shaping (static so the test scene can call it) ---------------------

## Analog horizontal strength (signed) for a tilt `n` in -1..1.
static func shape_horizontal(n: float) -> float:
	var a: float = absf(n)
	if a <= AXIS_DEAD:
		return 0.0
	var m: float = clampf((a - AXIS_DEAD) / (AXIS_SAT - AXIS_DEAD), 0.0, 1.0)
	return signf(n) * lerpf(AXIS_FLOOR, 1.0, m)

## -1 up, +1 down, 0 neither, for a normalised tilt and the previous state.
static func vertical_state(n: Vector2, previous: int) -> int:
	var threshold: float = V_OFF if previous != 0 and int(signf(n.y)) == previous else V_ON
	if absf(n.y) >= threshold and absf(n.y) * V_CONE >= absf(n.x):
		return int(signf(n.y))
	return 0

# --- layout ------------------------------------------------------------------

func apply_layout(m: TouchMetrics, unit_scale: float) -> void:
	unit = m.dp * unit_scale
	var rect: Rect2 = m.safe_rect
	position = rect.position + rect.size * region.position
	size = rect.size * region.size
	# rest spot: dp inward from the safe rect's bottom-left, in local coords
	var global_rest := Vector2(rect.position.x + rest_offset_dp.x * unit, rect.end.y - rest_offset_dp.y * unit)
	_rest = _clamp_base(global_rest - position)
	if _finger == -1:
		_origin = _rest
		_shown = Vector2.ZERO
	queue_redraw()

## The stick listens over its whole rectangular region (the base is not round).
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

## Keep the whole base disc inside the region (and so on screen).
func _clamp_base(p: Vector2) -> Vector2:
	var r: float = base_radius_dp * unit
	var lo := Vector2(r, r)
	var hi := Vector2(maxf(size.x - r, r), maxf(size.y - r, r))
	return p.clamp(lo, hi)

# --- input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.index == _orphan:
				_orphan = -1   # a fresh press with that index: the old finger is long gone
			if _finger == -1 and _accepts(touch.position):
				_finger = touch.index
				_begin(touch.position)
			accept_event()
		elif touch.index == _finger:
			_reset()
			accept_event()
		elif touch.index == _orphan:
			# the orphaned finger lifted (the GUI delivers that release even while we
			# are hidden): it is gone, nothing to adopt any more
			_orphan = -1
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_move(drag.position)
		elif _finger == -1 and drag.index == _orphan and is_visible_in_tree() and _accepts(drag.position):
			# RESUME A THUMB THIS STICK OWNED. The GUI keeps routing a finger's drags
			# (and its release) to the control it pressed even while that control is
			# hidden (verified on 4.3), so a thumb still down across a death/respawn
			# or a pause arrives as drags with no press. Without this the stick stayed
			# dead after every death until the player lifted and re-touched (seen in
			# the real-browser playtest).
			# ONLY a finger recorded in _orphan may be adopted. A finger that pressed
			# while the controls were hidden also produces drags here but its RELEASE
			# is never delivered (measured), so adopting it would leave the hero
			# running forever. Hidden controls never adopt either.
			# Resume with the ORIGINAL base: the thumb has not moved, so its output
			# must come straight back (a held key resumes after a respawn too). A
			# fresh neutral at the thumb would leave the hero idle until it moved.
			_finger = _orphan
			_orphan = -1
			_origin = _orphan_origin
			_animate_active(1.0)
			_move(drag.position)
		accept_event()

func _accepts(local_pos: Vector2) -> bool:
	if mode == Mode.FIXED:
		return local_pos.distance_to(_rest) <= base_radius_dp * unit * 1.7
	return true

func _begin(local_pos: Vector2) -> void:
	_origin = _rest if mode == Mode.FIXED else local_pos
	_animate_active(1.0)
	_move(local_pos)

func _move(local_pos: Vector2) -> void:
	var radius: float = base_radius_dp * unit
	var delta: Vector2 = local_pos - _origin
	var dist: float = delta.length()
	if mode == Mode.FOLLOWING and dist > radius:
		# drag the base along so the finger stays on the rim
		_origin += delta / dist * (dist - radius)
		delta = local_pos - _origin
		dist = delta.length()
	_shown = delta if dist <= radius or dist == 0.0 else delta / dist * radius
	_apply(_shown / maxf(radius, 0.001))

func _apply(n: Vector2) -> void:
	var hx: float = shape_horizontal(n.x)
	_v_state = vertical_state(n, _v_state)
	# A mostly-vertical push is a climb / drop, not a sidestep: on a ladder
	# player.gd turns any horizontal axis into drift (0.6 x climb speed) and a
	# thumb a few degrees off vertical walked the hero out of the 44px ladder
	# zone. Only a deliberate diagonal (|x| >= |y|) keeps horizontal output.
	if _v_state != 0 and absf(n.x) < absf(n.y):
		hx = 0.0
	TouchActions.set_axis(&"move_left", &"move_right", hx)
	TouchActions.set_axis(&"move_up", &"move_down", float(_v_state))
	var v := Vector2(hx, float(_v_state))
	if not v.is_equal_approx(_value):
		_value = v
		value_changed.emit(_value)
	queue_redraw()

## Where the base RING is drawn: the logical origin, pushed back inside the region
## so the whole disc stays on screen near the edges (output never uses this).
func _draw_origin() -> Vector2:
	return _origin if mode == Mode.FIXED else _clamp_base(_origin)

## Current output: x = signed horizontal strength, y = -1 up / +1 down.
func value() -> Vector2:
	return _value

func is_active() -> bool:
	return _finger != -1

## Let go of everything from OUTSIDE (hide, pause, death, layout swap). The finger
## this stick was following is remembered so it can be resumed if it is still down
## when the controls come back (see _gui_input).
func release() -> void:
	if _finger != -1:
		_orphan = _finger
		_orphan_origin = _origin
	_reset()

## Drop the finger and every action. Used directly when the finger itself lifts.
func _reset() -> void:
	var was_active: bool = _finger != -1
	_finger = -1
	_v_state = 0
	TouchActions.release(&"move_left")
	TouchActions.release(&"move_right")
	TouchActions.release(&"move_up")
	TouchActions.release(&"move_down")
	if _value != Vector2.ZERO:
		_value = Vector2.ZERO
		value_changed.emit(_value)
	_origin = _rest
	_shown = Vector2.ZERO
	if was_active:
		_animate_active(0.0)
	else:
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

# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var col: Color = tint()
	var idle: float = hint_alpha() if hint_active else idle_alpha()
	# ghost ring at rest -> full base under the thumb
	var alpha: float = lerpf(idle * 0.62, pressed_alpha() * 0.62, _active_amount)
	var r: float = base_radius_dp * unit
	var k: float = knob_radius_dp * unit
	var ring_w: float = maxf((touch_theme.ring_width_dp if touch_theme != null else 2.5) * unit, 1.5)
	var c: Vector2 = _draw_origin()
	var knob_pos: Vector2 = c + _shown
	draw_circle(c, r, Color(col.r, col.g, col.b, alpha * 0.28))
	draw_arc(c, r, 0.0, TAU, 56, Color(col.r, col.g, col.b, alpha), ring_w, true)
	# four tiny rim ticks help the thumb find the directions without looking
	for i in 4:
		var d := Vector2.RIGHT.rotated(TAU * float(i) / 4.0)
		draw_line(c + d * r * 0.78, c + d * r * 0.94, Color(col.r, col.g, col.b, alpha * 0.9), ring_w, true)
	var knob_alpha: float = lerpf(idle * 0.9, pressed_alpha(), _active_amount)
	draw_circle(knob_pos, k, Color(col.r, col.g, col.b, knob_alpha * 0.55))
	draw_arc(knob_pos, k, 0.0, TAU, 40, Color(1, 1, 1, clampf(knob_alpha + 0.1, 0.0, 1.0)), ring_w, true)
