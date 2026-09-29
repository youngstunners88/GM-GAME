extends SceneTree
## Drive real input along collision-aware routes: no teleporting between stations.
const Layout := preload("res://src/protocol_portals/RoomLayout.gd")
var failures := 0
var ground = Layout

func _initialize() -> void:
	Engine.time_scale = 3.0
	for protocol in ["smoke", "diamonds", "gold"]:
		await exercise(protocol)
	Engine.time_scale = 1.0
	print("PORTAL TRAVERSAL: ALL PASS" if failures == 0 else "PORTAL TRAVERSAL: FAILURES %d" % failures)
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + message)
	if not ok: failures += 1

func exercise(protocol: String) -> void:
	var room: Node2D = load("res://src/protocol_portals/StudyRoom.tscn").instantiate()
	room.protocol = protocol
	root.add_child(room)
	await create_timer(0.8).timeout
	var player: CharacterBody2D = room.get_node("Player")
	var guide: Node2D = room.get_node("Companion")
	var lives: int = root.get_node("GameManager").lives
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 141, 56)
	grid.cell_size = Vector2(20, 20)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var obstacles: Array[Rect2] = []
	for stop in get_nodes_in_group("portal_stop"):
		if not room.is_ancestor_of(stop): continue
		var shape: CollisionShape2D = stop.get_node_or_null("Fixture/Footprint/CollisionShape2D")
		if shape != null:
			obstacles.append(Rect2(shape.global_position - shape.shape.size * 0.5, shape.shape.size).grow(27.0))
	for x in range(141):
		for y in range(56):
			var point := Vector2(x * 20, y * 20)
			var blocked: bool = not ground.contains(protocol, point)
			for rect in obstacles:
				blocked = blocked or rect.has_point(point)
			grid.set_point_solid(Vector2i(x, y), blocked)
	var order: Array = ["paper"]
	order.append_array(room.get("_required_learning_stops"))
	order.append_array(["video", "exam"])
	for id in order:
		var stop: Node2D = room.get_node("Stop_" + id)
		var target := stop.position + Vector2(0, 60)
		var walked := await walk_to(player, guide, grid, target, protocol)
		check(walked, "%s: walks to %s with furniture collisions" % [protocol, id])
		if not walked: continue
		check(player.position.distance_to(stop.position + Vector2(0, 28)) < 100, "%s: %s is within E range" % [protocol, id])
		await create_timer(0.25).timeout
		var key := InputEventAction.new()
		key.action = "interact"
		key.pressed = true
		root.push_input(key)
		await process_frame
		check(room.is_overlay_open(), "%s: E activates %s after walking there" % [protocol, id])
		if id in room.get("_required_learning_stops"):
			var named_mechanism := false
			for item in room.get("_overlay_box").get_children():
				if item is Label and item.text == stop.stop_name: named_mechanism = true
			check(named_mechanism, "%s: E selects the correct mechanism %s" % [protocol, id])
		key.pressed = false
		root.push_input(key)
		room.close_overlay()
		await process_frame
	# Visit all three lounge interiors as part of a continuous walk.
	if protocol == "smoke":
		for interior in [Vector2(1400, 130), Vector2(300, 350), Vector2(2570, 470)]:
			check(await walk_to(player, guide, grid, interior, protocol), "smoke: enters lounge %s" % interior)
	# Hold movement into the bridge edge longer than the removed fall timer.
	if protocol == "diamonds":
		check(await walk_to(player, guide, grid, Layout.ENTRANCES[protocol], protocol), "diamonds: returns across bridge")
		Input.action_press("move_left")
		for frame in range(60): await physics_frame
		Input.action_release("move_left")
		check(player.modulate.a > 0.99 and player.is_physics_processing(), "diamonds: edge does not trigger fall/fade/respawn")
		check(player.position.distance_to(ground.constrain(protocol, player.position)) < 0.5, "diamonds: edge stays on safe ground")
	check(root.get_node("GameManager").lives == lives, "%s: education does not consume a life" % protocol)
	await create_timer(1.0).timeout
	check(guide.position.distance_to(player.position) < 130, "%s: advisor catches up and stays nearby" % protocol)
	room.queue_free()
	await process_frame

func walk_to(player: CharacterBody2D, guide: Node2D, grid: AStarGrid2D, target: Vector2, protocol: String) -> bool:
	var start := Vector2i((player.position / 20.0).round())
	var end := Vector2i((target / 20.0).round())
	if not grid.region.has_point(start) or not grid.region.has_point(end): return false
	if grid.is_point_solid(start) or grid.is_point_solid(end): return false
	var route := grid.get_point_path(start, end)
	if route.is_empty(): return false
	for waypoint in route:
		var frames := 0
		while player.position.distance_to(waypoint) > 13.0 and frames < 60:
			var direction: Vector2 = (waypoint - player.position).normalized()
			for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
			if direction.x < -0.05: Input.action_press("move_left", -direction.x)
			if direction.x > 0.05: Input.action_press("move_right", direction.x)
			if direction.y < -0.05: Input.action_press("move_up", -direction.y)
			if direction.y > 0.05: Input.action_press("move_down", direction.y)
			await physics_frame
			frames += 1
			if guide.position.distance_to(ground.constrain(protocol, guide.position)) > 0.5:
				check(false, "%s: advisor leaves safe ground" % protocol)
				break
		for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
		if frames >= 60:
			print("STUCK: %s at %s approaching %s" % [protocol, player.position, waypoint])
			return false
	return player.position.distance_to(target) < 35.0
