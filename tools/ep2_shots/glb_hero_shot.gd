extends Node
## ENGINE CAPTURE of a GLB on a neutral studio backdrop from a reference-matched camera (skill ep2-hyperreal-scene-pipeline, step 5/6):
## the picture that goes on a board next to the Muapi reference and into tools/ep2_forge/ref_metrics.py.
##   xvfb-run -a -s "-screen 0 1200x900x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1200x900 \
##       res://tools/ep2_shots/glb_hero_shot.tscn -- glb=res://src/episode2/assets/vehicles/flame_quad.glb out=.farm/quad/engine \
##       views=hero:-3.9,1.9,4.0:0.1,0.8,0.1:42;side:-9,0.85,0:0,0.85,0:30 [studio=1]
## `views` = name:camera x,y,z:target x,y,z:fov joined by ';' (GLB frame: +Z nose, +Y up).
## `studio=1` swaps the woods sky/ground for the plain mid-grey seamless backdrop the Muapi object references use, so
## tools/ep2_forge/ref_metrics.py compares the SUBJECT (a woods backdrop alone drives saturation/warmth off by 3x).
## `glb=/abs/or/relative/file.glb` (not res://) is loaded AT RUN TIME with GLTFDocument - no import, no project files: for AI-generated candidates in .farm/.
## `spin=DEG` turns every Wheel_XX node (one underscore) by DEG about its axle (X) - proves the wheels were cut cleanly (no body bits riding along).
## `auto=1` ignores `views` and orbits the model's own bounds: px / nx / pz / nz / top / q3 (unknown orientation, unknown scale), the model dropped on the ground.
func _ready() -> void:
	var glb := ""
	var out := ".farm/glb_hero"
	var views := "hero:-3.9,1.9,4.0:0.1,0.8,0.1:42"
	var studio := false
	var auto := false
	var spin := 0.0
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"glb": glb = kv[1]
			"out": out = kv[1]
			"views": views = kv[1]
			"studio": studio = kv[1] == "1"
			"auto": auto = kv[1] == "1"
			"spin": spin = float(kv[1])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var vp := SubViewport.new()
	vp.size = Vector2i(get_viewport().get_visible_rect().size)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	# the SAME sky + ambient + grade as the bear woods (woods_quad.gd _apply_light), so metals reflect a real sky (a sky-less room renders chrome black)
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.20, 0.34, 0.52)
	psm.sky_horizon_color = Color(0.92, 0.62, 0.38)
	psm.ground_horizon_color = Color(0.45, 0.36, 0.28)
	psm.ground_bottom_color = Color(0.14, 0.16, 0.12)
	psm.sun_angle_max = 25.0
	if studio:
		# grey seamless: a soft gradient the chrome can still reflect, no coloured horizon
		psm.sky_top_color = Color(0.58, 0.58, 0.60)
		psm.sky_horizon_color = Color(0.66, 0.66, 0.67)
		psm.ground_horizon_color = Color(0.60, 0.60, 0.61)
		psm.ground_bottom_color = Color(0.46, 0.46, 0.47)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.58, 0.60) if studio else Color(0.46, 0.52, 0.56)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = not studio
	env.fog_light_color = Color(0.58, 0.55, 0.50)
	env.fog_density = 0.011
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.88) if studio else Color(1.0, 0.78, 0.55)
	sun.light_energy = 1.15 if studio else 1.35
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40.0, 40.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.50, 0.50, 0.52) if studio else Color(0.38, 0.42, 0.25)
	gm.roughness = 0.95
	ground.material_override = gm
	vp.add_child(ground)
	var model: Node3D = null
	if glb.begins_with("res://"):
		model = (load(glb) as PackedScene).instantiate() as Node3D
	else:
		var gdoc := GLTFDocument.new()
		var gstate := GLTFState.new()
		var err: int = gdoc.append_from_file(ProjectSettings.globalize_path(glb) if glb.begins_with("res") else glb, gstate)
		if err != OK:
			printerr("GLB load failed: ", glb, " err ", err)
			get_tree().quit(1)
			return
		model = gdoc.generate_scene(gstate) as Node3D
	vp.add_child(model)
	if spin != 0.0:
		for wn in model.find_children("Wheel_*", "Node3D", true, false):
			if String(wn.name).count("_") == 1:
				(wn as Node3D).rotation_degrees.x = spin
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	await get_tree().process_frame
	if auto:
		var box := _bounds(model)
		model.position.y -= box.position.y                      # stand it on the ground
		box.position.y = 0.0
		var c: Vector3 = box.get_center()
		var r: float = maxf(box.size.length() * 0.5, 0.2)
		var dist: float = r * 2.6
		var dirs := {"px": Vector3(1, 0.18, 0), "nx": Vector3(-1, 0.18, 0), "pz": Vector3(0, 0.18, 1), "nz": Vector3(0, 0.18, -1), "top": Vector3(0.01, 1, 0.01), "q3": Vector3(1, 0.5, 1)}
		var vs: PackedStringArray = []
		for k in dirs:
			var d: Vector3 = (dirs[k] as Vector3).normalized() * dist + c
			vs.append("%s:%f,%f,%f:%f,%f,%f:34" % [k, d.x, d.y, d.z, c.x, c.y, c.z])
		print("BOUNDS size ", box.size, " centre ", c)
		views = ";".join(vs)
	for v in views.split(";"):
		var parts: PackedStringArray = v.split(":")
		var p: PackedStringArray = parts[1].split(",")
		var t: PackedStringArray = parts[2].split(",")
		cam.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.fov = float(parts[3])
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "%s_%s.png" % [out, parts[0]]
		vp.get_texture().get_image().save_png(path)
		print("SHOT ", path)
	get_tree().quit()


## World-space bounds of every mesh under `n` (the model, wherever its authoring tool put the origin).
func _bounds(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
