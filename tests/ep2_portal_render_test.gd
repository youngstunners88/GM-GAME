extends SceneTree
## GPU oracle for the shipped Compatibility shader, also run as an external web fixture.
## Green opaque foreground lies BEHIND the portal plane but must remain visible;
## a red old-world background must be replaced by the blue destination image.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(640,360)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	camera.near = 0.05
	var background := MeshInstance3D.new()
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(12,8)
	background.mesh = background_mesh
	background.position.z = -3
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color.RED
	background.material_override = red
	scene.add_child(background)
	var foreground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.2,.2,.2)
	foreground.mesh = box
	foreground.position = Vector3(.2,0,-.8)
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color.GREEN
	foreground.material_override = green
	scene.add_child(foreground)
	var portal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.3,4.4)
	portal.mesh = quad
	portal.position.z = -.22
	var material := ShaderMaterial.new()
	material.shader = load("res://src/episode2/art/ep2_portal.gdshader")
	var blue := Image.create(4,4,false,Image.FORMAT_RGBA8)
	blue.fill(Color.BLUE)
	material.set_shader_parameter("portal_tex",ImageTexture.create_from_image(blue))
	material.set_shader_parameter("gain",1.0)
	material.set_shader_parameter("viewmodel_depth",1.6)
	portal.material_override = material
	scene.add_child(portal)
	for i in 6: await RenderingServer.frame_post_draw
	var frame: Image = vp.get_texture().get_image()
	var p: Vector2 = camera.unproject_position(foreground.position)
	var fg: Color = frame.get_pixel(int(p.x),int(p.y))
	var bg: Color = frame.get_pixel(100,180)
	var foreground_ok: bool = fg.g > .7 and fg.r < .2 and fg.b < .2
	var background_ok: bool = bg.b > .7 and bg.r < .2 and bg.g < .2
	print("[PASS] portal preserves opaque foreground self-depth" if foreground_ok else "[FAIL] portal paints over the opaque foreground: " + str(fg))
	print("[PASS] portal replaces the old wall at the near clip" if background_ok else "[FAIL] portal exposes the old wall: " + str(bg))
	var failed: int = int(not foreground_ok)+int(not background_ok)
	print("EP2_PORTAL_RENDER: 2 checks, %d failed" % failed)
	if not OS.has_feature("web"): quit(failed)
