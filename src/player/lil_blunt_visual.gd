class_name LilBluntVisual
extends Node2D
## Procedurally drawn Lil Blunt — the chill green nugget mascot.
## Matches the launcher's character (rounded body, big friendly eyes, smile,
## leaf sprout) until hand-pixeled sprite sheets replace it. Drawn in a
## 32×32 footprint centred on this node's origin.
##
## Compatibility: exposes `color` (body tint — power-ups/outfits write it)
## and inherits `visible` (damage flicker), so existing call sites that used
## the old ColorRect keep working unchanged.

const OUTLINE := Color(0.07, 0.28, 0.12, 1.0)
const EYE_WHITE := Color(0.98, 0.99, 0.96, 1.0)
const PUPIL := Color(0.08, 0.09, 0.12, 1.0)
const CHEEK := Color(1.0, 0.55, 0.55, 0.30)
const LEAF := Color(0.15, 0.55, 0.25, 1.0)

## Body tint. Power-ups set cyan/green/red glows; outfits set theme colors.
var color: Color = Color(0.35, 0.85, 0.45, 1.0):
	set(value):
		color = value
		queue_redraw()

## Pupils and leaf lean toward the travel direction.
var facing_right: bool = true:
	set(value):
		if facing_right != value:
			facing_right = value
			queue_redraw()

func _draw() -> void:
	var dir := 1.0 if facing_right else -1.0

	# Body — slightly tall blob with outline.
	draw_set_transform(Vector2(0, 0.5), 0.0, Vector2(1.0, 1.08))
	draw_circle(Vector2.ZERO, 14.2, OUTLINE)
	draw_circle(Vector2.ZERO, 12.6, color)
	# Soft top-light so the body reads round, not flat.
	draw_circle(Vector2(-3.5, -5.0), 6.5, Color(1.0, 1.0, 1.0, 0.10))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Leaf sprout on the crown, leaning with movement.
	var base := Vector2(1.0 * dir, -14.0)
	draw_colored_polygon(PackedVector2Array([
		base, base + Vector2(-5.0 * dir, -5.5), base + Vector2(-1.0 * dir, -0.5),
	]), LEAF)
	draw_colored_polygon(PackedVector2Array([
		base, base + Vector2(3.5 * dir, -6.5), base + Vector2(1.5 * dir, 0.0),
	]), LEAF)

	# Eyes — big, white, slightly oval; pupils track facing.
	for ex in [-4.7, 4.7]:
		draw_set_transform(Vector2(ex, -2.0), 0.0, Vector2(1.0, 1.25))
		draw_circle(Vector2.ZERO, 3.7, EYE_WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2(ex + 1.1 * dir, -1.4), 1.7, PUPIL)

	# Blush cheeks.
	draw_circle(Vector2(-7.5, 2.8), 2.0, CHEEK)
	draw_circle(Vector2(7.5, 2.8), 2.0, CHEEK)

	# Chill smile.
	draw_arc(Vector2(0.0, 3.2), 4.6, 0.6, PI - 0.6, 12, PUPIL, 1.8, true)
