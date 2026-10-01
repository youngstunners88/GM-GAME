extends SceneTree
## Print what a GLB really contains once Godot imports it: clips, track paths, bones, world AABB per mesh.
##   godot --headless -s tools/ep2_shots/glb_probe.gd -- res://path/a.glb res://path/b.glb

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var ps: PackedScene = load(path)
		if ps == null:
			print("PROBE ", path, " FAILED TO LOAD")
			continue
		var n: Node3D = ps.instantiate()
		root.add_child(n)
		print("PROBE ", path)
		for ap in n.find_children("*", "AnimationPlayer", true, false):
			var p: AnimationPlayer = ap
			print("  player ", n.get_path_to(p), " root_node=", p.root_node)
			for an in p.get_animation_list():
				var a: Animation = p.get_animation(an)
				print("    clip ", an, " len=%.2f loop=%d tracks=%d first=%s" % [a.length, a.loop_mode, a.get_track_count(), str(a.track_get_path(0)) if a.get_track_count() > 0 else "-"])
		for sk in n.find_children("*", "Skeleton3D", true, false):
			print("  skeleton ", n.get_path_to(sk), " bones=", (sk as Skeleton3D).get_bone_count(), " scale=", (sk as Node3D).global_transform.basis.get_scale())
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := -lo
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			lo = lo.min(ab.position)
			hi = hi.max(ab.end)
			print("  mesh ", n.get_path_to(mi), " aabb=", ab)
		print("  TOTAL lo=", lo, " hi=", hi, " size=", hi - lo)
		n.queue_free()
	quit()
