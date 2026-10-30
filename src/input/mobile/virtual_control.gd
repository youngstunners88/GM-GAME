class_name VirtualControl
extends Control
## Base for every on-screen touch control (button, stick).
##
## Controls are real `Control` nodes living in the touch CanvasLayer, NOT
## `TouchScreenButton`s and NOT a hand-rolled `_input` router. Verified on the
## shipped engine (Godot 4.3, tests/mobile_touch_controls_test.gd): the GUI hands
## `InputEventScreenTouch` / `InputEventScreenDrag` to the Control under each
## finger, keeps delivering that finger's drag + release to the SAME control even
## after it slides off, and tracks fingers independently by `index`. That gives:
##   * true multi-touch (stick + jump + attack at once) with no bookkeeping,
##   * correct z-order for free: a modal panel on a HIGHER canvas layer wins the
##     touch where it has a stop-filter Control, so quiz buttons stay tappable,
##   * `_has_point` for round hit areas bigger than what is drawn.
##
## Subclasses only implement `_gui_input` (their own finger) and `_draw`.
## They talk to gameplay exclusively through `TouchActions` -> InputMap.
##
## Placement is data: each control names a screen corner, an offset in dp measured
## INWARD from that corner and a radius in dp. The layout scene sets those; the
## `TouchLayout` calls `apply_layout()` whenever the screen changes.
##
## NO TEXT, EVER: controls draw vector shapes only (founder, 2026-10-13: a phone UI has
## no written words). There is deliberately no text-drawing helper here; the wordless
## scan tests walk every layout scene and fail on any Label / Button / text property.
##
## Rules every subclass follows (the stick set them, the pads/field reuse them):
##   * per-finger ownership: a control acts only on a finger it PRESSED itself
##   * the orphan rule: never adopt a finger it did not press (after a hide the GUI
##     still routes that finger's drags, and a finger that pressed while hidden never
##     delivers a release)
##   * release() on hide / rotation / focus loss drops every finger and action
##   * a faint visible resting cue (these are not invisible zones). The one exception is the
##     whole-screen tap field (Blaze), which acknowledges each tap with a ring instead.

enum ScreenAnchor { BOTTOM_LEFT, BOTTOM_RIGHT, BOTTOM_CENTER, TOP_LEFT, TOP_RIGHT, TOP_CENTER }

@export var anchor_corner: ScreenAnchor = ScreenAnchor.BOTTOM_RIGHT
## Centre of the control, in dp, measured inward from `anchor_corner`.
@export var offset_dp: Vector2 = Vector2(96, 92)
## Visible radius in dp.
@export var radius_dp: float = 40.0
## Extra invisible hit radius in dp (thumbs are fat and imprecise).
@export var hit_pad_dp: float = 10.0
## Colour role looked up in the TouchTheme ("jump", "attack", "dash", ...).
@export var role: StringName = &"jump"

var touch_theme: TouchTheme
## Canvas units per dp for THIS control (metrics dp x user scale x tier scale).
var unit: float = 1.0
## Canvas units per dp of the SCREEN (metrics dp, no user/tier scale). Finger-travel
## thresholds (swipe distances, look slop) are measured with this, not with `unit`:
## a bigger button should not make a swipe longer.
var dp: float = 1.0
var hint_active: bool = false : set = set_hint
## A context cue (a verb is in range): the disc brightens and gains an outer ring, no words.
var cue_active: bool = false : set = set_cue
## The mouse filter this control returns to after set_inert(false).
var base_mouse_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	mouse_filter = base_mouse_filter
	focus_mode = Control.FOCUS_NONE
	visibility_changed.connect(_on_visibility_changed)

func _exit_tree() -> void:
	release()

## Position and size from the metrics. Buttons are circles sized to their hit
## radius; the visible disc is drawn inside it.
func apply_layout(m: TouchMetrics, unit_scale: float) -> void:
	unit = m.dp * unit_scale
	dp = m.dp
	var vis_r: float = radius_dp * unit
	var hit_r: float = (radius_dp + hit_pad_dp) * unit
	var rect: Rect2 = m.safe_rect
	var origin: Vector2 = rect.position
	var sx: float = 1.0
	var sy: float = 1.0
	match anchor_corner:
		ScreenAnchor.BOTTOM_LEFT:
			origin = Vector2(rect.position.x, rect.end.y); sy = -1.0
		ScreenAnchor.BOTTOM_RIGHT:
			origin = Vector2(rect.end.x, rect.end.y); sx = -1.0; sy = -1.0
		ScreenAnchor.BOTTOM_CENTER:
			origin = Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y); sy = -1.0
		ScreenAnchor.TOP_LEFT:
			origin = rect.position
		ScreenAnchor.TOP_RIGHT:
			origin = Vector2(rect.end.x, rect.position.y); sx = -1.0
		ScreenAnchor.TOP_CENTER:
			origin = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)
	var c: Vector2 = origin + Vector2(offset_dp.x * sx, offset_dp.y * sy) * unit
	# Keep the visible disc inside the safe area on tiny screens.
	var lo: Vector2 = rect.position + Vector2(vis_r, vis_r)
	var hi: Vector2 = Vector2(maxf(rect.end.x - vis_r, lo.x), maxf(rect.end.y - vis_r, lo.y))
	c = c.clamp(lo, hi)
	size = Vector2.ONE * hit_r * 2.0
	position = c - size * 0.5
	queue_redraw()

## Circular hit test (local coordinates).
func _has_point(point: Vector2) -> bool:
	var half: float = size.x * 0.5
	return point.distance_to(Vector2(half, half)) <= half

func set_hint(on: bool) -> void:
	hint_active = on
	queue_redraw()

## Light this control as a wordless "a verb is available here" cue; only the button draws it.
func set_cue(on: bool) -> void:
	if cue_active == on:
		return
	cue_active = on
	queue_redraw()

## Drop every finger / action this control holds. Overridden by subclasses.
func release() -> void:
	pass

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		release()

## Local-space centre of the hit circle.
func local_center() -> Vector2:
	return size * 0.5

func tint() -> Color:
	return touch_theme.tint_for(role) if touch_theme != null else Color(0.8, 0.9, 0.85)

func idle_alpha() -> float:
	return touch_theme.idle_alpha if touch_theme != null else 0.3

func pressed_alpha() -> float:
	return touch_theme.pressed_alpha if touch_theme != null else 0.78

func hint_alpha() -> float:
	return touch_theme.hint_alpha if touch_theme != null else 0.88

## While true the control ignores every touch (mouse_filter IGNORE) so a layer that is
## fading out can never take a press that lands during the fade.
func set_inert(on: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if on else base_mouse_filter

## The layout manager tells every control when injection is suspended (death / pause)
## or resumes. Default: nothing. Controls that hold an action of their own accord
## (the swipe pad's duck) drop it here.
func on_suspended(_on: bool) -> void:
	pass
