extends Node
## Founder follow-ups 2026-11-02 seen in the real renderer: the stranger's Borchardt (holster, in his fist, in the dirt), the founder's plants
## in Dude's patch, and the vultures at a carcass.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/followups_1102_shot.tscn

var out: String = ""
var cam: Camera3D = null


func _shot(name: String, eye: Vector3, at: Vector3) -> void:
	cam.position = eye
	cam.look_at(at)
	for i in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("FOLLOWUP_SHOT ", name)


func _ready() -> void:
	out = OS.get_environment("OUT")
	if out == "":
		out = "user://followups"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.8, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 0.97, 0.9)
	e.ambient_light_energy = 0.55
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.62, 0.45, 0.28)
	ground.material_override = dirt
	world.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	cam.current = true

	# the stranger, seated the way gold_town seats him
	var opp := Ep2TownFolk.new()
	world.add_child(opp)
	opp.setup(GoldTownChamber.COWBOY_MODEL, GoldTownChamber.COWBOY_HEIGHT, Color(0.2, 0.17, 0.15), false)
	var holder := Node3D.new()
	opp.add_child(holder)
	holder.add_child((load(Ep2Extras.BORCHARDT_GUN) as PackedScene).instantiate())
	holder.position = GoldTownChamber.OPP_HOLSTER
	holder.rotation = GoldTownChamber.OPP_HOLSTER_ROT
	opp.set_pose("idle")
	await _shot("holstered", Vector3(-1.6, 1.3, 1.9), Vector3(-0.1, 1.0, 0.0))
	opp.set_pose("draw")
	holder.position = GoldTownChamber.opp_gun_in_hand()
	holder.rotation = Vector3.ZERO
	await _shot("drawn_side", Vector3(-2.3, 1.5, 0.75), Vector3(-0.15, 1.3, 0.4))
	await _shot("drawn_front", Vector3(0.9, 1.5, 3.0), Vector3(-0.1, 1.25, 0.3))
	await _shot("drawn_close", Vector3(-0.85, 1.55, 1.05), Vector3(-0.22, 1.36, 0.62))
	holder.position = Vector3(-0.42, 0.045, 0.38)
	holder.rotation = Vector3(0.0, 0.9, PI * 0.5)
	opp.fall_dead()
	for i in 30:
		opp.step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot("dropped", Vector3(-1.3, 0.8, 1.5), Vector3(-0.42, 0.05, 0.38))
	opp.queue_free()

	# the patch
	var patch: Node3D = Ep2BudPatch.build(world)
	patch.position = Vector3.ZERO
	while not Ep2BudPatch.upgrade_step(patch):
		pass
	await get_tree().process_frame
	await _shot("patch_near", Vector3(1.0, 1.55, 5.2), Vector3(-0.1, 1.2, -0.6))
	await _shot("patch_far", Vector3(5.5, 1.7, 15.0), Vector3(0.0, 1.9, -1.5))
	await _shot("patch_bed", Vector3(0.4, 1.3, 2.6), Vector3(0.0, 0.5, 0.0))
	patch.queue_free()
	await get_tree().process_frame

	# the birds
	var bison: Node3D = (load(Ep2Stampede.MODEL) as PackedScene).instantiate() as Node3D
	world.add_child(bison)
	bison.rotation.x = PI * 0.5
	var birds := Ep2CarrionVultures.new()
	world.add_child(birds)
	birds.add_body(Vector3.ZERO, 1.7)
	for i in int(41.0 * 10.0 + 40.0):
		birds.step(0.1, Vector3(200, 0, 0))
		if birds.feeders() > 0 and float(birds.birds[0]["t"]) > 4.0 and str(birds.birds[0]["state"]) == "descend":
			break
	await _shot("birds_down", Vector3(16, 3.0, 22), Vector3(0, 7.0, 0))
	for i in 80:
		birds.step(0.1, Vector3(200, 0, 0))
	await _shot("birds_feed", Vector3(4.5, 1.7, 6.5), Vector3(0, 0.5, 0))
	print("FOLLOWUP_SHOTS_DONE")
	get_tree().quit()
