class_name TouchLayout
extends Control
## Root of a layout scene (`layouts/*.tscn`). A layout is a PURE SCENE: it only
## composes `VirtualJoystick` / `VirtualButton` nodes with their anchor, offset,
## radius, glyph and action set in the inspector. This script adds no input
## logic; it positions its controls from the current metrics and fans out
## theme / hint / release calls.
##
## Adding a control later (an Episode 2 chamber action, a second stick) is
## dropping another VirtualButton into the scene - nothing here changes.

## Extra size multiplier for this layout's tier (tablets get larger targets).
@export var tier_scale: float = 1.0
## The layout key this scene answers to (the registry key in MobileLayoutManager.LAYOUT_SCENES,
## e.g. "phone_landscape" or "blaze_phone_landscape").
@export var layout_name: StringName = &"phone_landscape"
## The touch profile this scene belongs to ("platformer", "blaze", "ep2_runner", ...).
@export var profile: StringName = &"platformer"

func _ready() -> void:
	# Sized explicitly from the metrics in apply(); no anchors, so there is no
	# competing layout pass and the scene instances identically anywhere.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Every virtual control in this layout, in tree order.
func controls() -> Array[VirtualControl]:
	var out: Array[VirtualControl] = []
	_collect(self, out)
	return out

func _collect(node: Node, out: Array[VirtualControl]) -> void:
	for child in node.get_children():
		if child is VirtualControl:
			out.append(child)
		_collect(child, out)

## First button bound to `action`, or null.
func find_button(action: StringName) -> VirtualButton:
	for c in controls():
		if c is VirtualButton and (c as VirtualButton).action == action:
			return c
	return null

## First control with the given colour `role`, or null.
func find_role(role: StringName) -> VirtualControl:
	for c in controls():
		if c.role == role:
			return c
	return null

## Re-place every control for the current screen. `user_scale` is the player's
## own button-size preference.
func apply(m: TouchMetrics, user_scale: float, theme: TouchTheme) -> void:
	position = Vector2.ZERO
	size = m.viewport_size
	for c in controls():
		c.touch_theme = theme
		c.apply_layout(m, tier_scale * user_scale)

func apply_theme(theme: TouchTheme) -> void:
	for c in controls():
		c.touch_theme = theme
		c.queue_redraw()

## Show / hide the first-time hint (labels + stronger opacity).
func set_hint(on: bool) -> void:
	for c in controls():
		c.set_hint(on)

## Drop every finger and held action in this layout.
func release_all() -> void:
	for c in controls():
		c.release()

## Make every control ignore touches (a layer that is fading out) or listen again.
func set_inert(on: bool) -> void:
	for c in controls():
		c.set_inert(on)

## Fan out "injection is suspended / resumed" (death, pause) to controls that hold an
## action on their own (the swipe pad's duck).
func on_suspended(on: bool) -> void:
	for c in controls():
		c.on_suspended(on)
