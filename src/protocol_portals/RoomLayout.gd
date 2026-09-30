extends RefCounted
## Ground contacts authored on the paintings after the 50px vertical crop.
const STOPS := {
	"smoke": {"ash_ring": Vector2(906, 681), "lounge_basket": Vector2(1929, 681), "arb_well": Vector2(1403, 593), "paper": Vector2(760, 418), "video": Vector2(2104, 440), "exam": Vector2(1403, 388)},
	"diamonds": {"blaze_gate": Vector2(1575, 480), "tight_float": Vector2(2280, 490), "vault_crush": Vector2(2380, 750), "handler_bridge": Vector2(1070, 650), "paper": Vector2(1230, 450), "video": Vector2(1610, 790), "exam": Vector2(1960, 720)},
	"gold": {"vest_clock": Vector2(1270, 430), "knox_window": Vector2(910, 720), "melt_stamp": Vector2(1950, 610), "rush_board": Vector2(1920, 920), "paper": Vector2(1640, 330), "video": Vector2(1030, 1020), "exam": Vector2(1180, 810)},
}
const ENTRANCES := {"smoke": Vector2(1439, 1039), "diamonds": Vector2(650, 1010), "gold": Vector2(1460, 1030)}
const WAYSTONES := {"smoke": Vector2(1286, 1061), "diamonds": Vector2(505, 1060), "gold": Vector2(1350, 1060)}
## Overlapping pieces follow garden paths, bridge/terrace, and town street.
const GROUND := {
	"smoke": [
		[Vector2(570, 301), Vector2(1220, 274), Vector2(1225, 236), Vector2(1581, 236), Vector2(1586, 274), Vector2(2280, 301), Vector2(2327, 388), Vector2(2321, 710), Vector2(2280, 827), Vector2(2104, 878), Vector2(1651, 885), Vector2(1605, 944), Vector2(1605, 1119), Vector2(1187, 1119), Vector2(1184, 944), Vector2(1154, 841), Vector2(818, 841), Vector2(614, 812), Vector2(529, 739), Vector2(504, 535), Vector2(526, 388)],
		# the three lounges are walk-in (founder 2026-09-30): main doorway, west and east pergola lounges
		[Vector2(1240, 262), Vector2(1575, 262), Vector2(1575, 70), Vector2(1240, 70)],
		[Vector2(90, 230), Vector2(470, 200), Vector2(560, 300), Vector2(570, 520), Vector2(480, 520), Vector2(120, 470)],
		[Vector2(2320, 380), Vector2(2520, 330), Vector2(2780, 330), Vector2(2780, 620), Vector2(2560, 640), Vector2(2320, 600)],
	],
	"diamonds": [
		# A broad bridge merges into the repainted forecourt; no prop crosses it.
		[Vector2(340,1100), Vector2(760,1100), Vector2(1350,710), Vector2(1060,620)],
		[Vector2(925,595), Vector2(1090,440), Vector2(1290,340), Vector2(1340,405), Vector2(1350,500), Vector2(1550,530), Vector2(1600,450), Vector2(1660,510), Vector2(1880,540), Vector2(2070,460), Vector2(2080,320), Vector2(2260,390), Vector2(2510,520), Vector2(2560,700), Vector2(2440,815), Vector2(2260,900), Vector2(1990,900), Vector2(1870,840), Vector2(1770,880), Vector2(1290,835), Vector2(1150,775), Vector2(1040,710), Vector2(875,650)],
	],
	"gold": [
		# Broad square, with boardwalks outside the walking route.
		[Vector2(640,1100), Vector2(2200,1100), Vector2(1990,960), Vector2(2030,850), Vector2(2190,660), Vector2(1990,560), Vector2(1890,480), Vector2(1970,350), Vector2(1810,280), Vector2(1700,230), Vector2(1750,100), Vector2(1660,50), Vector2(1550,240), Vector2(1560,320), Vector2(1210,260), Vector2(1190,380), Vector2(890,460), Vector2(820,630), Vector2(760,760), Vector2(580,900)],
	],
}

## Cell width (room px) of each painted prop. Smoke props are photoreal and sized
## against the painted lounge furniture (a chair + table set reads ~290 px wide).
const PROP_WIDTH := {
	"smoke": {"ash_ring": 210.0, "lounge_basket": 200.0, "arb_well": 230.0, "paper": 200.0,
		"video": 220.0, "exam": 315.0, "exit": 150.0},
	"diamonds": {"blaze_gate": 0.0, "tight_float": 145.0, "vault_crush": 180.0, "handler_bridge": 140.0,
		"paper": 150.0, "video": 145.0, "exam": 190.0, "exit": 115.0},
	"gold": {"vest_clock": 165.0, "knox_window": 175.0, "melt_stamp": 180.0, "rush_board": 180.0,
		"paper": 120.0, "video": 160.0, "exam": 190.0, "exit": 120.0},
}
const DEFAULT_PROP_WIDTH := 125.0

## Atmosphere per room. haze = drifting fog shaders (far one behind the props, near one
## in front for depth); sources = particle wisps. "kind": door = smoke blowing out of the
## lounge, rise = a curling column, drift = wide horizontal breeze. Neutral colours only
## (never green-dominant: the blotch rule).
const ATMOSPHERE := {
	"smoke": {
		"haze": Color(0.86, 0.80, 0.94), "far": 0.36, "near": 0.10,
		"sources": [
			{"kind": "door", "pos": Vector2(1403, 245)},
			{"kind": "rise", "pos": Vector2(906, 640)},
			{"kind": "rise", "pos": Vector2(250, 360)},
			{"kind": "rise", "pos": Vector2(2540, 470)},
			{"kind": "drift", "pos": Vector2(1400, 760)},
		],
	},
	"diamonds": {
		"haze": Color(0.66, 0.90, 0.96), "far": 0.16, "near": 0.05,
		"sources": [{"kind": "drift", "pos": Vector2(1500, 500)}],
		# Accent what the painting already shows: the archway is the way in, so it glows
		# warm (no separate gate prop); the crystals pulse cyan (never green-dominant).
		"accents": [
			{"kind": "glow", "pos": Vector2(1585, 420), "size": Vector2(210, 260), "color": Color(1.0, 0.72, 0.32), "strength": 0.24, "pulse": 2.6},
			{"kind": "glow", "pos": Vector2(1320, 300), "size": Vector2(110, 170), "color": Color(0.40, 0.90, 0.95), "strength": 0.18, "pulse": 3.4},
			{"kind": "glow", "pos": Vector2(2010, 450), "size": Vector2(100, 160), "color": Color(0.40, 0.90, 0.95), "strength": 0.18, "pulse": 4.0},
			{"kind": "glow", "pos": Vector2(1870, 870), "size": Vector2(160, 170), "color": Color(0.40, 0.90, 0.95), "strength": 0.18, "pulse": 3.0},
		],
	},
	"gold": {
		"haze": Color(0.97, 0.84, 0.58), "far": 0.15, "near": 0.05,
		"sources": [{"kind": "drift", "pos": Vector2(1300, 600)}],
		# Golden-hour sun bloom from the canyon mouth, and sun glints on the coin heaps.
		"accents": [
			{"kind": "glow", "pos": Vector2(1500, 140), "size": Vector2(760, 520), "color": Color(1.0, 0.82, 0.45), "strength": 0.24, "pulse": 5.0},
			{"kind": "glints", "pos": Vector2(720, 690), "extent": Vector2(110, 70), "color": Color(1.0, 0.88, 0.5), "amount": 9},
			{"kind": "glints", "pos": Vector2(620, 805), "extent": Vector2(110, 60), "color": Color(1.0, 0.88, 0.5), "amount": 8},
			{"kind": "glints", "pos": Vector2(2130, 900), "extent": Vector2(150, 70), "color": Color(1.0, 0.88, 0.5), "amount": 10},
			{"kind": "glints", "pos": Vector2(2080, 495), "extent": Vector2(100, 80), "color": Color(1.0, 0.88, 0.5), "amount": 8},
		],
	},
}

static func prop_width(protocol: String, kind: String) -> float:
	var table: Dictionary = PROP_WIDTH.get(protocol, {})
	return float(table.get(kind, DEFAULT_PROP_WIDTH))

static func polygons(protocol: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for points in GROUND[protocol]:
		result.append(PackedVector2Array(points))
	return result

static func contains(protocol: String, point: Vector2) -> bool:
	for polygon in polygons(protocol):
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false

static func constrain(protocol: String, point: Vector2) -> Vector2:
	if contains(protocol, point):
		return point
	var nearest := Vector2.ZERO
	var distance := INF
	for polygon in polygons(protocol):
		for i in polygon.size():
			var candidate := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
			var d := point.distance_squared_to(candidate)
			if d < distance:
				distance = d
				nearest = candidate
	return nearest
