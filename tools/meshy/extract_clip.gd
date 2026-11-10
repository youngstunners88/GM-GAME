extends SceneTree
## Pull ONE clip out of a Meshy animate GLB (which carries the whole 12 MB mesh) into a small Animation resource that plays on the
## shipped townsfolk body of the same rig. Meshy's raw rig is in centimetres (armature_scale 0.01 baked into our shipped GLBs), so the
## hips position track is rescaled by the ratio of the two skeletons' hips rest heights; track paths are re-pointed at the shipped
## Skeleton3D. Usage:
##   godot --headless --path . -s res://tools/meshy/extract_clip.gd -- <meshy.glb> <shipped body res path> <out .res> <clip name>
func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(a[0], st) != OK:
		push_error("cannot read " + a[0]); quit(1); return
	var src: Node = doc.generate_scene(st)
	var body: Node = (load(a[1]) as PackedScene).instantiate()
	var sap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var bap: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var bsk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var names: PackedStringArray = sap.get_animation_list()
	print("source clips: ", names)
	var anim: Animation = sap.get_animation(names[names.size() - 1]).duplicate(true)
	var skel_path: String = str(bap.get_node(bap.root_node).get_path_to(bsk))
	var hs: int = ssk.find_bone("Hips")
	var hb: int = bsk.find_bone("Hips")
	var scale: float = bsk.get_bone_rest(hb).origin.length() / maxf(ssk.get_bone_rest(hs).origin.length(), 1e-6)
	print("hips rest: src %.4f body %.4f scale %.5f" % [ssk.get_bone_rest(hs).origin.length(), bsk.get_bone_rest(hb).origin.length(), scale])
	var missing := 0
	for t in range(anim.get_track_count() - 1, -1, -1):
		var p: NodePath = anim.track_get_path(t)
		var bone: String = str(p.get_concatenated_subnames())
		if bsk.find_bone(bone) < 0:
			anim.remove_track(t); missing += 1; continue
		anim.track_set_path(t, NodePath(skel_path + ":" + bone))
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			for k in anim.track_get_key_count(t):
				anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) * scale)
	anim.resource_name = a[3]
	anim.loop_mode = Animation.LOOP_LINEAR
	print("tracks %d (dropped %d), length %.2f s" % [anim.get_track_count(), missing, anim.length])
	var err := ResourceSaver.save(anim, a[2], ResourceSaver.FLAG_COMPRESS)
	print("saved ", a[2], " err ", err)
	src.free(); body.free()
	quit(0 if err == OK else 1)
