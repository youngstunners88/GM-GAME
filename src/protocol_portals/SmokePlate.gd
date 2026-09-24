extends Node2D
## The SMOKE whitepaper plate, drawn in code.
##
## The diamonds/gold rooms hang a founder JPEG on the wall; smoke has no art, so
## this node renders the plate's `draw_spec` as a flat 512x512 disc design:
## dark ground, neon rim circles, a burnt ash ring, the central sink hole, eight
## inward burn arrows and the two word marks.
##
## Only three colours are used (background / rim / accent), read straight out of
## the draw_spec dictionary so a copy tweak re-tints the plate.
## SmokePlate draws with the fallback font (draw_string) — the design's text is
## pure ASCII on purpose.

const DESIGN_SIZE: float = 512.0
const CENTRE: Vector2 = Vector2(256.0, 256.0)

## The plate.draw_spec dictionary from portal_copy.json. Assigned by StudyRoom
## before the node enters the tree; the defaults below match the shipped copy.
var draw_spec: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var background: Color = _spec_color("background", Color(0.043, 0.078, 0.063))
	var rim: Color = _spec_color("rim", Color(0.224, 1.0, 0.533))
	var accent: Color = _spec_color("accent", Color(0.714, 1.0, 0.816))

	# 1. Ground: full square, then a faint radial lift at the centre.
	draw_rect(Rect2(0.0, 0.0, DESIGN_SIZE, DESIGN_SIZE), background)
	draw_circle(CENTRE, 250.0, background.lightened(0.06))

	# 2. Outer rim (r=236) and a thinner, softer inner ring (r=214).
	draw_arc(CENTRE, 236.0, 0.0, TAU, 160, rim, 6.0, true)
	draw_arc(CENTRE, 214.0, 0.0, TAU, 160, Color(rim.r, rim.g, rim.b, 0.4), 2.0, true)

	# 3. Ash ring: 40 short arcs along r=225, alternating alpha, reading as a
	#    burnt paper edge.
	for i in range(40):
		var start: float = TAU * float(i) / 40.0
		var alpha: float = 0.85 if (i % 2) == 0 else 0.35
		draw_arc(CENTRE, 225.0, start, start + (TAU / 40.0) * 0.5, 4,
			Color(rim.r, rim.g, rim.b, alpha), 3.0, true)

	# 4. Sink hole (r=96) and the lounge-basket mark inside it.
	draw_circle(CENTRE, 96.0, Color(0.02, 0.04, 0.03))
	draw_arc(CENTRE, 96.0, 0.0, TAU, 96, rim, 4.0, true)
	for i in range(3):
		var bar := Rect2(CENTRE.x - 34.0, CENTRE.y - 18.0 + float(i) * 16.0, 68.0, 9.0)
		draw_rect(bar, Color(accent.r, accent.g, accent.b, 0.9 - 0.2 * float(i)))

	# 5. Burn arrows: eight chevrons on r=160, all pointing inward.
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var outward := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-outward.y, outward.x)
		var base: Vector2 = CENTRE + outward * 160.0
		var tri := PackedVector2Array([
			base - outward * 12.0,
			base + outward * 6.0 + perp * 9.0,
			base + outward * 6.0 - perp * 9.0,
		])
		draw_colored_polygon(tri, accent)

	# 6. Word marks. draw_string with a width centres the text for us.
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(0.0, CENTRE.y - 26.0), "SMOKE",
		HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE, 44, accent)
	draw_string(font, Vector2(0.0, CENTRE.y + 12.0), "culture + sink",
		HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE, 28, rim)

	# 7. Four corner ticks on the outer ring at the 45-degree marks.
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 + TAU / 8.0
		var outward := Vector2(cos(angle), sin(angle))
		var outer: Vector2 = CENTRE + outward * 248.0
		var inner: Vector2 = CENTRE + outward * 222.0
		draw_line(inner, outer, rim, 5.0, true)


## Reads one "#rrggbb" colour out of the draw_spec, falling back when absent.
func _spec_color(key: String, fallback: Color) -> Color:
	var raw: Variant = draw_spec.get(key, null)
	if typeof(raw) != TYPE_STRING:
		return fallback
	var text: String = String(raw)
	if text.is_empty():
		return fallback
	return Color.from_string(text, fallback)
