class_name Ep2RemingtonView
extends RefCounted
## Blender-authored founder-reference Remington. Muzzle +Z, up +Y, metres.
const MODEL := preload("res://src/episode2/assets/weapons/armory/remington_1875_gold.glb")

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
