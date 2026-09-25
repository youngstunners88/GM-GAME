extends SceneTree
# Probe: does the player walk in a tour room? Holds move_right ~1 s and reports x delta + state.
func _initialize() -> void:
	var room: Node = load("res://src/protocol_portals/rooms/smoke/ReadingRing.tscn").instantiate()
	root.add_child(room)
	for i in 200: await physics_frame
	var p: Node = get_first_node_in_group("player")
	if p == null:
		print("PROBE: no player"); quit(1); return
	var x0: float = p.global_position.x
	var info := "paused=%s pmode=%d phys=%s layer=%d mask=%d" % [paused, p.process_mode, p.is_physics_processing(), p.collision_layer, p.collision_mask]
	for k in ["_climbing", "_ladder_zones", "_input_locked", "_frozen", "is_dead", "can_move", "_cutscene"]:
		if k in p: info += " %s=%s" % [k, str(p.get(k))]
	Input.action_press("move_right")
	for i in 60: await physics_frame
	Input.action_release("move_right")
	print("PROBE: x0=%.1f x1=%.1f dx=%.1f %s" % [x0, p.global_position.x, p.global_position.x - x0, info])
	quit(0)
