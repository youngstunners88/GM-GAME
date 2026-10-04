extends Node
## Render the runner's archer-bear GLB to a flat transparent PNG so the range can show it as a "wanted poster"
## target plaque matching the four protocol logos (founder 2026-10-04 round 2: "one of the targets must be a bear",
## shown in the reference as a bullet-scarred wall poster, not a 3D standing bear). Skill ep2-range-lesson.
##   xvfb-run ... godot --rendering-driver opengl3 --rendering-method gl_compatibility res://tools/ep2_shots/render_bear_poster.tscn -- out=<file.png>

const BEAR := "res://src/episode2/assets/mine_bear_archer.glb"

func _ready() -> void:
	var out := "src/episode2/assets/textures/logos/logo_bear.png"
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bear: Node3D = (load(BEAR) as PackedScene).instantiate()
	vp.add_child(bear)
	# measure the bear's AABB to frame it
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for mi in bear.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		lo = lo.min(ab.position)
		hi = hi.max(ab.end)
	var centre: Vector3 = (lo + hi) * 0.5
	var radius: float = (hi - lo).length() * 0.5
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = centre + Vector3(0.0, 0.0, radius * 2.3)
	cam.look_at(centre, Vector3.UP)
	cam.fov = 45.0
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(30.0), 0.0)
	key.light_energy = 1.4
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(-120.0), 0.0)
	fill.light_energy = 0.5
	fill.light_color = Color(1.0, 0.8, 0.6)
	vp.add_child(fill)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(ProjectSettings.globalize_path(out) if not out.begins_with("res://") else out)
	print("BEAR POSTER ", out, " aabb_size=", hi - lo)
	get_tree().quit()
