class_name VirtualRotateCue
extends VirtualControl
## "Turn your phone sideways", with no words: a dimmed screen, a drawn phone outline that
## swings from upright to sideways and a curved arrow round it. Shown by the `ep2_rotate`
## profile when the Episode 2 runner / on-foot room is opened in portrait (they cannot be
## framed upright); the room pauses until the screen is landscape.
##
## It swallows touches (STOP over the whole viewport) so a tap on the dim screen cannot
## fall through to the paused room as an emulated click (a stray shot, a camera capture).

## Seconds for one swing cycle.
const CYCLE_SECONDS := 2.8

## Swallow every touch while shown (default). False = purely visual.
@export var swallow_input: bool = true

var _t: float = 0.0

func _ready() -> void:
	base_mouse_filter = Control.MOUSE_FILTER_STOP if swallow_input else Control.MOUSE_FILTER_IGNORE
	super()
	set_process(is_visible_in_tree())

func apply_layout(m: TouchMetrics, unit_scale: float) -> void:
	unit = m.dp * unit_scale
	dp = m.dp
	position = Vector2.ZERO
	size = m.viewport_size
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

func _gui_input(event: InputEvent) -> void:
	if swallow_input:
		accept_event()

func _on_visibility_changed() -> void:
	super()
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	_t = fmod(_t + delta, CYCLE_SECONDS)
	queue_redraw()

func _draw() -> void:
	var col: Color = tint()
	var c: Vector2 = size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.62))
	# swing: hold upright, turn to sideways, hold, fade back
	var k: float = _t / CYCLE_SECONDS
	var turn: float = smoothstep(0.15, 0.55, k)
	var angle: float = -PI * 0.5 * turn
	var fade: float = 1.0 - smoothstep(0.88, 1.0, k)
	var a: float = 0.9 * fade
	var w: float = 40.0 * unit
	var h: float = 72.0 * unit
	var stroke: float = maxf(3.0 * unit, 2.0)
	draw_set_transform(c, angle, Vector2.ONE)
	draw_polyline(_rounded_rect(Vector2(-w, -h), Vector2(w, h), 12.0 * unit), Color(1, 1, 1, a), stroke, true)
	draw_line(Vector2(-w * 0.28, -h * 0.84), Vector2(w * 0.28, -h * 0.84), Color(1, 1, 1, a * 0.8), stroke, true)
	draw_circle(Vector2(0.0, h * 0.86), 3.0 * unit, Color(1, 1, 1, a * 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the curved arrow, clockwise from the top-left round to the right
	var rad: float = 118.0 * unit
	var a0: float = -PI * 0.88
	var a1: float = -PI * 0.12
	var arrow := Color(col.r, col.g, col.b, 0.95 * fade)
	draw_arc(c, rad, a0, a1, 32, arrow, stroke * 1.3, true)
	var e: Vector2 = c + Vector2(cos(a1), sin(a1)) * rad
	var radial := Vector2(cos(a1), sin(a1))
	var tangent := Vector2(-sin(a1), cos(a1))
	draw_colored_polygon(PackedVector2Array([e + tangent * 20.0 * unit, e + radial * 14.0 * unit, e - radial * 14.0 * unit]), arrow)

## Outline of a rounded rectangle as a closed polyline.
func _rounded_rect(lo: Vector2, hi: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners: Array = [
		[Vector2(hi.x - r, lo.y + r), -PI * 0.5],
		[Vector2(hi.x - r, hi.y - r), 0.0],
		[Vector2(lo.x + r, hi.y - r), PI * 0.5],
		[Vector2(lo.x + r, lo.y + r), PI],
	]
	for corner: Array in corners:
		var centre: Vector2 = corner[0]
		var start: float = corner[1]
		for i in 7:
			var ang: float = start + (PI * 0.5) * float(i) / 6.0
			pts.append(centre + Vector2(cos(ang), sin(ang)) * r)
	pts.append(pts[0])
	return pts
