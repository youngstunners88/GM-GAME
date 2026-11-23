extends SceneTree
## Measures the Inferno Bull GLB's left (and right) palm in its hand bone's frame, in metres of the native 2.4 m model - the frame
## Ep2BullHero.hand_point_world() reads (LEFT_PALM_M / RIGHT_PALM_M). Centroid of the skinned vertices bound mostly to that hand.
##   godot --headless --path . --script res://tools/ep2_shots/bull_palm_probe.gd

func _init() -> void:
	var scene: Node3D = (load(OS.get_environment("BULL_GLB") if OS.get_environment("BULL_GLB") != "" else "res://src/episode2/assets/inferno_bull_rigged.glb") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var top: float = -INF
	for side in ["LeftHand", "RightHand"]:
		var hb: int = sk.find_bone(side)
		var hw: Transform3D = sk.global_transform * sk.get_bone_global_rest(hb)
		var sum := Vector3.ZERO
		var n: int = 0
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.skin == null:
				continue
			var bind_bone: Dictionary = {}
			for bi in m.skin.get_bind_count():
				bind_bone[bi] = m.skin.get_bind_bone(bi) if m.skin.get_bind_bone(bi) >= 0 else sk.find_bone(m.skin.get_bind_name(bi))
			for si in m.mesh.get_surface_count():
				var arr: Array = m.mesh.surface_get_arrays(si)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
				var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
				var per: int = bones.size() / v.size()
				for i in v.size():
					var p: Vector3 = m.global_transform * v[i]
					top = maxf(top, p.y)
					var wt: float = 0.0
					for k in per:
						if bind_bone.get(bones[i * per + k], -1) == hb:
							wt += w[i * per + k]
					if wt > 0.6:
						# bind pose = mesh space -> this bone's frame in skeleton units (rig cm): / 100 = metres of the 2.4 m model
						var bi: int = bind_bone.find_key(hb)
						var lb: Vector3 = m.skin.get_bind_pose(bi) * v[i]
						var l: Vector3 = lb / 100.0
						sum += l
						n += 1
						lo = lo.min(l)
						hi = hi.max(l)
		var c: Vector3 = sum / maxf(n, 1)
		print("PALM %s n=%d centroid %s box %s..%s wrist(world) %s" % [side, n, c, lo, hi, hw.origin])
	print("PALM model top %.3f" % top)
	quit()
