class_name LilBluntVisual
extends Node2D
## Procedurally drawn Lil Blunt matching the client's reference art
## (design/art_direction_reference.md): shaggy green weed-leaf body, brown
## cowboy hat with leaf badge, googly white eyes with dotted red rims, huge
## grin, red bandana, tan fringe vest, blunt with smoke puffs.
## Drawn in a 32×32 footprint centred on this node's origin — placeholder
## until hand-pixeled sprite sheets replace it.
##
## Compatibility: exposes `color` (body tint — power-ups/outfits write it)
## and inherits `visible` (damage flicker), so existing call sites keep
## working unchanged.

const OUTLINE := Color(0.05, 0.20, 0.09, 1.0)
const LEAF_DARK := Color(0.10, 0.45, 0.18, 1.0)
const EYE_WHITE := Color(0.99, 0.99, 0.97, 1.0)
const EYE_RIM := Color(0.95, 0.93, 0.82, 1.0)
const EYE_DOT := Color(0.85, 0.25, 0.20, 0.9)
const PUPIL := Color(0.06, 0.07, 0.10, 1.0)
const MOUTH := Color(0.25, 0.08, 0.10, 1.0)
const TEETH := Color(0.99, 0.99, 0.95, 1.0)
const HAT := Color(0.42, 0.26, 0.12, 1.0)
const HAT_BAND := Color(0.28, 0.16, 0.07, 1.0)
const BANDANA := Color(0.78, 0.15, 0.12, 1.0)
const VEST := Color(0.62, 0.42, 0.18, 1.0)
const BLUNT := Color(0.55, 0.33, 0.16, 1.0)
const BLUNT_TIP := Color(0.95, 0.45, 0.15, 1.0)
const SMOKE := Color(0.85, 0.82, 0.95, 0.55)

## Body tint. Power-ups set cyan/green/red glows; outfits set theme colors.
var color: Color = Color(0.32, 0.72, 0.30, 1.0):
	set(value):
		color = value
		queue_redraw()

## Pupils, blunt, and hat lean toward the travel direction.
var facing_right: bool = true:
	set(value):
		if facing_right != value:
			facing_right = value
			queue_redraw()

func _draw() -> void:
	var dir := 1.0 if facing_right else -1.0

	# Spiky leaf mane behind the body — reads as the shaggy weed silhouette.
	for i in range(10):
		var ang := -PI / 2.0 + (i - 4.5) * 0.33
		var base_pt := Vector2(cos(ang), sin(ang)) * 10.0 + Vector2(0, 1)
		var tip := Vector2(cos(ang), sin(ang)) * 16.5 + Vector2(0, 1)
		var side := Vector2(-sin(ang), cos(ang)) * 2.6
		draw_colored_polygon(PackedVector2Array([base_pt + side, tip, base_pt - side]), LEAF_DARK)

	# Body — round green nugget with outline and top-light.
	draw_set_transform(Vector2(0, 1.5), 0.0, Vector2(1.0, 1.06))
	draw_circle(Vector2.ZERO, 12.6, OUTLINE)
	draw_circle(Vector2.ZERO, 11.2, color)
	draw_circle(Vector2(-3.0, -4.0), 5.5, Color(1.0, 1.0, 1.0, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Tan fringe vest — two panels at the lower body.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.5, 4.0), Vector2(-3.5, 6.5), Vector2(-4.5, 12.0), Vector2(-9.5, 9.0),
	]), VEST)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8.5, 4.0), Vector2(3.5, 6.5), Vector2(4.5, 12.0), Vector2(9.5, 9.0),
	]), VEST)

	# Red bandana under the face.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6.5, 4.5), Vector2(6.5, 4.5), Vector2(0.0, 9.5),
	]), BANDANA)

	# Cowboy hat: wide brim + dented crown + band with a tiny leaf badge.
	draw_set_transform(Vector2(0.6 * dir, -9.5), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 12.0, OUTLINE)
	draw_circle(Vector2.ZERO, 10.8, HAT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.0 + 0.6 * dir, -10.0), Vector2(-5.0 + 0.8 * dir, -17.5),
		Vector2(5.5 + 0.8 * dir, -17.0), Vector2(7.0 + 0.6 * dir, -10.0),
	]), HAT)
	draw_rect(Rect2(-7.0 + 0.6 * dir, -12.0, 14.0, 2.2), HAT_BAND)
	# Leaf badge on the band: three tiny blades.
	var badge := Vector2(0.6 * dir, -12.6)
	for off in [-1.0, 0.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			badge, badge + Vector2(off * 2.2 - 0.6, -2.8), badge + Vector2(off * 2.2 + 0.6, -2.6),
		]), Color(0.35, 0.85, 0.35, 1.0))

	# Googly eyes: cream rim with red dots, white ball, dark pupil.
	for ex in [-4.6, 4.6]:
		draw_circle(Vector2(ex, -3.0), 4.4, EYE_RIM)
		for d in range(8):
			var a := d * TAU / 8.0
			draw_circle(Vector2(ex, -3.0) + Vector2(cos(a), sin(a)) * 3.9, 0.5, EYE_DOT)
		draw_circle(Vector2(ex, -3.0), 3.1, EYE_WHITE)
		draw_circle(Vector2(ex + 1.2 * dir, -2.6), 1.5, PUPIL)

	# Huge open grin with teeth.
	draw_set_transform(Vector2(0, 3.0), 0.0, Vector2(1.0, 0.72))
	draw_circle(Vector2.ZERO, 5.6, OUTLINE)
	draw_circle(Vector2.ZERO, 4.7, MOUTH)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-4.4, 1.4, 8.8, 2.0), TEETH)

	# Blunt at the mouth corner with ember + smoke puffs.
	var mouth_corner := Vector2(4.2 * dir, 4.6)
	draw_set_transform(mouth_corner, 0.35 * dir, Vector2.ONE)
	draw_rect(Rect2(0.0, -1.1, 7.0, 2.2), BLUNT)
	draw_rect(Rect2(7.0, -1.1, 1.6, 2.2), BLUNT_TIP)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tip_pos := mouth_corner + Vector2(8.2, 2.6).rotated(0.35 * dir) * Vector2(dir, 1.0)
	draw_circle(tip_pos + Vector2(1.0 * dir, -3.0), 1.5, SMOKE)
	draw_circle(tip_pos + Vector2(2.2 * dir, -6.0), 2.0, SMOKE)
