extends Node
## Exact first-frame handoff captures; no replacement pose after activating the lift.
var out := "/workspace/work/fix-doc-1029/views"
var vp: SubViewport
func shot(name: String) -> void:
	for i in 3: await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join(name + ".png"))
func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1280,720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var session := Ep2SessionRoot.new()
	vp.add_child(session)
	session.set_process(false)
	var facility: SmeltingFacilityChamber = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	facility.intro_film = false
	session.add_child(facility)
	session._active = facility
	session._wire_chamber(facility)
	facility.setup()
	facility.set_physics_process(false)
	facility._on_video_film_finished()
	session._drive_prebuild(1.0e9)
	facility._beat = facility.Beat.EXIT
	facility._show_active = false
	facility._show_blocks_control = false
	facility._hold = 0
	facility._player_pos = Vector3(.25,0,facility.PORTAL_Z-.04)
	facility._look_yaw = .18
	facility._look_pitch = -.04
	facility._move_input = Vector2(0,1)
	facility._moving = true
	facility._walk_phase = 1.7
	facility._bull.position = Vector3(.7,0,facility.PORTAL_Z+3)
	facility._bull.play(facility._bull.walk_clip)
	facility._bull.anim.seek(.4,true)
	facility._update_camera(0)
	session._drive_portal()
	await shot("door-before")
	print("DOOR_BEFORE ",facility._camera.global_transform)
	facility._player_pos.z += .08
	session._chain_id = "mine_lift"
	session._enter_chamber_chained(0)
	var lift: MineLiftChamber = session._active
	lift.set_physics_process(false)
	await shot("door-after")
	print("DOOR_AFTER ",lift._camera.global_transform)
	print("FIX_DOOR_REVIEW_DONE")
	get_tree().quit()
