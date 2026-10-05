extends Node
## Renders a GLB from the side (+X looking -X: muzzle +Z should be on the LEFT of the picture? we print and judge) and from above.
##   xvfb-run -a godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 800x400 res://tools/ep2_shots/glb_axes_shot.tscn -- glb=/tmp/x.glb out=/tmp/axes
func _ready() -> void:
	var glb := ""; var out := "/tmp/axes"
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv[0] == "glb": glb = kv[1]
		if kv[0] == "out": out = kv[1]
	var gltf := GLTFDocument.new(); var st := GLTFState.new()
	gltf.append_from_file(glb, st)
	var root: Node = gltf.generate_scene(st)
	var vp := SubViewport.new(); vp.size = Vector2i(800, 400); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp); vp.add_child(root)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 30, 0); vp.add_child(l)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6,0.6,0.6); vp.add_child(env)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.6; vp.add_child(cam)
	for view in [["side", Vector3(3,0,0), Vector3.UP], ["top", Vector3(0,3,0.001), Vector3.FORWARD]]:
		cam.position = view[1]; cam.look_at(Vector3.ZERO, view[2])
		await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s_%s.png" % [out, view[0]])
	get_tree().quit()
