class_name Ep2ViewHands
extends RefCounted
## Lil Blunt's first-person HANDS and forearms on the Winchester (founder 2026-10-04, round 3: "What I don't like
## currently is that we don't see Lil Blunt's hands on the gun like in true shooter game style. This is more like
## it [IMG_3070: leafy green hands, leather bracers, one hand on the wrist of the stock, one under the fore-end]").
## Skill ep2-fps-shooter-feel (hands section).
##
## The hands are children of the RIFLE node (rifle-local metres: muzzle +Z, stock -Z, +Y up; the rifle itself is
## yawed PI toward the camera), so they inherit EVERY viewmodel motion for free: hip pose, ADS, sway, recoil, the
## lever dip, the reload tilt. Stylised, procedural, no new textures: a leafy green mitten with leaf-shaped
## fingers, a leather bracer with a brass band on each forearm.

## The founder's rifle (his Tripo GLB, surgery + graded PBR baked by tools/ep2_blender/rifle_export_game.py): lever-action
## Winchester with the GM logo on the receiver and Lil Blunt's gloved left hand + green forearm on the fore-end.
const FOUNDER_GLB := "res://src/episode2/assets/weapons/winchester_1886_founder.glb"
static var founder_ads_depth: float = -0.46
## Where the eye sits in the MODEL frame when shouldered (measured from the model: barrel top 0.15, receiver 0.195, comb 0.22,
## so the camera must sit FORWARD of the receiver, just above the barrel, behind the rear sight - the stock and receiver are then
## behind the camera and never block the target; skill ep2-fps-shooter-feel, placement sim).
static var founder_ads_cam: Vector3 = Vector3(0.0, 0.155, 0.14)
static var founder_drop: float = 0.11        # model sits a little lower than the forge sight line so the stock comb never blocks the view in ADS
static var founder_z_shift: float = -0.15
const HANDS_GLB := "res://src/episode2/assets/fp_hands.glb"
const GREEN := Color(0.30, 0.62, 0.17)
const GREEN_DARK := Color(0.18, 0.42, 0.10)
const LEATHER := Color(0.30, 0.17, 0.09)
const BRASS := Color(0.78, 0.58, 0.20)


## Builds the hands under `rifle` and returns the root ("Hands"). Idempotent.
static func attach(rifle: Node3D) -> Node3D:
	var existing: Node = rifle.get_node_or_null("Hands")
	if existing:
		return existing as Node3D
	var root := Node3D.new()
	root.name = "Hands"
	rifle.add_child(root)
	# Best: the founder's rifle (hand included). The forge rifle meshes are hidden and the model's top is matched to
	# the forge rifle's so the ADS sight line still lands on the crosshair.
	var founder: PackedScene = load(FOUNDER_GLB) as PackedScene if ResourceLoader.exists(FOUNDER_GLB) else null
	if founder:
		var forge_top: float = _top_y(rifle, rifle)
		for mi in rifle.find_children("*", "MeshInstance3D", true, false):
			if not root.is_ancestor_of(mi) and not String((mi as Node).name).begins_with("Muzzle"):
				(mi as MeshInstance3D).visible = false
		var fm: Node3D = founder.instantiate() as Node3D
		fm.name = "HandsModel"
		root.add_child(fm)
		fm.position = Vector3(0.0, forge_top - _top_y(fm, rifle) - founder_drop, founder_z_shift)
		rifle.set_meta("ads_cam", fm.position + founder_ads_cam)
		rifle.set_meta("ads_depth", founder_ads_depth)      # the longer stock needs the camera pulled behind the butt
		return root
	# Next: the Blender-built model (tools/blender/build_fp_hands.py): knitted green mittens, studded bracers.
	var packed: PackedScene = load(HANDS_GLB) as PackedScene if ResourceLoader.exists(HANDS_GLB) else null
	if packed:
		var model: Node3D = packed.instantiate() as Node3D
		model.name = "HandsModel"        # the GLB holds both arms (right/left hand + bracer meshes)
		root.add_child(model)
		return root
	var skin := _mat(GREEN, 0.95, 0.10)
	var skin_dark := _mat(GREEN_DARK, 0.95, 0.06)
	var leather := _mat(LEATHER, 0.8, 0.0)
	var brass := _mat(BRASS, 0.35, 0.0)
	brass.metallic = 0.7
	# RIGHT hand: gripping the wrist of the stock, just behind the receiver, forearm running back toward the camera.
	_arm(root, "Right", Vector3(0.0, -0.075, -0.2), Vector3(-0.62, -0.30, -0.72), skin, skin_dark, leather, brass, false)
	# LEFT hand: cupped under the fore-end, forearm running back under the rifle toward the left shoulder.
	_arm(root, "Left", Vector3(0.0, -0.082, 0.22), Vector3(0.68, -0.20, -0.70), skin, skin_dark, leather, brass, true)
	return root


static func _mat(c: Color, rough: float, emit: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = emit        # a hint of self-light so the hands read in the dim forge
	return m


## One hand + forearm. `wrist` is the hand centre (rifle-local), `back` the direction the forearm runs (toward the
## elbow, i.e. toward the camera). `support` = the fore-end hand (palm up, fingers wrapped over the wood).
static func _arm(root: Node3D, side: String, wrist: Vector3, back: Vector3, skin: Material, skin_dark: Material,
		leather: Material, brass: Material, support: bool) -> void:
	var arm := Node3D.new()
	arm.name = side + "Arm"
	arm.position = wrist
	root.add_child(arm)
	var dir: Vector3 = back.normalized()
	# --- the hand: a leafy mitten (palm + 4 leaf fingers + thumb) ---
	var palm := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.052
	pm.height = 0.104
	palm.mesh = pm
	palm.material_override = skin
	palm.scale = Vector3(1.0, 0.72, 1.25)
	arm.add_child(palm)
	# fingers wrap around the wood: right hand over the top/left of the wrist, left hand over the fore-end
	for i in 4:
		var f := MeshInstance3D.new()
		var fm := CapsuleMesh.new()
		fm.radius = 0.0125
		fm.height = 0.085
		f.mesh = fm
		f.material_override = skin_dark if i % 2 == 1 else skin
		var zoff: float = (float(i) - 1.5) * 0.026
		if support:
			# left: fingers curl up over the near side of the fore-end
			f.position = Vector3(0.045, 0.028, zoff)
			f.rotation = Vector3(0.0, 0.0, deg_to_rad(40.0))
		else:
			# right: fingers curl around the stock wrist, toward the lever side
			f.position = Vector3(-0.048, 0.01, zoff)
			f.rotation = Vector3(0.0, 0.0, deg_to_rad(-55.0))
		arm.add_child(f)
		# the leaf tip: a small flattened sphere on the end of each finger so the silhouette reads as leaves
		var tip := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.016
		tm.height = 0.032
		tip.mesh = tm
		tip.material_override = skin
		tip.scale = Vector3(0.7, 1.0, 1.5)
		tip.position = f.position + (Vector3(0.04, 0.03, 0.0) if support else Vector3(-0.036, 0.034, 0.0))
		arm.add_child(tip)
	var thumb := MeshInstance3D.new()
	var thm := CapsuleMesh.new()
	thm.radius = 0.014
	thm.height = 0.07
	thumb.mesh = thm
	thumb.material_override = skin
	thumb.position = Vector3(0.0 if support else 0.02, 0.05, 0.0 if support else 0.03)
	thumb.rotation = Vector3(deg_to_rad(80.0), 0.0, 0.0)
	arm.add_child(thumb)
	# --- the forearm: leather sleeve running back toward the elbow (long enough to leave the frame) ---
	var sleeve := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.052
	sm.bottom_radius = 0.058
	sm.height = 0.7
	sleeve.mesh = sm
	sleeve.material_override = leather
	arm.add_child(sleeve)
	_orient_along(sleeve, dir, 0.04 + 0.35)
	# the bracer: a wider leather band near the wrist with a brass ring and a stud
	var bracer := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.066
	bm.bottom_radius = 0.07
	bm.height = 0.16
	bracer.mesh = bm
	bracer.material_override = leather
	arm.add_child(bracer)
	_orient_along(bracer, dir, 0.12)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.066
	rm.outer_radius = 0.078
	ring.mesh = rm
	ring.material_override = brass
	arm.add_child(ring)
	_orient_along(ring, dir, 0.065)
	var stud := MeshInstance3D.new()
	var stm := SphereMesh.new()
	stm.radius = 0.016
	stm.height = 0.032
	stud.mesh = stm
	stud.material_override = brass
	arm.add_child(stud)
	stud.position = dir * 0.15 + Vector3(0.0, 0.07, 0.0)


## Orient a cylinder (its long axis is +Y) so it runs along `dir` and sits `dist` along it from the arm's origin.
static func _orient_along(mi: MeshInstance3D, dir: Vector3, dist: float) -> void:
	var up := Vector3.UP
	var axis: Vector3 = up.cross(dir)
	var angle: float = up.angle_to(dir)
	if axis.length() < 0.0001:
		axis = Vector3.RIGHT
	mi.transform = Transform3D(Basis(axis.normalized(), angle), dir * dist)


## Highest point (in `space`'s local frame) of every mesh under `node`, ignoring the Hands subtree on the rifle itself.
static func _top_y(node: Node3D, space: Node3D) -> float:
	var top: float = -1.0e9
	var inv: Transform3D = space.global_transform.affine_inverse()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or (node == space and space.get_node_or_null("Hands") and space.get_node("Hands").is_ancestor_of(m)):
			continue
		var aabb: AABB = m.mesh.get_aabb()
		var xf: Transform3D = inv * m.global_transform
		for i in 8:
			top = maxf(top, (xf * aabb.get_endpoint(i)).y)
	return top
