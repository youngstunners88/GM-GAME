extends Node
## One first-person weapon view on its own, neutral light, seen from four sides (muzzle +Z): what the hands on it really look like, away from the game's
## camera crop. `view=` an armory id (sharps_buffalo, borchardt_c93, bear_longbow, pickaxe ...); `draw=` 0..1 poses the bow.
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/ep2_shots/held_view_probe.tscn -- out=<dir> view=sharps_buffalo
var _out := ".farm/held_view"
var _id := Ep2ArmoryState.BUFF
var _draw := 0.0
var _dist := 1.1
## icon=<png>: instead of the five views, write the weapon's Tabs card (640 x 320, transparent, seen from his left, the grown sleeves left out so the arms
## end inside the card like the other weapons' icons).
var _icon := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("view="):
			_id = a.substr(5)
		elif a.begins_with("draw="):
			_draw = float(a.substr(5))
		elif a.begins_with("icon="):
			_icon = a.substr(5)
		elif a.begins_with("dist="):
			_dist = float(a.substr(5))
	DirAccess.make_dir_recursive_absolute(_out)
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 700)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.55, 0.58)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.7, 0.0)
	vp.add_child(sun)
	var view: Node3D
	if _id == Ep2ArmoryState.BOW:
		view = Ep2BowView.make(true)
		Ep2BowView.update(view, _draw, true)
	elif _id == "gun_hand":
		# the Remington's glove, bracer and arm exactly as that view places it, with a 5 cm ruler from the trigger (the origin): red down, blue back
		view = Node3D.new()
		var hand: Node3D = (load(Ep2Extras.GUN_HAND) as PackedScene).instantiate()
		hand.rotation.y = Ep2RemingtonView.FOUNDER_TURN
		hand.position = Ep2RemingtonView.FOUNDER_OFFSET
		view.add_child(hand)
		for i in 10:
			for axis in 2:
				var dot := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3.ONE * (0.012 if i > 0 else 0.02)
				dot.mesh = box
				var m := StandardMaterial3D.new()
				m.albedo_color = Color.RED if axis == 0 else Color.BLUE
				m.no_depth_test = true
				dot.material_override = m
				dot.position = (Vector3.DOWN if axis == 0 else Vector3.BACK * -1.0) * 0.05 * float(i)
				view.add_child(dot)
	elif _id == "pick_model":
		# the war pick as the counter's case shows it, laid along the card for its Tabs tile
		view = Node3D.new()
		var pick: Node3D = (load(Ep2Viewmodel.PICK_HELD_MODEL) as PackedScene).instantiate()
		pick.position = Vector3(0.0, -0.45, 0.0)
		var turned := Node3D.new()
		turned.rotation = Vector3(0.0, -PI * 0.5, -0.62)
		turned.add_child(pick)
		view.add_child(turned)
		view.rotation.x = 1.3
	elif _id == Ep2ArmoryState.PICK:
		var vm := Ep2Viewmodel.new()
		vp.add_child(vm)
		view = vm._make_pickaxe_view()
	else:
		view = Ep2ArmoryGunView.make(_id)
	vp.add_child(view)
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	cam.current = true
	if _icon != "":
		vp.size = Vector2i(640, 320)
		vp.transparent_bg = true
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_energy = 0.85
		sun.rotation = Vector3(-0.7, PI * 0.5 - 0.5, 0.0)
		for sleeve in view.find_children("ArmSleeve", "MeshInstance3D", true, false):
			(sleeve as Node3D).visible = false
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 0.64 if _id != "pick_model" else 0.72
		var aim: Vector3 = Vector3(0.0, -0.075, 0.145) if _id != "pick_model" else Vector3.ZERO
		cam.position = aim + Vector3(2.0, 0.0, 0.0)
		cam.look_at(aim, Vector3.UP)
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(_icon)
		print("HELD_VIEW_PROBE icon ", _icon)
		get_tree().quit()
		return
	var centre := Vector3(0.0, -0.1, 0.05)
	for shot in [["behind", Vector3(-0.25, 0.25, -1.0)], ["left", Vector3(1.0, 0.1, 0.0)], ["right", Vector3(-1.0, 0.1, 0.0)], ["below", Vector3(0.2, -1.0, -0.3)], ["front", Vector3(0.3, 0.2, 1.0)]]:
		cam.position = centre + (shot[1] as Vector3).normalized() * _dist
		cam.look_at(centre, Vector3.UP)
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _id, shot[0]])
	print("HELD_VIEW_PROBE done ", _id)
	get_tree().quit()
