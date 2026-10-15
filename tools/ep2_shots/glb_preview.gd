extends Node
## Render a GLB (loaded at runtime, no import) from 4 angles: front, side, back, 3/4 -> out/<name>_<view>.png
##   xvfb-run -a godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 900x900 --path . res://tools/ep2_shots/glb_preview.tscn -- glb=/abs/path.glb out=.farm/prev/name
func _ready() -> void:
	var glb := ""
	var out := ".farm/prev/x"
	var hide := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("glb="): glb = a.substr(4)
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("hide="): hide = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(glb, st) != OK:
		print("LOAD FAIL"); get_tree().quit(); return
	var root: Node3D = doc.generate_scene(st) as Node3D
	add_child(root)
	if hide != "":
		for mi in root.find_children(hide + "*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).visible = false
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.8, 0.8, 0.8); env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); add_child(sun)
	var aabb := AABB(); var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null: continue
		var b: AABB = m.global_transform * m.get_aabb()
		aabb = b if first else aabb.merge(b); first = false
	print("AABB ", aabb)
	var c := aabb.get_center(); var r := aabb.size.length() * 0.9
	var cam := Camera3D.new(); cam.fov = 40; add_child(cam); cam.current = true
	var names := ["front", "side", "back", "q34"]
	var yaws := [0.0, 90.0, 180.0, 40.0]
	for i in 4:
		var y: float = deg_to_rad(yaws[i])
		cam.position = c + Vector3(sin(y) * r, aabb.size.y * 0.1, cos(y) * r)
		cam.look_at(c, Vector3.UP)
		for k in 3: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, names[i]])
	get_tree().quit()
