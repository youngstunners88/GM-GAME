class_name BlazeRotateCue
extends Control
## One-time, WORDLESS "turn the phone sideways" hint for Blaze Rush in portrait.
##
## The founder's rule (2026-10-13, angry): a phone UI is icons and finger
## movement, never words. This is a drawn phone outline, a faint landscape ghost
## and a curved arrow between them, pulsing for ~2.6 s, once per session. It is
## NON-BLOCKING (mouse_filter IGNORE, the run keeps going): portrait stays
## playable through the framing zoom; the cue only suggests the better shape.
## A web orientation lock is not available on iOS, so it can never be a gate.

const DURATION: float = 2.6
const CREAM := Color(1.0, 0.95, 0.75, 1.0)
const DARK := Color(0.06, 0.0, 0.12, 0.95)

## Shown at most once per session (a static survives scene reloads, so a Blaze
## re-entry does not nag).
static var _shown_once: bool = false

static func was_shown() -> bool:
	return _shown_once

## Test hook: forget that the cue has been shown.
static func reset_for_test() -> void:
	_shown_once = false

## Build the cue under `parent` on its own CanvasLayer (above the HUD, below the
## touch layer) and return it. `dp` = canvas units per dp, so the icon is a
## constant physical size on every screen.
static func show_on(parent: Node, dp: float) -> BlazeRotateCue:
	_shown_once = true
	var layer := CanvasLayer.new()
	layer.name = "RotateCueLayer"
	layer.layer = 30
	parent.add_child(layer)
	var cue := BlazeRotateCue.new()
	cue.name = "RotateCue"
	cue.unit = maxf(dp, 0.1)
	layer.add_child(cue)
	return cue

## Canvas units per dp (set by show_on before the node enters the tree).
var unit: float = 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	# Two soft pulses, then gone. Frees its whole layer so nothing lingers.
	modulate.a = 0.0
	var tw := create_tween()
	for i in range(2):
		tw.tween_property(self, "modulate:a", 1.0, DURATION * 0.2)
		tw.tween_property(self, "modulate:a", 0.35, DURATION * 0.3)
	tw.tween_property(self, "modulate:a", 0.0, DURATION * 0.1)
	tw.tween_callback(func() -> void:
		var layer: Node = get_parent()
		if is_instance_valid(layer):
			layer.queue_free())

func _draw() -> void:
	var u: float = unit
	var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.30)
	var phone: Vector2 = Vector2(24.0, 42.0) * u
	# The turned phone first (faint ghost), then the upright one over it.
	_draw_phone(c + Vector2(34.0, 0.0) * u, phone, PI * 0.5, Color(CREAM, 0.45), 2.0 * u)
	_draw_phone(c - Vector2(34.0, 0.0) * u, phone, 0.0, CREAM, 2.5 * u)
	# Curved arrow from the upright phone to the turned one.
	var r: float = 40.0 * u
	var centre: Vector2 = c + Vector2(0.0, 6.0) * u
	var a0: float = deg_to_rad(-165.0)
	var a1: float = deg_to_rad(-20.0)
	draw_arc(centre, r, a0, a1, 24, DARK, 6.0 * u, true)
	draw_arc(centre, r, a0, a1, 24, CREAM, 3.0 * u, true)
	var tip: Vector2 = centre + Vector2.from_angle(a1) * r
	var dir: Vector2 = Vector2.from_angle(a1 + PI * 0.5)
	var side: Vector2 = dir.orthogonal()
	var head: PackedVector2Array = PackedVector2Array([
		tip + dir * 9.0 * u,
		tip - dir * 3.0 * u + side * 8.0 * u,
		tip - dir * 3.0 * u - side * 8.0 * u,
	])
	draw_colored_polygon(head, CREAM)
	draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), DARK, 1.5 * u, true)

func _draw_phone(centre: Vector2, size_px: Vector2, angle: float, col: Color, width: float) -> void:
	draw_set_transform(centre, angle, Vector2.ONE)
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0, 0, 0, 0)
	dark.set_border_width_all(int(ceilf(width + 3.0)))
	dark.border_color = DARK
	dark.set_corner_radius_all(int(size_px.x * 0.2))
	draw_style_box(dark, Rect2(-size_px * 0.5 - Vector2(1.5, 1.5), size_px + Vector2(3.0, 3.0)))
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0, 0, 0, 0)
	lit.set_border_width_all(int(ceilf(width)))
	lit.border_color = col
	lit.set_corner_radius_all(int(size_px.x * 0.2))
	draw_style_box(lit, Rect2(-size_px * 0.5, size_px))
	draw_set_transform_matrix(Transform2D.IDENTITY)
