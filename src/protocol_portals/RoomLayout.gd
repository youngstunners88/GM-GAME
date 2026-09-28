extends RefCounted
## Ground contacts authored on the paintings after the 50px vertical crop.
const STOPS := {
	"smoke": {"ash_ring": Vector2(1220, 990), "lounge_basket": Vector2(1740, 780), "arb_well": Vector2(2070, 930), "paper": Vector2(1320, 650), "video": Vector2(1590, 970), "exam": Vector2(1950, 800)},
	"diamonds": {"blaze_gate": Vector2(1540, 440), "tight_float": Vector2(1210, 510), "vault_crush": Vector2(2130, 535), "handler_bridge": Vector2(1050, 805), "paper": Vector2(1630, 650), "video": Vector2(2070, 345), "exam": Vector2(1890, 590)},
	"gold": {"vest_clock": Vector2(1400, 450), "knox_window": Vector2(1000, 790), "melt_stamp": Vector2(1740, 510), "rush_board": Vector2(1510, 820), "paper": Vector2(1640, 265), "video": Vector2(1330, 950), "exam": Vector2(1630, 620)},
}
const ENTRANCES := {"smoke": Vector2(1500, 1040), "diamonds": Vector2(650, 1010), "gold": Vector2(1090, 1020)}
const WAYSTONES := {"smoke": Vector2(1400, 1080), "diamonds": Vector2(505, 1060), "gold": Vector2(940, 1060)}
## Overlapping pieces follow garden paths, bridge/terrace, and town street.
const GROUND := {
	"smoke": [
		[Vector2(1360,1100), Vector2(1570,1100), Vector2(1780,850), Vector2(1560,790)],
		[Vector2(1090,890), Vector2(1210,1030), Vector2(1500,1100), Vector2(1460,990), Vector2(1260,925), Vector2(1180,810)],
		[Vector2(1130,880), Vector2(1240,860), Vector2(1570,730), Vector2(1550,655), Vector2(1360,690), Vector2(1160,780)],
		[Vector2(950,440), Vector2(1050,430), Vector2(1180,535), Vector2(1430,625), Vector2(1510,745), Vector2(1330,725), Vector2(1130,605)],
		[Vector2(1550,780), Vector2(1740,670), Vector2(2000,730), Vector2(2110,870), Vector2(1930,905), Vector2(1810,820)],
		[Vector2(1590,990), Vector2(1750,1080), Vector2(2150,980), Vector2(2150,850), Vector2(2030,890), Vector2(1950,970)],
	],
	"diamonds": [
		[Vector2(430,1100), Vector2(660,1100), Vector2(1450,610), Vector2(1350,530)],
		[Vector2(1250,665), Vector2(1420,660), Vector2(1640,460), Vector2(1550,370)],
		[Vector2(1110,415), Vector2(1230,370), Vector2(1510,450), Vector2(1440,575), Vector2(1240,600), Vector2(1130,535)],
		[Vector2(1420,565), Vector2(1740,480), Vector2(2140,460), Vector2(2230,560), Vector2(1930,655), Vector2(1530,690)],
		[Vector2(2010,265), Vector2(2160,265), Vector2(2270,450), Vector2(2220,555), Vector2(1990,515)],
	],
	"gold": [
		[Vector2(760,1100), Vector2(1500,1100), Vector2(1730,710), Vector2(1560,490), Vector2(1370,535), Vector2(1100,710)],
		[Vector2(1330,570), Vector2(1570,670), Vector2(1790,465), Vector2(1780,295), Vector2(1540,295)],
		[Vector2(1480,375), Vector2(1730,375), Vector2(1820,90), Vector2(1650,40), Vector2(1510,200)],
	],
}

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
