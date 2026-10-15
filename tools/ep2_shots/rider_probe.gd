extends Node
## Prints where the Bull's hips / feet / head sit (actor-local, metres) in his riding clips, so a vehicle seat can be calibrated
## (skill ep2-hyperreal-scene-pipeline, woods quad seat). godot --headless res://tools/ep2_shots/rider_probe.tscn
func _ready() -> void:
	var b := Ep2Actor.new()
	add_child(b)
	var ok: bool = b.setup(SmeltingFacilityChamber.BULL_RIG_MODEL, SmeltingFacilityChamber.BULL_RIG_H, SmeltingFacilityChamber.BULL_HEIGHT,
		{"walk": SmeltingFacilityChamber.BULL_WALK_CLIP}, ["Idle_02"])
	print("RIDER setup ok ", ok)
	b.add_all_clips(SmeltingFacilityChamber.BULL_SIT_CLIPS)
	for clip in ["Chair_Sit_Idle_M", "Sit_and_Drink", "Idle_02"]:
		b.play(clip, 1.0, 0.0)
		b.anim.advance(float(OS.get_environment("CLIP_T") if OS.get_environment("CLIP_T") != "" else "3.0"))
		await get_tree().process_frame
		var sk: Skeleton3D = b.skeleton
		var inv: Transform3D = b.global_transform.affine_inverse()
		var out: Array = []
		for bone in ["Hips", "LeftFoot", "RightFoot", "LeftHand", "RightHand", "Head", "LeftLeg", "Spine01"]:
			var i: int = sk.find_bone(bone)
			if i >= 0:
				var p: Vector3 = inv * (sk.global_transform * sk.get_bone_global_pose(i).origin)
				out.append("%s=(%.2f,%.2f,%.2f)" % [bone, p.x, p.y, p.z])
		print("RIDER ", clip, " ", " ".join(out))
	get_tree().quit()
