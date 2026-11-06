class_name Ep2ArmoryGunView
extends RefCounted
## First-person views of Rich & Utah's new stock (founder 2026-11-01): the coach gun, the Bergmann MP18 and the golden Thompson.
## Each is the Blender-built GLB (tools/ep2_blender/build_armory_new_guns.py, real size, muzzle +Z, up +Y, trigger at the origin)
## with Lil Blunt's leafy hands and leather bracers on the grip and the fore-end (Ep2ViewHands' procedural arms), so the equipped
## gun is always in his hands. The view carries the metas Ep2Viewmodel reads: carry offset, the ADS eye point, the forearm pivot,
## the muzzle (flash) and its own report sounds.

const DIR := "res://src/episode2/assets/weapons/armory/"
## The founder's Meshy guns (2026-11-01 evening): gun + Lil Blunt's gloved hands in ONE model, made from his "hands carrying the gun"
## images and shrunk for the game by tools/ep2_forge/meshy_gun_to_game.py (muzzle +Z, up +Y, the barrel line at y = 0, real length).
## They ride the streamed extras pack; until it has mounted (or if it never does) the Blender stand-ins below are used.
const MESHY := "res://src/episode2/extras/armory/meshy/"
const MESHY_MODELS := {
	Ep2ArmoryState.SHOT: MESHY + "lever_shotgun.glb",
	Ep2ArmoryState.MP18: MESHY + "mp18_drum.glb",
	Ep2ArmoryState.TOMMY: MESHY + "thompson_gold.glb",
	# gun only, since 2026-11-05: real size (the stranger's pistol is this same file), held by the arms below
	Ep2ArmoryState.BORCH: Ep2Extras.BORCHARDT_GUN,
	Ep2ArmoryState.BUFF: Ep2Extras.SHARPS_SCOPED,
}
## The GM bow for the showcase only (the bow in his hands stays the animated founder bow: draw, loose, nock).
const MESHY_BOW := MESHY + "gm_bow.glb"
const MODELS := {
	Ep2ArmoryState.SHOT: DIR + "coach_shotgun.glb",
	Ep2ArmoryState.MP18: DIR + "bergmann_mp18.glb",
	Ep2ArmoryState.TOMMY: DIR + "thompson_gold.glb",
	Ep2ArmoryState.BORCH: "",
	Ep2ArmoryState.BUFF: "",
}
const ICONS := {
	Ep2ArmoryState.SHOT: DIR + "coach_shotgun_icon.png",
	Ep2ArmoryState.MP18: DIR + "bergmann_mp18_icon.png",
	Ep2ArmoryState.TOMMY: DIR + "thompson_gold_icon.png",
	Ep2ArmoryState.BORCH: DIR + "borchardt_icon.png",
	Ep2ArmoryState.BUFF: DIR + "sharps_buffalo_icon.png",
}
## Meshy views: measured on the shrunk models (tools/ep2_forge, slice profile of the gun's top line). `eye` is the aimed eye: on the
## line over the rear sight and the front sight (the Sharps: through the gap of its raised ladder sight); `ads_rot` pitches the gun so
## that line is level with the view. `hip` places the carry; `muzzle` the flash.
const MESHY_ANCHORS := {
	Ep2ArmoryState.SHOT: {"muzzle": Vector3(0, 0.02, 0.52), "eye": Vector3(0, 0.115, -0.6), "hip": Vector3(0.03, -0.03, 0.04), "pivot": Vector3(0, -0.05, -0.15)},
	# the snail drum stands just left of the bore line (x -0.12..0.018): the eye looks past its right edge
	Ep2ArmoryState.MP18: {"muzzle": Vector3(0, 0.0, 0.42), "eye": Vector3(0.05, 0.105, -0.5), "hip": Vector3(0.03, -0.03, 0.06), "pivot": Vector3(0, -0.05, -0.15),
		"ads_rot": Vector3(-0.06, PI, 0.0)},
	Ep2ArmoryState.TOMMY: {"muzzle": Vector3(0, 0.0, 0.44), "eye": Vector3(0, 0.046, -0.44), "hip": Vector3(0.03, -0.03, 0.09), "pivot": Vector3(0, -0.05, -0.12)},
}
## HELD IN THE REMINGTON'S OWN HAND (founder 2026-11-05: the Borchardt "far too small"). The cause was the hand, not the gun: the old model baked a hand at the gun's scale, 0.35 m in all,
## against the Remington's 1.0 m of gun and arm. The Remington's own gun is 0.54 m in that model (1.5x a real 0.355 m C93). So these views use the very same glove, bracer and vine arm
## (lil_blunt_gun_hand.glb), and the real-size pistol gets the Remington's first-person size here only: `gun_scale` is on the view's Gun node, the GLB stays 0.355 m for the stranger's draw.
## `gun_at` puts the gun in the view. `hands` lists the arms: `at` is the arm model's origin, `size` its scale, `mirror` makes the support hand. The Borchardt's hand stays exactly where
## the Remington's is, trigger on trigger, its toggle overhanging the wrist as a real C93's does.
const HELD := {
	Ep2ArmoryState.BORCH: {"gun_scale": 1.527, "gun_at": Vector3(0.0, 0.045, -0.083), "muzzle": Vector3(0, 0.045, 0.264), "eye": Vector3(0, 0.095, -0.60),
		"hands": [{"at": Ep2RemingtonView.FOUNDER_OFFSET, "size": 1.0, "mirror": false}],
		"hip_rotation": Vector3(0.03, PI + 0.28, -0.04), "hip_offset": Vector3(0.015, 0.055, -0.08), "arm_pivot": Vector3(-0.14, -0.23, -0.33)},
	# trigger hand on the wrist with its finger at the set triggers, support hand under the fore-end. The eye is on the tube's axis, just behind the eyepiece (build_scoped_sharps.py
	# prints it), and the bore is parallel, so the aimed view looks level down the tube; `scoped` takes the rifle away at full aim, when Ep2FpsHud draws the lens.
	Ep2ArmoryState.BUFF: {"gun_scale": 1.0, "gun_at": Vector3.ZERO, "muzzle": Vector3(0, 0.0, 0.75), "eye": Vector3(0, 0.0915, -0.25), "scoped": true,
		"hands": [{"at": Vector3(0.0, -0.277, -0.128), "size": 0.6, "mirror": false}, {"at": Vector3(0.0, -0.29, 0.229), "size": 0.6, "mirror": true}],
		"hip_rotation": Vector3(0.03, PI + 0.26, -0.04), "hip_offset": Vector3(0.02, -0.03, -0.02), "arm_pivot": Vector3(0.0, -0.075, -0.11)},
}
## Measured in the model frame (the build script prints its Blender anchors; game = (x, z, -y)): muzzle, the eye when aimed (on the
## line through the rear and front sights), the trigger-hand grip and the support hand.
const ANCHORS := {
	Ep2ArmoryState.SHOT: {"muzzle": Vector3(0, 0.036, 0.585), "eye": Vector3(0, 0.066, -0.06), "grip": Vector3(0, 0.0, -0.07), "fore": Vector3(0, 0.0, 0.2)},
	Ep2ArmoryState.MP18: {"muzzle": Vector3(0, 0.0, 0.352), "eye": Vector3(0, 0.035, -0.21), "grip": Vector3(0, -0.055, -0.18), "fore": Vector3(0, -0.045, 0.04)},
	Ep2ArmoryState.TOMMY: {"muzzle": Vector3(0, 0.022, 0.48), "eye": Vector3(0, 0.075, -0.2), "grip": Vector3(0, -0.07, -0.085), "fore": Vector3(0, -0.06, 0.22)},
	# no streamed model yet: the arms hold their places (HELD has the real views)
	Ep2ArmoryState.BUFF: {"muzzle": Vector3(0, 0.0, 0.75), "eye": Vector3(0, 0.0915, -0.25), "grip": Vector3(0, -0.075, -0.11), "fore": Vector3(0, -0.045, 0.22)},
	Ep2ArmoryState.BORCH: {"muzzle": Vector3(0, 0.0, 0.347), "eye": Vector3(0, 0.055, -0.60), "grip": Vector3(0, -0.15, -0.02), "fore": Vector3(0, -0.16, 0.0)},
}
const SOUNDS := {
	Ep2ArmoryState.SHOT: ["ep2_shotgun_blast_1", "ep2_shotgun_blast_2"],
	Ep2ArmoryState.BORCH: ["ep2_revolver_blast_1", "ep2_revolver_blast_2", "ep2_revolver_blast_3"],
	Ep2ArmoryState.BUFF: ["ep2_winchester_shot_1", "ep2_winchester_shot_2", "ep2_winchester_shot_3"],
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


## True when the founder's Meshy model for `id` is mounted (streamed extras) and will be used.
static func meshy(id: String) -> bool:
	return MESHY_MODELS.has(id) and Ep2Extras.has(str(MESHY_MODELS[id]))


## The showcase piece: the founder's Meshy gun when mounted, else the Blender stand-in.
static func model(id: String) -> Node3D:
	var path: String = str(MESHY_MODELS[id]) if meshy(id) else str(MODELS.get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var node := (load(path) as PackedScene).instantiate() as Node3D
	if meshy(id) and id == Ep2ArmoryState.TOMMY:
		_gild(node)
	return node


## The Thompson's Meshy texture is colour only (no metal map): give its gold parts their metal so it does not read as cream plastic.
static func _gild(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			var g := m.duplicate() as BaseMaterial3D
			g.metallic = 0.55
			g.roughness = 0.38
			g.metallic_specular = 0.7
			g.albedo_color = Color(0.86, 0.7, 0.38)
			mi.set_surface_override_material(i, g)


static func icon(id: String) -> Texture2D:
	var path: String = str(ICONS.get(id, ""))
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null


## The first-person view: gun + hands + metas. Never null (a missing model leaves the hands on an empty frame).
static func make(id: String) -> Node3D:
	if HELD.has(id) and meshy(id) and Ep2Extras.has(Ep2Extras.GUN_HAND):
		return _make_held(id)
	if meshy(id) and MESHY_ANCHORS.has(id):
		return _make_meshy(id)
	var root := Node3D.new()
	root.name = "View_" + id
	var gun: Node3D = model(id)
	if gun != null:
		gun.name = "Gun"
		root.add_child(gun)
	var a: Dictionary = ANCHORS[id]
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


## The gun in the Golden Remington's own hand and arm.
static func _make_held(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "View_" + id
	var a: Dictionary = HELD[id]
	var gun: Node3D = model(id)
	gun.name = "Gun"
	gun.scale = Vector3.ONE * float(a["gun_scale"])
	gun.position = a["gun_at"]
	root.add_child(gun)
	var hands := Node3D.new()
	hands.name = "Hands"
	root.add_child(hands)
	var packed: PackedScene = load(Ep2Extras.GUN_HAND) as PackedScene
	for spec in a["hands"]:
		var hand: Node3D = packed.instantiate() as Node3D
		hand.name = "GunHand"
		hand.rotation.y = Ep2RemingtonView.FOUNDER_TURN
		hand.position = spec["at"]
		var size: float = float(spec["size"])
		# turned a quarter, the model's z is the view's x: flipping it makes the left hand
		hand.scale = Vector3(size, size, -size if spec["mirror"] else size)
		hands.add_child(hand, true)
	root.set_meta("meshy", true)
	root.set_meta("hip_offset", a["hip_offset"])
	root.set_meta("arm_pivot", a["arm_pivot"])
	root.set_meta("ads_cam", a["eye"])
	root.set_meta("muzzle", a["muzzle"])
	root.set_meta("shot_sounds", SOUNDS.get(id, []))
	if a.has("hip_rotation"):
		root.set_meta("hip_rotation", a["hip_rotation"])
	if a.get("scoped", false):
		root.set_meta("scoped", true)
	return root


## The founder's Meshy view: his gun with Lil Blunt's gloved hands already on it (no procedural arms), and the same metas.
static func _make_meshy(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "View_" + id
	var gun: Node3D = model(id)
	gun.name = "Gun"
	root.add_child(gun)
	var a: Dictionary = MESHY_ANCHORS[id]
	root.set_meta("meshy", true)
	root.set_meta("hip_offset", a["hip"])
	root.set_meta("ads_cam", a["eye"])
	root.set_meta("arm_pivot", a["pivot"])
	root.set_meta("muzzle", a["muzzle"])
	# Place the aimed node directly so the eye point lands exactly on the camera for ANY aimed rotation (a pitched sight line, an
	# eye off the bore line): node = -(R * eye * scale) - sight drop.
	var rot: Vector3 = a.get("ads_rot", Vector3(0.0, PI, 0.0))
	root.set_meta("ads_rotation", rot)
	root.set_meta("ads_pos", -(Basis.from_euler(rot) * (Vector3(a["eye"]) * Ep2Viewmodel.VM_SCALE)) - Vector3(0.0, Ep2Viewmodel.VM_ADS_SIGHT_DROP, 0.0))
	root.set_meta("shot_sounds", SOUNDS.get(id, []))
	return root
