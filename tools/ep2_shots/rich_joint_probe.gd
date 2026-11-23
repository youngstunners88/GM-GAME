extends SceneTree
## Finds the tip of the joint modelled into Rich's mouth (rich_armory2.glb) in the MESH's own vertex space (what Ep2RichJoint.TIP_MESH
## needs): among the Head-bound vertices at mouth height (1.47 - 1.56 m), the farthest forward (+Z: the model faces +Z).
##   godot --headless --path . --script res://tools/ep2_shots/rich_joint_probe.gd

func _init() -> void:
	var scene: Node3D = (load(Ep2Extras.RICH) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var head: int = -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("Head"):
			head = i
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		var bind := -1
		for bi in m.skin.get_bind_count():
			var b: int = m.skin.get_bind_bone(bi) if m.skin.get_bind_bone(bi) >= 0 else sk.find_bone(m.skin.get_bind_name(bi))
			if b == head:
				bind = bi
		var arr: Array = m.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / v.size()
		var best: float = -1.0
		var best_v := Vector3.ZERO
		var best_l := Vector3.ZERO
		for i in v.size():
			var wt: float = 0.0
			for k in per:
				if bones[i * per + k] == bind:
					wt += w[i * per + k]
			if wt < 0.5 and OS.get_environment("ANYBONE") == "":
				continue
			var l: Vector3 = m.skin.get_bind_pose(bind) * v[i]          # head-bone frame, skeleton units
			# the model faces +Z: at mouth height (1.47 - 1.56 m) the joint is the farthest-forward point
			var flat_d: float = Vector2(v[i].x + 0.03, v[i].z).length()
			if v[i].y > 1.47 and v[i].y < 1.56 and flat_d > best:
				best = flat_d
				best_v = v[i]
				best_l = l
		print("RICHTIP mesh %s bone-local %s flat %.4f head weight-bind %d" % [best_v, best_l, best, bind])
	quit()
