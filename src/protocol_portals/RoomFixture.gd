extends Node2D
## Solid, readable furniture at each learning stop. Drawn locally so the web
## export cannot silently lose an optional sprite import. No collision changes.

var kind: String = ""
var accent: Color = Color(0.35, 1.0, 0.45)
const STONE := Color("59616a")
const EDGE := Color("929a9f")
const DARK := Color("222831")
const WOOD := Color("74553d")
const PAPER := Color("e4d7b5")

func _draw() -> void:
	# Contact shadow and plinth anchor every object to the map.
	draw_ellipse(Vector2(0, -12), Vector2(102, 24), Color(0, 0, 0, 0.45))
	box(Rect2(-82, -28, 164, 22), STONE)
	match kind:
		"ash_ring":
			box(Rect2(-58, -100, 116, 74), DARK)
			draw_ellipse(Vector2(0, -98), Vector2(70, 30), EDGE)
			draw_ellipse(Vector2(0, -98), Vector2(55, 21), DARK)
			for i in range(7):
				var x: float = -39.0 + i * 13.0
				draw_line(Vector2(x, -97), Vector2(x + 6, -118 - (i % 3) * 9), Color("f4bb73"), 5)
			draw_arc(Vector2(0, -102), 48, PI, TAU, 32, accent, 4, true)
		"lounge_basket":
			box(Rect2(-70, -114, 140, 82), WOOD)
			for x in range(-60, 70, 20):
				draw_line(Vector2(x, -110), Vector2(x + 14, -34), PAPER.darkened(0.35), 4)
			for y in range(-100, -30, 18):
				draw_line(Vector2(-67, y), Vector2(67, y), DARK, 3)
			draw_arc(Vector2(0, -106), 52, PI, TAU, 32, EDGE, 8, true)
			for x in [-27, 27]:
				draw_circle(Vector2(x, -115), 23, accent.darkened(0.45))
				draw_arc(Vector2(x, -115), 23, 0, TAU, 32, accent, 3, true)
		"arb_well":
			box(Rect2(-65, -88, 130, 58), STONE)
			for y in [-70, -48]:
				draw_line(Vector2(-62, y), Vector2(62, y), DARK, 3)
			for x in [-40, 0, 40]:
				draw_line(Vector2(x, -86), Vector2(x, -33), DARK, 3)
			draw_ellipse(Vector2(0, -90), Vector2(77, 30), EDGE)
			draw_ellipse(Vector2(0, -92), Vector2(57, 19), DARK)
			draw_arc(Vector2(0, -104), 39, 0.2, 5.4, 32, accent, 5, true)
			draw_line(Vector2(-65, -92), Vector2(-65, -186), WOOD, 10)
			draw_line(Vector2(65, -92), Vector2(65, -186), WOOD, 10)
			box(Rect2(-78, -192, 156, 14), WOOD.lightened(0.15))
			draw_line(Vector2(0, -180), Vector2(0, -115), PAPER, 3)
		"blaze_gate", "melt_stamp":
			box(Rect2(-68, -166, 136, 136), STONE)
			box(Rect2(-50, -145, 100, 88), DARK)
			for i in range(5):
				var x: float = -36.0 + i * 18.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 10, -62), Vector2(x, -120 - i % 2 * 18), Vector2(x + 13, -62)]), Color("e1a457"))
			for x in range(-50, 60, 20):
				draw_line(Vector2(x, -144), Vector2(x, -59), EDGE, 4)
			box(Rect2(-80, -181, 160, 15), EDGE)
		"tight_float", "vault_crush":
			box(Rect2(-70, -174, 140, 144), STONE)
			box(Rect2(-54, -157, 108, 110), DARK)
			for x in [-24, 24]:
				crystal(Vector2(x, -76), 30)
			draw_arc(Vector2(0, -103), 42, 0, TAU, 32, EDGE, 6, true)
			draw_line(Vector2(-25, -103), Vector2(25, -103), EDGE, 5)
			draw_line(Vector2(0, -128), Vector2(0, -78), EDGE, 5)
		"handler_bridge":
			for x in [-65, 65]:
				box(Rect2(x - 10, -163, 20, 137), STONE)
			box(Rect2(-90, -86, 180, 22), WOOD)
			for x in range(-80, 90, 20):
				draw_line(Vector2(x, -84), Vector2(x, -66), EDGE, 2)
			draw_line(Vector2(-70, -151), Vector2(70, -151), accent, 4)
			crystal(Vector2(0, -100), 30)
		"vest_clock":
			box(Rect2(-54, -188, 108, 158), WOOD)
			draw_circle(Vector2(0, -131), 48, PAPER)
			draw_arc(Vector2(0, -131), 48, 0, TAU, 48, EDGE, 6, true)
			for i in range(12):
				var v := Vector2.from_angle(i * TAU / 12.0)
				draw_line(Vector2(0, -131) + v * 36, Vector2(0, -131) + v * 42, DARK, 3)
			draw_line(Vector2(0, -131), Vector2(0, -161), DARK, 5)
			draw_line(Vector2(0, -131), Vector2(25, -116), DARK, 5)
			draw_line(Vector2(0, -75), Vector2(0, -44), EDGE, 3)
			draw_circle(Vector2(0, -44), 10, accent)
		"knox_window":
			box(Rect2(-78, -168, 156, 138), STONE)
			box(Rect2(-61, -151, 122, 103), DARK)
			for row in range(3):
				for col in range(3):
					box(Rect2(-52 + col * 36, -73 - row * 24, 30, 17), Color("d5ad51"))
			for x in [-42, 0, 42]:
				draw_line(Vector2(x, -149), Vector2(x, -47), EDGE, 5)
		"rush_board":
			box(Rect2(-83, -182, 166, 133), WOOD)
			box(Rect2(-71, -169, 142, 107), DARK)
			for row in range(3):
				box(Rect2(-58, -157 + row * 30, 112, 22), PAPER)
				draw_line(Vector2(-47, -146 + row * 30), Vector2(37, -146 + row * 30), WOOD, 3)
			for x in [-63, 63]:
				draw_line(Vector2(x, -49), Vector2(x, -23), WOOD, 9)
		"exam":
			for x in [-80, 66]:
				box(Rect2(x, -89, 14, 65), WOOD.darkened(0.2))
			box(Rect2(-96, -110, 192, 27), WOOD)
			box(Rect2(-50, -123, 70, 13), PAPER)
			draw_line(Vector2(-16, -123), Vector2(-16, -111), WOOD, 2)
			draw_line(Vector2(56, -112), Vector2(56, -168), EDGE, 6)
			draw_colored_polygon(PackedVector2Array([Vector2(23, -159), Vector2(40, -190), Vector2(72, -190), Vector2(90, -159)]), accent.darkened(0.25))

func box(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, DARK, false, 3)
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(rect.size.x - 2, 2), color.lightened(0.25), 2)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		points.append(center + Vector2(cos(i * TAU / 48), sin(i * TAU / 48)) * radius)
	draw_colored_polygon(points, color)

func crystal(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius * 1.7), center + Vector2(radius, -radius * 0.6), center + Vector2(radius * 0.6, radius * 0.6), center + Vector2(-radius * 0.6, radius * 0.6), center + Vector2(-radius, -radius * 0.6)])
	draw_colored_polygon(points, accent.darkened(0.2))
	draw_line(points[0], points[2], Color.WHITE, 2)
	draw_line(points[0], points[3], accent.lightened(0.4), 3)
