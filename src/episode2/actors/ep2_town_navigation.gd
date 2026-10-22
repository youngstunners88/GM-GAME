class_name Ep2TownNavigation
extends RefCounted
## Outdoor walking graph built from the same walls/props as the player, with swept edges.
## Building interiors/raised porches and the west firing yard are deliberately outside this flat graph.
const RADIUS := 0.34
const SPACING := 0.8
const ORIGIN := Vector2(-34.0, 1393.0)
const SIZE := Vector2i(51, 90)
var graph := AStar2D.new()
var walls: Array = []
var props: Array = []
var blocked_rects: Array[Rect2] = []
var cells: Dictionary = {}

func configure(info: Dictionary) -> void:
	walls = info.get("walls", []).duplicate(true)
	props = info.get("props", []).duplicate(true)
	graph.clear()
	cells.clear()
	blocked_rects.clear()
	for entry in Ep2GoldTown.LAYOUT:
		var key: String = str(entry[0])
		var fp: Array = Ep2GoldTown.FOOTPRINT[key]
		if key == "Bldg_Armory" and Ep2GoldTown.armory_v2: fp = Ep2GoldTown.FOOTPRINT["Bldg_Armory2"]
		var xf: Transform3D = Ep2GoldTown.building_xform(entry)
		var rect := Rect2(Vector2(xf.origin.x, xf.origin.z), Vector2.ZERO)
		for x in [-1.0, 1.0]:
			for z in [-float(fp[1]) - 0.2, 1.7]:
				# Front porch projects beyond the building's front wall.
				var p: Vector3 = xf * Vector3(x * (float(fp[0]) * 0.5 + 0.3), 0, z)
				rect = rect.expand(Vector2(p.x, p.z))
		blocked_rects.append(rect.grow(RADIUS))
	# The Gatling shoots west of the armory; ambient civilians never enter its firing yard.
	blocked_rects.append(Rect2(-50, 1455, 22, 20))
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var p: Vector2 = ORIGIN + Vector2(cell) * SPACING
			if is_clear(p):
				var id: int = y * SIZE.x + x
				graph.add_point(id, p)
				cells[cell] = id
	for cell in cells:
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var other: Vector2i = cell + offset
			if cells.has(other):
				var a: Vector2 = graph.get_point_position(cells[cell])
				var b: Vector2 = graph.get_point_position(cells[other])
				if segment_clear(a, b): graph.connect_points(cells[cell], cells[other])
	# Conservative porch exclusions can leave small, isolated yard pockets.
	# Only admit the component reachable from Main Street for starts and destinations.
	var anchor: int = graph.get_closest_point(Vector2(0, 1422))
	var reachable: Dictionary = {}
	var pending: Array[int] = []
	if anchor >= 0: pending.append(anchor)
	while not pending.is_empty():
		var id: int = pending.pop_back()
		if reachable.has(id): continue
		reachable[id] = true
		for neighbour in graph.get_point_connections(id):
			if not reachable.has(neighbour): pending.append(neighbour)
	for id in graph.get_point_ids():
		if not reachable.has(id): graph.remove_point(id)
	for cell in cells.keys():
		if not reachable.has(cells[cell]): cells.erase(cell)

func is_clear(p: Vector2) -> bool:
	if not Rect2(ORIGIN, Vector2(SIZE - Vector2i.ONE) * SPACING).has_point(p): return false
	for rect in blocked_rects:
		if rect.has_point(p): return false
	return Ep2GoldTown.collide(p, RADIUS, walls, props).distance_to(p) < 0.002

func segment_clear(a: Vector2, b: Vector2) -> bool:
	var count: int = maxi(1, ceili(a.distance_to(b) / 0.16))
	for i in count + 1:
		if not is_clear(a.lerp(b, float(i) / count)): return false
	return true

func closest(p: Vector2) -> Vector2:
	var id: int = graph.get_closest_point(p)
	return graph.get_point_position(id) if id >= 0 else p

func path(a: Vector2, b: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if graph.get_point_count() == 0: return result
	var start: int = graph.get_closest_point(a)
	var finish: int = graph.get_closest_point(b)
	if start < 0 or finish < 0: return result
	var points: PackedVector2Array = graph.get_point_path(start, finish)
	if points.is_empty() or not segment_clear(a, points[0]): return result
	# Greedy line-of-sight simplification keeps a collision-tested path without zigzagging on every grid cell.
	var anchor: Vector2 = a
	var index: int = 0
	while index < points.size():
		var last: int = index
		while last + 1 < points.size() and segment_clear(anchor, points[last + 1]): last += 1
		if anchor.distance_to(points[last]) > 0.08: result.append(points[last])
		anchor = points[last]
		index = last + 1
	return result
