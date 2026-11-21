extends SceneTree
## Proof for an animation-import change (compression): sample every clip of each model at 12 moments and write every bone's
## model-space position. Run before and after, then compare with --compare: the largest bone drift in metres is the answer.
##   godot --headless --path . --script tools/ep2_forge/anim_pose_probe.gd -- out.json res://a.glb res://b.glb
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: Dictionary = {}
	for i in range(1, args.size()):
		var scene: Node = (load(args[i]) as PackedScene).instantiate()
		root.add_child(scene)
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var m: Dictionary = {}
		for clip in ap.get_animation_list():
			var rows: Array = []
			var length: float = ap.get_animation(clip).length
			ap.play(clip)
			var n: int = int(OS.get_environment("PROBE_N")) if OS.has_environment("PROBE_N") else 12
			for k in n:
				ap.seek(length * (k + 0.5) / float(n), true)
				sk.force_update_all_bone_transforms()
				var row: Array = []
				for b in sk.get_bone_count():
					var o: Vector3 = sk.get_bone_global_pose(b).origin * sk.global_basis.get_scale().y
					row.append([o.x, o.y, o.z])
				rows.append(row)
			m[clip] = rows
		out[args[i]] = m
		scene.free()
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()
