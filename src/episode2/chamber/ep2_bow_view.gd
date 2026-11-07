class_name Ep2BowView
extends RefCounted
## Shared authored longbow: independent limb morph, string, nock, arrow, and hand frames.
const BOW := preload("res://src/episode2/assets/weapons/armory/bear_longbow.glb")
const ARROW := preload("res://src/episode2/assets/weapons/armory/bear_arrow.glb")

static func arrow() -> Node3D:
	return ARROW.instantiate()

## The founder's bow (Drive "medieval bow", 2026-10-20; skill ep2-founder-bow) is a streamed extra: where it is mounted the PLAYER's bow is that bow, and
## the bears keep the bear bow (`make(false)`). Everywhere else this file behaves exactly as before.
static func has_founder() -> bool:
	return Ep2Extras.has(Ep2Extras.BOW)


static func make(player: bool = false) -> Node3D:
	if player and has_founder():
		var founder: Node3D = make_founder()
		if founder != null:
			return founder
	var root := Node3D.new()
	root.name = "RecoveredBearBow" if player else "Bow"
	root.add_child(BOW.instantiate())
	root.set_meta("limbs", root.find_children("FlexibleLimbs", "MeshInstance3D", true, false))
	var overlays: Array = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if str(node.name).begins_with("Tip binding") or str(node.name).begins_with("Horn nock"):
			overlays.append([node, node.position])
	root.set_meta("overlays", overlays)
	for label in ["Grip", "Nock"]:
		var mark := Marker3D.new()
		mark.name = label
		root.add_child(mark)
	var shaft := arrow()
	shaft.name = "NockedArrow"
	root.add_child(shaft)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c3b38e")
	material.roughness = 0.95
	for i in 2:
		var line := MeshInstance3D.new()
		line.name = "String%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0018
		mesh.bottom_radius = 0.0018
		mesh.radial_segments = 8
		line.mesh = mesh
		line.material_override = material
		root.add_child(line)
	if player:
		# Both authored hand meshes keep positive transforms; left glove is baked mirrored in Blender.
		# (the separate Blender hand GLBs were retired with the founder bow; without the streamed bow this view is the bare bear bow, and the hands are simple stand-ins)
		for side in ["Left", "Right"]:
			var path: String = "res://src/episode2/assets/weapons/armory/bow_%s_hand.glb" % side.to_lower()
			var hand: Node3D = (load(path) as PackedScene).instantiate() if ResourceLoader.exists(path) else Node3D.new()
			hand.name = side + "Hand"
			root.add_child(hand)
		root.set_meta("hip_offset", Vector3(-0.39, 0.04, -0.16))
		root.set_meta("hip_rotation", Vector3(0.0, PI + 0.06, -0.10))
		root.set_meta("ads_cam", Vector3(0.16, 0.02, -0.65))
	update(root, 0.0, true)
	return root

static func update(root: Node3D, draw: float, nocked: bool) -> void:
	if root.has_meta("fb"):
		_pose_founder(root, draw, 1.0 if nocked else 0.0, 0.0, draw)
		return
	var nock: Node3D = root.get_node("Nock")
	nock.position = Vector3(0.0, 0.0, -0.44 - 0.23 * draw)
	var shaft: Node3D = root.get_node("NockedArrow")
	shaft.visible = nocked
	shaft.position = nock.position
	for mesh in root.get_meta("limbs"):
		var mi := mesh as MeshInstance3D
		if mi.get_blend_shape_count() > 0:
			mi.set_blend_shape_value(0, draw)
	for pair in root.get_meta("overlays"):
		var original: Vector3 = pair[1]
		(pair[0] as Node3D).position = original - Vector3(0, 0, 0.045 * pow(absf(original.y) / 0.75, 2.0) * draw)
	for i in 2:
		var end := Vector3(0.0, 0.75 if i == 0 else -0.75, -0.44 - 0.045 * draw)
		var line: MeshInstance3D = root.get_node("String%d" % i)
		(line.mesh as CylinderMesh).height = end.distance_to(nock.position)
		line.position = (end + nock.position) * 0.5
		line.basis = Basis.looking_at(end - nock.position, Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
	var hand: Node3D = root.get_node_or_null("RightHand")
	if hand != null:
		hand.position = nock.position


# --- THE FOUNDER'S BOW ---------------------------------------------------------------------------------------------------------------
# Bow frame (tools/ep2_blender/build_founder_bow.py): origin = the grip, +y up along the limbs, +z the way the arrow flies, +x the archer's LEFT (viewed
# from behind the bow). Pieces under "Model": BowArm (riser, Lil Blunt's left arm, glove, bracer, sleeve), Limb_Up / Limb_Low (a `draw` blend shape
# each), Emblem (the GM disc, both sides). Reparented to the root: NockedArrow, RightHand (both with their origin AT the nock, so a node position is a
# string position). The string is two cylinders, tip to nock, never a baked rod.

const FOUNDER_ARROW_LEN := 0.746              # nock (tail) to head, metres, as built by build_founder_bow.py (--pinch-z -0.31, head at +0.436)
## The string hand's forearm leaves the wrist along this axis in the model (printed by the build as hand_axis_game); in the viewmodel the hand is turned so the forearm runs
## back and a little down and to the right, out of the bottom-right of the frame, the way a drawn arm reaches the shoulder.
const FOUNDER_HAND_AXIS := Vector3(-0.549, 0.712, -0.438)
const FOUNDER_FOREARM_DIR := Vector3(-0.28, -0.42, -0.86)


static func make_founder() -> Node3D:
	var scene: PackedScene = load(Ep2Extras.BOW) as PackedScene
	if scene == null:
		return null
	var model: Node3D = scene.instantiate() as Node3D
	var arrow_src: Node3D = model.find_child("Arrow", true, false) as Node3D
	var hand_src: Node3D = model.find_child("RightHand", true, false) as Node3D
	var up: MeshInstance3D = model.find_child("Limb_Up", true, false) as MeshInstance3D
	var low: MeshInstance3D = model.find_child("Limb_Low", true, false) as MeshInstance3D
	var nock_full: Node3D = model.find_child("Nock_Full", true, false) as Node3D
	var nock_rest: Node3D = model.find_child("Nock_Rest", true, false) as Node3D
	var tip_up: Node3D = model.find_child("Tip_Up", true, false) as Node3D
	var tip_low: Node3D = model.find_child("Tip_Low", true, false) as Node3D
	if arrow_src == null or hand_src == null or up == null or low == null or nock_full == null or nock_rest == null or tip_up == null or tip_low == null:
		model.free()
		return null
	var root := Node3D.new()
	root.name = "RecoveredBearBow"
	model.name = "Model"
	root.add_child(model)
	for pair in [[arrow_src, "NockedArrow"], [hand_src, "RightHand"]]:
		var n: Node3D = pair[0]
		n.get_parent().remove_child(n)
		n.name = pair[1]
		root.add_child(n)
	for label in ["Grip", "Nock"]:
		var mark := Marker3D.new()
		mark.name = label
		root.add_child(mark)
	_add_strings(root)
	var gp: Vector3 = (root.get_node("NockedArrow") as Node3D).position
	root.set_meta("fb", {
		"limbs": [up, low],
		"tip_up": tip_up.position, "tip_low": tip_low.position,
		"rest": nock_rest.position, "full": nock_full.position,
		"bend": 0.13, "shorten": 0.02, "hand_roll": 0.0,
		"hand_q": Quaternion(FOUNDER_HAND_AXIS.normalized(), FOUNDER_FOREARM_DIR.normalized()),
	})
	root.set_meta("limbs", [up, low])
	root.set_meta("overlays", [])
	root.get_node("Nock").position = nock_rest.position
	# carry and aim in the camera (the viewmodel reads these): the bow arm low on the left of the frame; aimed, the eye sits behind the string hand on the arrow's line
	root.set_meta("vm_scale", 0.46)                                      # the Tripo glove is the size of a real fist; the rifle's hands are smaller on screen
	# CANTED, like the Winchester is held: seen square from behind, the arrow, the string hand and both sleeves all stack along the line of sight. Turned ~50 degrees
	# the bow shows its face and emblem, the arrow runs across the frame and the string hand draws toward the lower right. (Negative cant puts the string hand on the left.)
	# 2026-10-21 founder "the bow is trash": the old pose (scale 0.62, y -0.04) put everything below the grip off the bottom of the frame and the string hand over the middle.
	# Smaller and raised, the whole bow, the bracer and the string hand read in one frame (probe p3 of tools/ep2_shots/bow_vm_shot).
	root.set_meta("hip_offset", Vector3(-0.34, 0.17, -0.22))
	root.set_meta("hip_rotation", Vector3(0.0, PI + 0.75, -0.12))
	root.set_meta("ads_pos", Vector3(-0.02, -0.10, -0.55))
	root.set_meta("ads_rotation", Vector3(0.0, PI + 0.35, -0.05))
	_founder_forearm(root.get_node("RightHand") as MeshInstance3D)
	_tone_founder(root)
	_pose_founder(root, 0.0, 1.0, 0.0, 0.0)
	return root


## THE STRING HAND'S FOREARM (founder 2026-11-07: it "looks like a plastic pole"). build_founder_bow.py grows a 0.9 m sleeve from the glove's
## cut as a straight 14-sided frustum that widens slightly, every UV on one texel and a flat olive: at full draw it is a smooth even pole across the
## lower right of the frame. Same pattern as Ep2ViewHands._add_sleeve: that surface is dropped here, and a forearm is grown from the same cut and axis:
## a rolled leather cuff at the wrist, the sleeve swelling over the forearm and narrowing a little toward the elbow, soft folds that bunch near the cuff,
## and a woven-cloth normal so the light breaks across it. The glove, the nock origin, the string and the limbs' shape keys are untouched.
const FOREARM_LEN := 0.95                 # its far end must never reach the screen (0.62 showed its end at two-thirds draw)
## The cloth mottles between these two olives, the bow arm's own sleeve shades (not one flat colour).
const FOREARM_CLOTH := Color(0.115, 0.15, 0.075)
const FOREARM_CLOTH_LIGHT := Color(0.20, 0.235, 0.12)
const FOREARM_CUFF := Color(0.26, 0.17, 0.10)


static func _founder_forearm(hand: MeshInstance3D) -> void:
	if hand == null or hand.mesh == null:
		return
	var src: Mesh = hand.mesh
	var keep := ArrayMesh.new()
	var sleeve_verts := PackedVector3Array()
	for i in src.get_surface_count():
		var mat: Material = src.surface_get_material(i)
		var arrays: Array = src.surface_get_arrays(i)
		if mat != null and str(mat.resource_name) == "SleeveCloth":
			sleeve_verts = arrays[Mesh.ARRAY_VERTEX]
			continue
		keep.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		keep.surface_set_material(keep.get_surface_count() - 1, mat)
	if sleeve_verts.is_empty():
		return                                                            # an older bow without the grown sleeve: leave it as it is
	hand.mesh = keep
	# the cut and the axis, read back from the dropped sleeve: its first ring sits on the glove's cut, its axis is the forearm's
	var axis: Vector3 = FOUNDER_HAND_AXIS.normalized()
	var lo: float = INF
	for v in sleeve_verts:
		lo = minf(lo, v.dot(axis))
	var cut := Vector3.ZERO
	var n: int = 0
	for v in sleeve_verts:
		if v.dot(axis) < lo + 0.01:
			cut += v
			n += 1
	cut /= float(maxi(n, 1))
	var r0: float = 0.0
	for v in sleeve_verts:
		if v.dot(axis) < lo + 0.01:
			var off: Vector3 = v - cut
			r0 += (off - axis * off.dot(axis)).length()
	r0 /= float(maxi(n, 1))
	var forearm := MeshInstance3D.new()
	forearm.name = "StringForearm"
	forearm.mesh = _forearm_mesh(cut, axis, r0)
	hand.add_child(forearm)


## The forearm as one mesh: surface 0 the cuff (leather), surface 1 the sleeve (cloth). Radii are fractions of the glove's cut radius `r0`.
static func _forearm_mesh(cut: Vector3, axis: Vector3, r0: float) -> ArrayMesh:
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = side.cross(axis).normalized()
	# [distance along the arm, radius factor, fold depth]: the cuff rolls over the glove's edge, then the sleeve, fuller over the muscle
	var cuff: Array = [[0.0, 0.98, 0.0], [0.006, 1.10, 0.0], [0.040, 1.12, 0.0], [0.050, 1.02, 0.0]]
	var cloth: Array = [[0.046, 1.00, 0.0], [0.08, 1.10, 0.05], [0.13, 1.20, 0.07], [0.20, 1.28, 0.05], [0.28, 1.31, 0.035],
		[0.38, 1.28, 0.03], [0.50, 1.22, 0.025], [0.70, 1.20, 0.02], [FOREARM_LEN, 1.18, 0.02]]
	var mesh := ArrayMesh.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.25
	var weave := NoiseTexture2D.new()
	weave.width = 128
	weave.height = 128
	weave.seamless = true
	weave.as_normal_map = true
	weave.bump_strength = 2.0
	weave.noise = noise
	var blotch := FastNoiseLite.new()                                     # the cloth's mottle: large soft patches, like the bow arm's sleeve
	blotch.frequency = 0.035
	var ramp := Gradient.new()
	ramp.set_color(0, FOREARM_CLOTH)
	ramp.set_color(1, FOREARM_CLOTH_LIGHT)
	var mottle := NoiseTexture2D.new()
	mottle.width = 128
	mottle.height = 128
	mottle.seamless = true
	mottle.noise = blotch
	mottle.color_ramp = ramp
	for part in 2:
		var rings: Array = cuff if part == 0 else cloth
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs: int = 20
		for k in rings.size() - 1:
			for i in segs:
				var quad: Array = [[k, i], [k + 1, i + 1], [k + 1, i], [k, i], [k, i + 1], [k + 1, i + 1]]     # clockwise seen from outside (Godot's front)
				for q in quad:
					var ring: Array = rings[q[0]]
					var a: float = TAU * float(q[1]) / float(segs)
					var d: float = float(ring[0])
					# folds: three soft creases that twist a little along the arm, deepest just above the cuff
					var r: float = r0 * float(ring[1]) * (1.0 - float(ring[2]) * (0.5 + 0.5 * sin(3.0 * a + d * 9.0)))
					st.set_uv(Vector2(float(q[1]) / float(segs) * 2.0, d * 6.0))
					st.add_vertex(cut + axis * d + (side * cos(a) + up * sin(a)) * r)
		st.generate_normals()
		st.generate_tangents()
		var m := StandardMaterial3D.new()
		m.resource_name = "ForearmCuff" if part == 0 else "ForearmCloth"
		m.albedo_color = FOREARM_CUFF if part == 0 else Color.WHITE
		m.roughness = 0.75 if part == 0 else 0.95
		if part == 1:
			m.albedo_texture = mottle
			m.normal_enabled = true
			m.normal_texture = weave
			m.normal_scale = 0.35
		st.set_material(m)
		st.commit(mesh)
	return mesh


## The Tripo textures are bright for the desert sun (the first captures washed the gloves out): the textured surfaces are scaled to ~0.84 and the grown sleeve cloth a
## little darker, on per-bow material copies (the shared GLB materials are never touched). The GM emblem keeps its full colour and its emission.
static func _tone_founder(root: Node3D) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src: Material = m.get_surface_override_material(i)
			if src == null:
				src = m.mesh.surface_get_material(i)
			if not (src is StandardMaterial3D) or str(src.resource_name) == "GM_Emblem":
				continue
			var d: StandardMaterial3D = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			var k: float = 0.55 if str(src.resource_name) == "SleeveCloth" else 0.84
			d.albedo_color = Color(d.albedo_color.r * k, d.albedo_color.g * k, d.albedo_color.b * k, d.albedo_color.a)
			if m.name == "RightHand" and str(src.resource_name) != "SleeveCloth":
				# the string hand's Tripo glove came out pale stone grey next to the bow hand's olive-brown leather: warm it to the same leather
				d.albedo_color = Color(d.albedo_color.r * 0.80, d.albedo_color.g * 0.80, d.albedo_color.b * 0.56, d.albedo_color.a)
			m.set_surface_override_material(i, d)


static func _add_strings(root: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c3b38e")
	material.roughness = 0.95
	for i in 2:
		var line := MeshInstance3D.new()
		line.name = "String%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0018
		mesh.bottom_radius = 0.0018
		mesh.radial_segments = 8
		line.mesh = mesh
		line.material_override = material
		root.add_child(line)


## Pose the founder bow. `draw` 0..1 (string back), `renock` 0..1 (the arrow is slid onto the string; 0 = no arrow), `age` seconds since the loose (limb and string
## shiver, damped), `limb` the limb blend value (draw plus the shiver).
static func _pose_founder(root: Node3D, draw: float, renock: float, age: float, limb_draw: float) -> void:
	var fb: Dictionary = root.get_meta("fb")
	var rest: Vector3 = fb["rest"]
	var full: Vector3 = fb["full"]
	var e: float = clampf(draw, 0.0, 1.0)
	var shiver: float = exp(-age * 15.0) * sin(age * 62.0) if age < 1.0 else 0.0
	var limb: float = clampf(limb_draw + 0.22 * shiver, 0.0, 1.12)
	var nock_pos := Vector3(rest.x + 0.012 * shiver, rest.y, lerpf(rest.z, full.z, e))
	var nock: Node3D = root.get_node("Nock")
	nock.position = nock_pos
	for mesh in fb["limbs"]:
		var mi := mesh as MeshInstance3D
		if mi.get_blend_shape_count() > 0:
			mi.set_blend_shape_value(0, limb)
	var bend: float = fb["bend"]
	var shorten: float = fb["shorten"]
	var ends: Array = [fb["tip_up"] + Vector3(0.0, -shorten * limb, -bend * limb), fb["tip_low"] + Vector3(0.0, shorten * limb, -bend * limb)]
	for i in 2:
		var end: Vector3 = ends[i]
		var line: MeshInstance3D = root.get_node("String%d" % i)
		(line.mesh as CylinderMesh).height = maxf(end.distance_to(nock_pos), 0.01)
		line.position = (end + nock_pos) * 0.5
		line.basis = Basis.looking_at(end - nock_pos, Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
	var slide: float = 1.0 - clampf(renock, 0.0, 1.0)
	var arrow: Node3D = root.get_node("NockedArrow")
	arrow.visible = renock > 0.02
	arrow.position = nock_pos + Vector3(0.05, -0.2, -0.04) * slide                  # the arrow is brought up from below the hand
	var hand: Node3D = root.get_node_or_null("RightHand")
	if hand != null:
		hand.position = nock_pos + Vector3(0.09, -0.26, -0.06) * slide
		# 2026-10-21 founder "the bow is trash": at rest and while the arrow is slid on, the string hand's forearm ran toward the camera and was cut by the near plane
		# in mid-screen (a green stump). The hand now only exists while the string is drawn: it closes on the string between 30 and 50 % of the draw (earlier its forearm is cut by the near plane) and is gone
		# as the loose lands (the arrow rides up onto the string on its own).
		var present: float = smoothstep(0.30, 0.50, e) if renock > 0.99 else 0.0
		hand.visible = present > 0.01
		hand.basis = Basis(fb["hand_q"] as Quaternion) * Basis.from_euler(Vector3(0.0, 0.0, float(fb["hand_roll"]) + 0.45 * slide)) * Basis.from_scale(Vector3.ONE * (0.86 * maxf(present, 0.01)))


## The animated bow from the gun's state (called every viewmodel step): draw with ease, the snap and shiver of the loose, the re-nock.
static func animate_founder(root: Node3D, bow: Ep2Bow) -> void:
	var raw: float = bow.draw_amount()
	var e: float = raw * raw * (3.0 - 2.0 * raw) if bow.drawing else raw
	var cp: float = bow.cycle_progress()
	var age: float = 99.0
	var renock: float = 1.0 if bow.rounds > 0 else 0.0
	if not bow.drawing and cp < 1.0:
		age = cp * bow.cycle_time                                                  # seconds since the loose
		renock = clampf((cp - 0.38) / 0.62, 0.0, 1.0) if bow.rounds > 0 else 0.0
		if bow.release_time > 0.0:
			renock = 0.0                                                           # the string is still snapping forward
	_pose_founder(root, e, renock, age, e)
	var model: Node3D = root.get_node("Model")
	model.position = Vector3(0.0, 0.0, 0.03 * e)                                   # the bow arm pushes out as the string comes back


## The arrow that FLIES: the founder's own arrow, its origin at the HEAD (so the swept hit test starts at the point), +z along the flight like the bear arrow.
static func player_arrow() -> Node3D:
	if not has_founder():
		return arrow()
	var scene: PackedScene = load(Ep2Extras.BOW) as PackedScene
	var model: Node3D = scene.instantiate() as Node3D if scene != null else null
	var src: Node3D = model.find_child("Arrow", true, false) as Node3D if model != null else null
	if src == null:
		if model != null:
			model.free()
		return arrow()
	var holder := Node3D.new()
	holder.name = "FlightArrow"
	src.get_parent().remove_child(src)
	model.free()
	holder.add_child(src)
	src.position = Vector3(0.0, 0.0, -FOUNDER_ARROW_LEN)                          # the tail is that far behind the head
	holder.scale = Vector3.ONE * 0.8
	return holder
