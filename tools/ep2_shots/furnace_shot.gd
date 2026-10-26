extends Node
## THE SMELTER'S FURNACE (founder 2026-10-25: "Inferno hideout smelting facility - hyperreal props, furnace, kegs, tools, surfaces - not
## grey primitives"): fixed views of the furnace in the real hideout, for a before / after board (run the same script on master for
## "before"). 1600x900 SubViewport (the tiling window manager squashes a real window).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/furnace_shot.tscn -- out=<dir>
const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
## [label, eye, look-at] in the facility's frame (the furnace mouth is at (-6.3, 1.7, 16.05), the exit at (0, 0, 15); the cauldrons at
## (-4.8, 12.5) and (-2.8, 13.9) stand between the room and the furnace, so the views come from in front of the mouth and from the exit)
const VIEWS: Array = [
	["furnace_front", Vector3(-6.2, 1.8, 13.6), Vector3(-6.3, 2.8, 16.1)],
	["furnace_exit", Vector3(-1.2, 2.0, 15.2), Vector3(-6.6, 2.8, 15.8)],
	["furnace_high", Vector3(-3.2, 3.4, 13.2), Vector3(-6.3, 3.6, 16.2)],
	["furnace_close", Vector3(-5.9, 1.4, 14.6), Vector3(-6.3, 1.4, 16.1)],
]
var vp: SubViewport
var out := ".farm/furnace"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var f = SMELT.instantiate()
	f.intro_film = false
	vp.add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	await get_tree().process_frame
	f._beat = int(f.Beat.EXIT)
	f._has_winchester = true
	f._has_helmet = true
	f._player_pos = Vector3(0.4, 0.0, 3.4)
	for _i in 120:
		f.step(1.0 / 60.0)
		f._hold = 99.0
		await get_tree().process_frame
	var cam: Camera3D = f._camera
	for v in VIEWS:
		cam.position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for _k in 6:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_jpg("%s/%s.jpg" % [out, str(v[0])], 0.88)
	print("FURNACE_SHOT_DONE")
	get_tree().quit()
