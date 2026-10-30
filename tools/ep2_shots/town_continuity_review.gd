extends Node
## Doorway/ranch baseline and candidate from the actual equipped player camera.
var out := "/workspace/work/town-continuity-1029/baseline"
var vp: SubViewport
func shot(label: String) -> void:
	for i in 3: await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join(label+".png"))
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):out=arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp=SubViewport.new()
	vp.size=Vector2i(1280,720)
	vp.own_world_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var town: GoldTownChamber=load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	vp.add_child(town)
	town.setup()
	town.set_physics_process(false)
	town._show_active=false
	town._show_blocks_control=false
	town._hold=0
	town._advance_to(town.Beat.GEARED)
	town._show_active=false
	town.release_look()
	town._sheriff.place(town._jail_spot("sheriff"))
	if OS.get_cmdline_user_args().has("edge"):
		var xf: Transform3D=Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Jail"))
		var d: Vector3=xf.basis*Vector3(0,0,-1)
		for x in [-0.4,0.4]:
			for z in [0.6,-0.3,-1.5]:
				town._player_pos=xf*Vector3(x,0,z)
				town._look_yaw=atan2(d.x,d.z)
				town._look_pitch=-0.04
				town._update_camera(0)
				await shot("jail-x%.1f-z%.1f"%[x,z])
		print("TOWN_CONTINUITY_REVIEW: SIX EDGE VIEWS")
		get_tree().quit()
		return
	for piece in ([] if OS.get_cmdline_user_args().has("ranch") else ["Bldg_Jail","Bldg_Certificates"]):
		var xf: Transform3D=Ep2GoldTown.building_xform(Ep2GoldTown.entry(piece))
		var d: Vector3=xf.basis*Vector3(0,0,-1)
		for index in 6:
			var z: float=[3.0,0.6,0.1,-0.3,-1.5,-3.0][index]
			town._player_pos=xf*Vector3(0,0,z)
			town._look_yaw=atan2(d.x,d.z)
			town._look_pitch=-0.04
			town._update_camera(0)
			print("DOOR_VIEW ",piece," ",z," camera=",town._camera.global_transform)
			await shot(piece+"-%02d"%index)
	town._player_pos=GoldTownChamber.DEPART_HORSE+Vector3(2,0,2)
	town._look_yaw=atan2(LakeTrailChamber.TRAIL_POINTS[1].x,LakeTrailChamber.TRAIL_POINTS[1].y)
	town._look_pitch=-0.13
	town._update_camera(0)
	await shot("ranch-road-before-mount")
	if OS.get_cmdline_user_args().has("ranch"):
		print("TOWN_CONTINUITY_REVIEW: RANCH CAPTURED")
		get_tree().quit()
		return
	print("TOWN_CONTINUITY_REVIEW: THIRTEEN CAPTURED")
	get_tree().quit()
