extends Node
## Weapon consistency (founder 2026-11-05): the Golden Remington, the Borchardt and the Sharps in Lil Blunt's hands through the REAL Ep2Viewmodel,
## same camera, fov and clear colour, at the hip and aimed, on a flat key colour so tools/ep2_shots/weapon_consistency_measure.py can read the silhouettes.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/weapon_consistency_shot.tscn
## Renders in a SubViewport, because the window manager overrides the window size.

const SIZE := Vector2i(1280, 720)
const KEY := Color(1.0, 0.0, 1.0)
## The normal aimed fov: the frame every gun is compared in, whatever its own aimed zoom.
const FOV := 58.0
const MUZZLE_REM := Vector3(0.0, 0.0, 0.343)


func _ready() -> void:
	var out: String = OS.get_environment("OUT")
	if out == "":
		out = "user://weapon_consistency"
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = KEY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.7
	world.environment = env
	vp.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.current = true
	vp.add_child(cam)
	var armory: Ep2ArmoryState = Ep2ArmoryState.post_hideout()
	armory.acquire(Ep2ArmoryState.REM)
	armory.acquire(Ep2ArmoryState.BORCH)
	armory.acquire(Ep2ArmoryState.BUFF)
	var vm := Ep2Viewmodel.new()
	vp.add_child(vm)
	vm.bind_armory(armory)
	vm.attach(cam)
	for id in [Ep2ArmoryState.REM, Ep2ArmoryState.BORCH, Ep2ArmoryState.BUFF]:
		armory.select(id)
		for aimed in [false, true]:
			vm.set_aim(aimed)
			for i in 90:
				vm.step(1.0 / 60.0, false, false, 0.0)
			cam.fov = FOV
			for i in 4:
				await RenderingServer.frame_post_draw
			var view: Node3D = vm.rifle
			var name_tail: String = ("ads-" if aimed else "hip-") + id
			vp.get_texture().get_image().save_png(out + "/" + name_tail + ".png")
			# the gun alone (a view whose arms are separate nodes): the measure needs no colour guess
			var hands: Node3D = view.get_node_or_null("Hands") as Node3D
			var whole: Node3D = view.get_node_or_null("FounderRevolver") as Node3D
			var gun_only: Node3D = null
			if whole != null:
				# the Remington's gun and hand are one mesh: its gun-only model, in the same frame, gives the same measure as the others
				gun_only = Ep2RemingtonView.make_held()
				view.add_child(gun_only)
				whole.visible = false
			elif hands != null:
				hands.visible = false
			if whole != null or hands != null:
				for i in 4:
					await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(out + "/" + name_tail + "-gun.png")
			if gun_only != null:
				gun_only.free()
				whole.visible = true
			elif hands != null:
				hands.visible = true
			print("CONSISTENCY_SHOT ", name_tail, " pos ", view.position, " rot ", view.rotation, " muzzle_px ", cam.unproject_position(view.global_transform * Vector3(view.get_meta("muzzle", MUZZLE_REM))))
		vm.set_aim(false)
	print("CONSISTENCY_SHOTS_DONE")
	get_tree().quit()
