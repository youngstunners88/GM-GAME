extends Node
## POST-FILM capture (skill ep2-bull-props-visible): the exact state the founder sees when his film ends, first
## person at the mold rack, with Inferno Bull at rest. Saves the default view and a look at the Bull, and prints
## for his rifle and his whiskey glass: visible, inside the camera frustum, and the size on screen in pixels.
##   xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 960x540 res://tools/ep2_shots/bull_props_shot.tscn -- out=<dir>

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _out := ".farm/bullprops"
var f: Node = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	f = SMELT.instantiate()
	f.intro_film = false
	add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	await get_tree().process_frame
	f._on_video_film_finished()
	_run(1.5)
	await _cap("bp0_after_film")
	f.aim_at(f._bull.global_position + Vector3(0.0, 1.5, 0.0))
	_run(0.5)
	await _cap("bp1_look_at_bull")
	f.aim_at(f._bull.global_position + Vector3(0.0, 1.5, 0.0))
	f._look_yaw += 0.12
	_run(0.5)
	await _cap("bp2_bull_offcentre")
	# From his other side: he must turn to Lil Blunt, and the props must still read.
	f._player_pos = Vector3(4.6, 0.0, 8.4)
	_run(2.5)
	f.aim_at(f._bull.global_position + Vector3(0.0, 1.5, 0.0))
	_run(0.3)
	await _cap("bp3_other_side")
	print("BULL facing=%.2f yaw_to_hero=%.2f" % [f._bull.facing,
		atan2(f._player_pos.x - f._bull.position.x, f._player_pos.z - f._bull.position.z)])
	get_tree().quit()


func _run(sec: float) -> void:
	for i in int(sec * 60.0):
		f.step(1.0 / 60.0)


func _cap(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name, " yaw=%.2f" % f.get_look_yaw())
	_report("glass", f._glass_node)
	_report("bull_rifle", f._bull_guard_rifle)


## Visible in tree, inside the frustum, and the projected screen size of the prop's mesh AABB.
func _report(label: String, n: Node3D) -> void:
	if n == null or not is_instance_valid(n):
		print("  ", label, " MISSING")
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var in_front := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = m.get_aabb()
		for k in 8:
			var wp: Vector3 = m.global_transform * bb.get_endpoint(k)
			if cam.is_position_behind(wp):
				continue
			in_front += 1
			var sp: Vector2 = cam.unproject_position(wp)
			lo = lo.min(sp)
			hi = hi.max(sp)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var on := lo.x < vp.x and lo.y < vp.y and hi.x > 0.0 and hi.y > 0.0 and in_front > 0
	var size: Vector2 = (hi.min(vp) - lo.max(Vector2.ZERO)) if on else Vector2.ZERO
	print("  %s visible=%s on_screen=%s px=%dx%d pos=%s parent=%s" % [label, n.is_visible_in_tree(), on,
		int(size.x), int(size.y), n.global_position, n.get_parent().name])
