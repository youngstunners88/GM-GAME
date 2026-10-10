extends Node
## WINCHESTER LOGO / RECEIVER CAPTURE (skill ep2-winchester-logo): the founder's rifle exactly as the shipped viewmodel holds it
## (Ep2Viewmodel hip pose on a camera, warm forge light like the hideout range) plus close-ups of the receiver side plate and the
## top strap, so the ring around the GM disc and any hole on top are MEASURED on the game's own render, not guessed.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x800 \
##       res://tools/ep2_shots/rifle_vm_shot.tscn -- out=.farm/rifle_vm/now
## Writes <out>_hip.png (what the player sees), <out>_side.png (receiver plate square-on), <out>_top.png (top strap from above),
## <out>_top3q.png (top strap, shooter's side, from above), <out>_side_wide.png.
## `glb=<file.glb>` swaps a candidate rifle (loaded at run time with GLTFDocument, no import) into the shipped pose, same frame.

var _out := ".farm/rifle_vm/now"
var _glb := ""
var _badge_local := Vector3.INF          # `badge=x,y,z` (model frame) frames a model that has no Badge_Face (the no-logo control build)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
		elif kv.size() == 2 and kv[0] == "glb":
			_glb = kv[1]
		elif kv.size() == 2 and kv[0] == "badge":
			var p: PackedStringArray = kv[1].split(",")
			_badge_local = Vector3(float(p[0]), float(p[1]), float(p[2]))
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var world := Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.35, 0.22, 0.12)
	psm.sky_horizon_color = Color(0.55, 0.36, 0.2)
	psm.ground_bottom_color = Color(0.12, 0.08, 0.05)
	psm.ground_horizon_color = Color(0.45, 0.3, 0.16)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.78, 0.5)
	key.light_energy = 1.4
	key.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.6, 0.3)
	fill.light_energy = 2.0
	fill.omni_range = 6.0
	fill.position = Vector3(1.2, 0.6, -0.6)
	world.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 75.0
	world.add_child(cam)
	cam.make_current()
	var vm := Ep2Viewmodel.new()
	add_child(vm)
	vm.attach(cam)
	if _glb != "":
		var old: Node3D = vm.rifle.get_node("Hands/HandsModel") as Node3D
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(_glb) if _glb.begins_with("res://") else _glb, st) != OK:
			push_error("cannot load " + _glb)
			get_tree().quit(1)
			return
		var cand: Node3D = doc.generate_scene(st) as Node3D
		old.get_parent().add_child(cand)
		cand.transform = old.transform
		old.name = "OldModel"
		old.get_parent().remove_child(old)
		old.queue_free()
		cand.name = "HandsModel"
	for i in 30:
		vm.step(1.0 / 60.0, false, false, 0.0)
		await get_tree().process_frame
	await _grab("_hip")
	# close-ups: detach the rifle model into the world frame and orbit its receiver
	var model: Node3D = vm.rifle.get_node_or_null("Hands/HandsModel") as Node3D
	if model == null:
		push_error("no founder rifle model")
		get_tree().quit(1)
		return
	vm.rifle.reparent(world)                       # keep its pose, but stop it riding on the camera
	vm.set_process(false)
	var aabb := _bounds(model)
	var c: Vector3 = aabb.get_center()
	# the receiver sits about 30 % from the stock end; find it as the widest point of the top silhouette: use the GM disc instead
	var badge := _badge_center(model)
	if badge != Vector3.INF:
		c = badge
	elif _badge_local != Vector3.INF:
		c = model.global_transform * _badge_local
	print("badge_local ", model.global_transform.affine_inverse() * c)
	var gt: Transform3D = model.global_transform
	var right: Vector3 = gt.basis.x.normalized()
	var up: Vector3 = gt.basis.y.normalized()
	var fwd: Vector3 = gt.basis.z.normalized()
	# the shooter's side = the side of the rifle the hip camera looked at
	var side_sign: float = 1.0 if right.dot(cam.global_position - c) > 0.0 else -1.0
	var shots := {
		"_side": [c + right * 0.35 * side_sign, c, up],
		"_top": [c + up * 0.35, c, fwd],
		"_top3q": [c + up * 0.28 + right * 0.18 * side_sign - fwd * 0.12, c + up * 0.04, up],
		"_side_wide": [c + right * 0.75 * side_sign, c, up],
	}
	for k in shots:
		var s: Array = shots[k]
		cam.global_position = s[0]
		cam.look_at(s[1], s[2])
		cam.fov = 40.0
		await _grab(k)
	get_tree().quit(0)


func _grab(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out + suffix + ".png")
	print("saved ", _out + suffix + ".png")


func _bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## World position of the centre of the GM disc (the surface whose material is named Badge_Face / carries the emblem texture).
func _badge_center(n: Node) -> Vector3:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(i)
			if mat != null and String(mat.resource_name).begins_with("Badge_Face"):
				var arr: Array = m.mesh.surface_get_arrays(i)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var s := Vector3.ZERO
				for v in verts:
					s += v
				return m.global_transform * (s / max(1, verts.size()))
	return Vector3.INF
