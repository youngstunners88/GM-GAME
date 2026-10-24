extends Node
## The wanted posters and the jail privy up close (skills ep2-wanted-posters, ep2-jail-privy) in the real Compatibility renderer from
## Lil Blunt's eye height; the town is built by the game's own Ep2GoldTown.build, so this is what the game draws.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/posters_privy_shot.tscn -- out=<dir>
var _out := ".farm/posters"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	Ep2GoldTown.apply_desert_grade(env.environment, sun, 1.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	ground.mesh = pm
	ground.material_override = Ep2GoldTown.desert_ground_mat()
	ground.position = Vector3(0, 0, 1450)
	world.add_child(ground)
	Ep2GoldTown.build(world, true)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	world.add_child(cam)
	cam.current = true
	var J := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Jail", p)
	var S := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Saloon", p)
	var C := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Certificates", p)
	var board: Vector3 = Ep2TownPosters.BOARD_POS
	var privy: Vector3 = J.call(Ep2GoldTown.jail_spots.get("privy", Vector3(-0.42, 0.5, -6.35)))
	var shots: Array = [
		["1_board_from_drop", Ep2GoldTown.DROP_POINT + Vector3(0, 1.65, 0), board + Vector3(0, 1.7, 0)],
		["2_board_close", board + Vector3(2.4, 1.65, 0.0), board + Vector3(0, 1.7, 0)],
		["3_saloon_porch", S.call(Vector3(0.4, 1.65, 3.4)), S.call(Vector3(0.0, 1.9, 0.0))],
		["4_certificates_porch", C.call(Vector3(0.6, 1.65, 3.2)), C.call(Vector3(0.0, 1.9, 0.0))],
		["5_jail_board", J.call(Vector3(1.2, 1.65, -1.2)), J.call(Vector3(3.44, 1.9, -2.05))],
		["6_privy_from_visit", J.call(Vector3(-1.85, 1.65, -4.05)), privy],
		["7_privy_close", J.call(Vector3(-0.9, 1.0, -5.05)), privy],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 8:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
	print("POSTERS_SHOT_DONE")
	get_tree().quit()
