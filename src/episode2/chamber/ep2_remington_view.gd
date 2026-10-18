class_name Ep2RemingtonView
extends RefCounted
## Blender-authored founder-reference Remington. Muzzle +Z, up +Y, metres.
const MODEL := preload("res://src/episode2/assets/weapons/armory/remington_1875_gold.glb")

## The founder's own hand-and-gun model (Tripo, regraded + decimated in Blender: tools/ep2_blender/revolver_improve.py).
## Gun and glove are one mesh, so the first-person viewmodel uses it whole; the third-person director uses make_held(); make() is the older separate-glove Remington.
const FOUNDER_MODEL := preload("res://src/episode2/assets/weapons/armory/golden_revolver_founder.glb")
## Model space: muzzle -X, up +Y, arm runs +X and down. Turn it to muzzle +Z and seat the bore on the old Remington's bore line.
const FOUNDER_TURN := PI * 0.5
const FOUNDER_OFFSET := Vector3(0.0, -0.45, -0.157)

## Gun only (glove and bracer stripped in Blender: tools/ep2_blender/revolver_gun_only.py) for the third-person
## director, where the hero's own hand holds it.
const FOUNDER_GUN_MODEL := preload("res://src/episode2/assets/weapons/armory/golden_revolver_gun.glb")

static func make_held() -> Node3D:
	var root := Node3D.new()
	root.name = "GoldenRemington1875"
	var model: Node3D = FOUNDER_GUN_MODEL.instantiate()
	model.name = "FounderRevolverGun"
	model.rotation.y = FOUNDER_TURN
	model.position = FOUNDER_OFFSET
	root.add_child(model)
	return root

static func make_founder() -> Node3D:
	var root := Node3D.new()
	root.name = "GoldenRemington1875"
	var model: Node3D = FOUNDER_MODEL.instantiate()
	model.name = "FounderRevolver"
	model.rotation.y = FOUNDER_TURN
	model.position = FOUNDER_OFFSET
	root.add_child(model)
	root.set_meta("hip_rotation", Vector3(0.03, PI + 0.28, -0.04))
	root.set_meta("hip_offset", Vector3(0.015, 0.055, -0.08))
	root.set_meta("arm_pivot", Vector3(-0.14, -0.23, -0.33))
	root.set_meta("ads_cam", Vector3(0, 0.095, -0.60))
	return root

static func make() -> Node3D:
	var root: Node3D = MODEL.instantiate()
	root.name = "GoldenRemington1875"
	var hand: Node3D = preload("res://src/episode2/assets/weapons/armory/remington_grip_hand.glb").instantiate()
	hand.name = "RightArm"
	root.add_child(hand)
	root.set_meta("hip_rotation", Vector3(0.03, PI + 0.28, -0.04))
	root.set_meta("hip_offset", Vector3(0.015, 0.055, -0.08))
	root.set_meta("arm_pivot", Vector3(-0.14, -0.23, -0.33))
	root.set_meta("ads_cam", Vector3(0, 0.063, -0.52))
	return root
