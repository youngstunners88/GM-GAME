extends Node
## P1-5 (founder 2026-11-22: "The horse that Lil Blunt mounts needs to not fucking change color"): pick the WHITE horse at Dude's yard,
## see it led to the rail he mounts at; then the trail and the auction road ride that coat.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/horse_coat_shot.tscn -- out=<dir>
var _out := ".farm/horse_coat"


func _save(name: String) -> void:
	for j in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var town: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	town.set_process(false)
	var yard: Ep2StableYard = town._stable_yard
	var white: int = yard.horses.map(func(h: Node3D) -> String: return Ep2HorseCoat.coat_of(h)).find("white")
	if white == yard.rail_index():
		white = yard.horses.map(func(h: Node3D) -> String: return Ep2HorseCoat.coat_of(h)).find("black")     # pick a horse that is not already at the rail
	var coat: String = Ep2HorseCoat.coat_of(yard.horses[white])
	yard.try_choose(yard.horses[white].global_position + Vector3(1.0, 0.0, 0.0))
	for i in 30 * 20: yard.step(1.0 / 30.0, GoldTownChamber.DEPART_HORSE)
	var cam := Camera3D.new()
	cam.fov = 65.0
	add_child(cam)
	cam.current = true
	cam.global_position = GoldTownChamber.DEPART_HORSE + Vector3(3.5, 1.7, 3.0)
	cam.look_at(GoldTownChamber.DEPART_HORSE + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	await _save("1_town_rail_%s" % coat)
	town.queue_free()
	await get_tree().process_frame
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	trail.handoff = {"horse": true, "horse_coat": coat, "horse_index": white}
	add_child(trail)
	trail.set_physics_process(false)
	trail.setup(0, [], 0)
	trail.set_process(false)
	trail._place_at_distance(60.0)
	trail._look_yaw = trail._travel_yaw
	trail._look_pitch = -0.45                                   # looking down at the horse's neck under him
	trail._update_camera(0)
	trail._sync_visuals()
	await _save("2_trail_mounted_%s" % coat)
	trail.queue_free()
	await get_tree().process_frame
	var road: AuctionRoadChamber = load("res://src/episode2/chamber/auction_road.tscn").instantiate()
	road.handoff = {"road_mounted": true}
	add_child(road)
	road.set_physics_process(false)
	road.setup(0, [], 0)
	road.set_process(false)
	road._look_pitch = -0.45
	road._update_camera(0)
	await _save("3_road_mounted_%s" % coat)
	print("HORSE_COAT_SHOT_DONE ", coat, " ", _out)
	get_tree().quit()
