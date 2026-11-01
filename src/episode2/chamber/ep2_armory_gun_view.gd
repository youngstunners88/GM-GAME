class_name Ep2ArmoryGunView
extends RefCounted
## First-person views of Rich & Utah's new stock (founder 2026-11-01): the coach gun, the Bergmann MP18 and the golden Thompson.
## Each is the Blender-built GLB (tools/ep2_blender/build_armory_new_guns.py, real size, muzzle +Z, up +Y, trigger at the origin)
## with Lil Blunt's leafy hands and leather bracers on the grip and the fore-end (Ep2ViewHands' procedural arms), so the equipped
## gun is always in his hands. The view carries the metas Ep2Viewmodel reads: carry offset, the ADS eye point, the forearm pivot,
## the muzzle (flash) and its own report sounds.

const DIR := "res://src/episode2/assets/weapons/armory/"
const MODELS := {
	Ep2ArmoryState.SHOT: DIR + "coach_shotgun.glb",
	Ep2ArmoryState.MP18: DIR + "bergmann_mp18.glb",
	Ep2ArmoryState.TOMMY: DIR + "thompson_gold.glb",
}
const ICONS := {
	Ep2ArmoryState.SHOT: DIR + "coach_shotgun_icon.png",
	Ep2ArmoryState.MP18: DIR + "bergmann_mp18_icon.png",
	Ep2ArmoryState.TOMMY: DIR + "thompson_gold_icon.png",
}
## Measured in the model frame (the build script prints its Blender anchors; game = (x, z, -y)): muzzle, the eye when aimed (on the
## line through the rear and front sights), the trigger-hand grip and the support hand.
const ANCHORS := {
	Ep2ArmoryState.SHOT: {"muzzle": Vector3(0, 0.036, 0.585), "eye": Vector3(0, 0.066, -0.06), "grip": Vector3(0, 0.0, -0.07), "fore": Vector3(0, 0.0, 0.2)},
	Ep2ArmoryState.MP18: {"muzzle": Vector3(0, 0.0, 0.352), "eye": Vector3(0, 0.035, -0.21), "grip": Vector3(0, -0.055, -0.18), "fore": Vector3(0, -0.045, 0.04)},
	Ep2ArmoryState.TOMMY: {"muzzle": Vector3(0, 0.022, 0.48), "eye": Vector3(0, 0.075, -0.2), "grip": Vector3(0, -0.07, -0.085), "fore": Vector3(0, -0.06, 0.22)},
}
const SOUNDS := {
	Ep2ArmoryState.SHOT: ["ep2_shotgun_blast_1", "ep2_shotgun_blast_2"],
	Ep2ArmoryState.MP18: ["ep2_mp18_shot_1", "ep2_mp18_shot_2", "ep2_mp18_shot_3"],
	Ep2ArmoryState.TOMMY: ["ep2_tommy_shot_1", "ep2_tommy_shot_2", "ep2_tommy_shot_3"],
}
## The carry: the trigger 0.36 m ahead of the eye, low right (Ep2Viewmodel adds this to its hip position).
const HIP_OFFSET := Vector3(0.03, -0.03, 0.12)
## The founder's Winchester shows Lil Blunt in an olive leather glove with a green sleeve; the new guns' hands wear the same.
const GLOVE := Color(0.36, 0.34, 0.20)
const GLOVE_DARK := Color(0.27, 0.25, 0.14)
## Forearms leave the frame DOWNWARD (rifle-local, muzzle +Z): never across the middle of the view.
const RIGHT_FOREARM := Vector3(-0.42, -0.78, -0.48)
const LEFT_FOREARM := Vector3(0.28, -0.84, -0.46)


static func has_view(id: String) -> bool:
	return MODELS.has(id)


## The bare gun (no hands): the Armory showcase spins this one.
static func model(id: String) -> Node3D:
	var path: String = str(MODELS.get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


static func icon(id: String) -> Texture2D:
	var path: String = str(ICONS.get(id, ""))
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null


## The first-person view: gun + hands + metas. Never null (a missing model leaves the hands on an empty frame).
static func make(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "View_" + id
	var gun: Node3D = model(id)
	if gun != null:
		gun.name = "Gun"
		root.add_child(gun)
	var a: Dictionary = ANCHORS.get(id, ANCHORS[Ep2ArmoryState.TOMMY])
	var hands := Node3D.new()
	hands.name = "Hands"
	root.add_child(hands)
	var skin := Ep2ViewHands._mat(GLOVE, 0.85, 0.04)
	var skin_dark := Ep2ViewHands._mat(GLOVE_DARK, 0.85, 0.03)
	var leather := Ep2ViewHands._mat(Ep2ViewHands.SLEEVE_GREEN, 0.88, 0.02)
	var brass := Ep2ViewHands._mat(Ep2ViewHands.BRASS, 0.35, 0.0)
	brass.metallic = 0.7
	# trigger hand around the wrist / pistol grip, forearm back to the right shoulder; support hand under the fore-end or the grip
	Ep2ViewHands._arm(hands, "Right", a["grip"], RIGHT_FOREARM, skin, skin_dark, leather, brass, false)
	Ep2ViewHands._arm(hands, "Left", a["fore"], LEFT_FOREARM, skin, skin_dark, leather, brass, true)
	root.set_meta("hip_offset", HIP_OFFSET)
	root.set_meta("ads_cam", a["eye"])
	root.set_meta("arm_pivot", a["grip"])
	root.set_meta("muzzle", a["muzzle"])
	root.set_meta("shot_sounds", SOUNDS.get(id, []))
	return root
