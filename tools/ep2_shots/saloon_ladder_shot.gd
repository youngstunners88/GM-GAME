extends Node
## THE SALOON'S SIDE LADDER in the real town chamber (founder 2026-11-21; skill ep2-saloon-roof-access): the ladder from the side lane and
## from the street, Lil Blunt climbing it (first person, rung by rung, and seen from the lane), the balcony with the two old regulars,
## the street from up there, and the stand-in the town draws before the streamed pack mounts.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/saloon_ladder_shot.tscn -- out=<dir>
const LADDER := preload("res://src/episode2/chamber/ep2_saloon_ladder.gd")
var chamber: GoldTownChamber
var vp: SubViewport
var out := ".farm/saloon_ladder"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	chamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate() as GoldTownChamber
	vp.add_child(chamber)
	chamber.setup(0, [], 0)
	chamber.set_physics_process(false)
	await get_tree().process_frame
	chamber.step(1.0 / 60.0)
	var lad = chamber.get_ladder()
	var S := func(v: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Saloon", v)
	# 1. the ladder from the side lane (south of the saloon) and from the street
	_orbit(S.call(Vector3(-11.5, 1.7, -3.5)), S.call(Vector3(-6.4, 2.4, 0.3)))
	await _shot("01_side_lane")
	_orbit(S.call(Vector3(-9.5, 1.6, 6.5)), S.call(Vector3(-5.0, 3.0, 0.4)))
	await _shot("02_street_corner")
	_eye(Ep2GoldTown.DROP_POINT, S.call(Vector3(-4.0, 3.2, 0.5)))
	await _shot("03_from_the_drop_point")
	# 2. the climb, first person: at the foot (prompt), then eight moments up the rungs and onto the balcony
	chamber._player_pos = lad.foot_world() + (lad.foot_world() - lad.to_world(LADDER.LADDER_AT)).normalized() * 0.4
	_face(S.call(Vector3(-6.42, 1.6, 0.3)), 0.25)
	chamber.step(1.0 / 60.0)
	await _shot("04_climb_prompt")
	chamber.start_rig("")
	var marks: Array = [0.5, 1.2, 2.0, 2.8, 3.5, 4.1, 4.6, 5.2]
	var t: float = 0.0
	var k: int = 0
	while lad.busy() and k < marks.size():
		chamber.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if t >= float(marks[k]):
			chamber._update_camera(0)
			await _shot("05_climb_%d_%.1fs" % [k, t])
			k += 1
	while lad.busy():
		chamber.step(1.0 / 60.0)
	# 3. up there: along the balcony to the old men, and down at the street
	var me: Vector3 = chamber.get_player_position()
	_face(S.call(Vector3(-1.6, Ep2GoldTown.BALCONY_Y + 1.4, 1.0)), 0.0)
	await _shot("06_top_the_old_men")
	_face(S.call(Vector3(-4.0, 0.0, 8.0)), 0.0)
	await _shot("07_top_over_the_street")
	_face(S.call(Vector3(-8.0, 0.5, 0.3)), 0.0)
	chamber.step(1.0 / 60.0)
	await _shot("08_top_climb_down_prompt")
	# 4. seen from the lane while he climbs (his body drawn for the shot)
	chamber.start_rig("")
	for i in 150:
		chamber.step(1.0 / 60.0)
	chamber._player_node.visible = true
	_orbit(S.call(Vector3(-11.0, 2.4, 2.8)), chamber.get_player_position() + Vector3(0, 1.0, 0), true)
	await _shot("09_climbing_seen_from_the_lane")
	while lad.busy():
		chamber.step(1.0 / 60.0)
	print("LADDER_SHOT climbs up=%d down=%d at %s streamed=%s" % [lad.climbs_up, lad.climbs_down, str(chamber.get_player_position()), str(lad.streamed)])
	# 5. the stand-in (no pack yet): the same ladder as rails, rungs and boards
	lad.get_node("Ladder").visible = false
	LADDER.force_stand_in = true
	var props: Array = []
	var stand = LADDER.build(chamber._visuals, null, props)
	stand.get_node("BalconyEndRails").visible = false
	LADDER.force_stand_in = false
	stand.set_process(false)
	_orbit(S.call(Vector3(-11.5, 1.7, -3.5)), S.call(Vector3(-6.4, 2.4, 0.3)))
	await _shot("10_side_lane_stand_in")
	print("SALOON_LADDER_SHOT_DONE")
	get_tree().quit()


## First-person eye at ground point `ground`, looking at `focus`.
func _eye(ground: Vector3, focus: Vector3) -> void:
	chamber._player_pos = Vector3(ground.x, 0.0, ground.z)
	_face(focus, 0.0)


func _face(focus: Vector3, _unused: float) -> void:
	var eye: Vector3 = chamber._player_pos + Vector3(0, chamber.eye_height, 0)
	var d: Vector3 = focus - eye
	chamber._look_yaw = atan2(d.x, d.z)
	chamber._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	chamber._update_camera(0)
	chamber._sync_visuals()


## A free camera (no rifle, no HUD) at `from` looking at `at`.
func _orbit(from: Vector3, at: Vector3, keep_body: bool = false) -> void:
	chamber._update_camera(0)
	chamber._sync_visuals()
	if chamber.get_viewmodel() != null:
		chamber.get_viewmodel().set_shown(false)
	chamber.get_hud().visible = false
	if keep_body:
		chamber._player_node.visible = true
	chamber._camera.global_position = from
	chamber._camera.look_at(at, Vector3.UP)
	chamber._camera.fov = 60.0


func _shot(label: String) -> void:
	for f in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg("%s/%s.jpg" % [out, label], 0.88)
