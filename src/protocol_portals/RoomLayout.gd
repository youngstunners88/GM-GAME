extends RefCounted
## Ground contacts authored on the paintings after the 50px vertical crop.
const STOPS := {
	"smoke": {"ash_ring": Vector2(906, 681), "lounge_basket": Vector2(1929, 681), "arb_well": Vector2(1403, 593), "paper": Vector2(760, 418), "video": Vector2(2104, 440), "exam": Vector2(1403, 388)},
	"diamonds": {"blaze_gate": Vector2(1680, 495), "tight_float": Vector2(1800, 600), "vault_crush": Vector2(2215, 455), "handler_bridge": Vector2(1100, 790), "paper": Vector2(1300, 490), "video": Vector2(2100, 325), "exam": Vector2(2040, 545)},
	"gold": {"vest_clock": Vector2(1520, 400), "knox_window": Vector2(1110, 850), "melt_stamp": Vector2(1650, 560), "rush_board": Vector2(1540, 890), "paper": Vector2(1640, 250), "video": Vector2(1310, 1010), "exam": Vector2(1370, 715)},
}
const ENTRANCES := {"smoke": Vector2(1439, 1039), "diamonds": Vector2(650, 1010), "gold": Vector2(1090, 1020)}
const WAYSTONES := {"smoke": Vector2(1286, 1061), "diamonds": Vector2(505, 1060), "gold": Vector2(940, 1060)}
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
		[Vector2(430,1100), Vector2(660,1100), Vector2(1450,610), Vector2(1350,530)],
		[Vector2(1250,665), Vector2(1420,660), Vector2(1640,460), Vector2(1550,370)],
		[Vector2(1110,415), Vector2(1230,370), Vector2(1510,450), Vector2(1440,575), Vector2(1240,600), Vector2(1130,535)],
		# wide junction so the bridge flows onto the plateau with no pinch point
		[Vector2(1380,560), Vector2(1500,470), Vector2(1700,470), Vector2(1760,610), Vector2(1560,700), Vector2(1400,660)],
		# the castle-front plateau: one open terrace, kept 60+ px in from the cliff lip
		[Vector2(1633,446), Vector2(1693,481), Vector2(2020,481), Vector2(2023,270), Vector2(2087,267), Vector2(2260,446), Vector2(2231,553), Vector2(2160,574), Vector2(1900,662), Vector2(1633,690), Vector2(1533,696), Vector2(1413,630), Vector2(1533,503), Vector2(1580,457)],
	],
	"gold": [
		[Vector2(760,1100), Vector2(1500,1100), Vector2(1730,710), Vector2(1560,490), Vector2(1370,535), Vector2(1100,710)],
		[Vector2(1330,570), Vector2(1570,670), Vector2(1790,465), Vector2(1780,295), Vector2(1540,295)],
		[Vector2(1480,375), Vector2(1730,375), Vector2(1820,90), Vector2(1650,40), Vector2(1510,200)],
	],
}

## Cell width (room px) of each painted prop. Smoke props are photoreal and sized
## against the painted lounge furniture (a chair + table set reads ~290 px wide).
const PROP_WIDTH := {
	"smoke": {"ash_ring": 210.0, "lounge_basket": 200.0, "arb_well": 230.0, "paper": 200.0,
		"video": 220.0, "exam": 315.0, "exit": 150.0},
	"diamonds": {"blaze_gate": 200.0, "tight_float": 195.0, "vault_crush": 225.0, "handler_bridge": 190.0,
		"paper": 200.0, "video": 190.0, "exam": 250.0, "exit": 150.0},
	"gold": {"vest_clock": 235.0, "knox_window": 215.0, "melt_stamp": 225.0, "rush_board": 245.0,
		"paper": 215.0, "video": 225.0, "exam": 290.0, "exit": 170.0},
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
			{"kind": "glow", "pos": Vector2(1613, 415), "size": Vector2(300, 340), "color": Color(1.0, 0.72, 0.32), "strength": 0.55, "pulse": 2.6},
			{"kind": "glow", "pos": Vector2(1690, 380), "size": Vector2(160, 170), "color": Color(1.0, 0.66, 0.26), "strength": 0.45, "pulse": 0.45},
			{"kind": "glow", "pos": Vector2(1267, 340), "size": Vector2(150, 260), "color": Color(0.40, 0.90, 0.95), "strength": 0.34, "pulse": 3.4},
			{"kind": "glow", "pos": Vector2(1777, 470), "size": Vector2(170, 290), "color": Color(0.40, 0.90, 0.95), "strength": 0.30, "pulse": 4.0},
			{"kind": "glow", "pos": Vector2(2093, 300), "size": Vector2(140, 240), "color": Color(0.40, 0.90, 0.95), "strength": 0.30, "pulse": 3.0},
			{"kind": "rise", "pos": Vector2(1613, 470), "extent": Vector2(36, 8), "color": Color(1.0, 0.80, 0.45), "amount": 10},
			{"kind": "rise", "pos": Vector2(1690, 420), "extent": Vector2(22, 6), "color": Color(1.0, 0.75, 0.35), "amount": 8},
		],
	},
	"gold": {
		"haze": Color(0.97, 0.84, 0.58), "far": 0.15, "near": 0.05,
		"sources": [{"kind": "drift", "pos": Vector2(1300, 600)}],
		# Golden-hour sun bloom from the canyon mouth, and sun glints on the coin heaps.
		"accents": [
			{"kind": "glow", "pos": Vector2(1500, 140), "size": Vector2(760, 520), "color": Color(1.0, 0.82, 0.45), "strength": 0.24, "pulse": 5.0},
			{"kind": "glints", "pos": Vector2(880, 700), "extent": Vector2(110, 70), "color": Color(1.0, 0.88, 0.5), "amount": 9},
			{"kind": "glints", "pos": Vector2(770, 960), "extent": Vector2(110, 60), "color": Color(1.0, 0.88, 0.5), "amount": 8},
			{"kind": "glints", "pos": Vector2(1855, 745), "extent": Vector2(150, 70), "color": Color(1.0, 0.88, 0.5), "amount": 10},
			{"kind": "glints", "pos": Vector2(1590, 940), "extent": Vector2(100, 80), "color": Color(1.0, 0.88, 0.5), "amount": 8},
		],
	},
}

## Rooms with a real drop: walking off the ground by more than this many px is a fall
## (the player loses a life; the advisor never does). Founder 2026-09-30.
const FALL_MARGIN := {"diamonds": 46.0}

static func overhang(protocol: String, point: Vector2) -> float:
	if contains(protocol, point):
		return 0.0
	return point.distance_to(constrain(protocol, point))

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
