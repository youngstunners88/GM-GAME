class_name Ep2VultureMesh
extends RefCounted
## The trail's turkey vulture, built from real bird proportions instead of a cross of flat triangles: a long body, a small bare red
## head on a short neck, a fan tail, and two shoulder pivots carrying long fingered wings (about 2.5 m tip to tip at scale 1).
##
## The soaring flock and the birds at the carcasses share this one silhouette. The caller owns motion: `flap()` turns the wing
## pivots, `fold()` lays them along the body for a landing or a fall, `slump()` drops them for a corpse, `spread()` restores them,
## and the returned node keeps named pivots ("WingL", "WingR", "Neck") for the owner to pose. Meshes and materials are shared
## between birds: only the transforms differ.

const FEATHER_COLOR := Color(0.085, 0.070, 0.058)
const FLIGHT_COLOR := Color(0.17, 0.155, 0.135)
const SKIN_COLOR := Color(0.34, 0.115, 0.080)
const GLIDE_DIHEDRAL := 0.24              # the shallow V a turkey vulture soars in
const STANDING_HEIGHT := 0.17             # root height (at scale 1) that puts the feet on the ground

static var _feather: StandardMaterial3D = null
static var _flight: StandardMaterial3D = null
static var _skin: StandardMaterial3D = null
static var _body_mesh: SphereMesh = null
static var _head_mesh: SphereMesh = null
static var _beak_mesh: CylinderMesh = null
static var _leg_mesh: CylinderMesh = null
static var _wing: ArrayMesh = null
static var _primaries: ArrayMesh = null
static var _tail: ArrayMesh = null
static var _puff_mesh: QuadMesh = null


static func _ensure_shared() -> void:
	if _feather != null:
		return
	_feather = StandardMaterial3D.new()
	_feather.albedo_color = FEATHER_COLOR
	_feather.cull_mode = BaseMaterial3D.CULL_DISABLED
	_feather.roughness = 0.92
	_flight = StandardMaterial3D.new()
	_flight.albedo_color = FLIGHT_COLOR
	_flight.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flight.roughness = 0.95
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = SKIN_COLOR
	_skin.roughness = 0.80
	_body_mesh = SphereMesh.new()
	_body_mesh.radius = 0.115
	_body_mesh.height = 0.62
	_body_mesh.radial_segments = 12
	_body_mesh.rings = 7
	_head_mesh = SphereMesh.new()
	_head_mesh.radius = 0.062
	_head_mesh.height = 0.16
	_head_mesh.radial_segments = 8
	_head_mesh.rings = 5
	_beak_mesh = CylinderMesh.new()
	_beak_mesh.top_radius = 0.0
	_beak_mesh.bottom_radius = 0.030
	_beak_mesh.height = 0.13
	_beak_mesh.radial_segments = 7
	_leg_mesh = CylinderMesh.new()
	_leg_mesh.top_radius = 0.012
	_leg_mesh.bottom_radius = 0.010
	_leg_mesh.height = 0.17
	_leg_mesh.radial_segments = 5
	_wing = wing_mesh()
	_primaries = primaries_mesh()
	_tail = tail_mesh()


static func _part(mesh: Mesh, material: Material, parent: Node3D, label: String = "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	if label != "":
		m.name = label
	m.mesh = mesh
	m.material_override = material
	parent.add_child(m)
	return m


## Build one vulture. `size` is the whole bird; 1.0 gives a ~2.5 m wingspan.
static func build(size: float = 1.0) -> Node3D:
	_ensure_shared()
	var root := Node3D.new()
	root.name = "Vulture"
	root.scale = Vector3.ONE * size

	# Body: a long ellipsoid, nose toward -Z.
	var body := _part(_body_mesh, _feather, root, "Body")
	body.rotation.x = PI * 0.5 - 0.16
	body.position = Vector3(0.0, 0.02, 0.0)

	# A short bare neck and the small red head, held a little forward.
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0.0, 0.06, -0.25)
	root.add_child(neck)
	_part(_head_mesh, _skin, neck, "Head").position = Vector3(0.0, 0.0, -0.10)
	var beak := _part(_beak_mesh, _skin, neck, "Beak")
	beak.position = Vector3(0.0, -0.012, -0.21)
	beak.rotation.x = -PI * 0.5

	# Fan tail, spread enough to read from below.
	_part(_tail, _feather, root, "Tail").position = Vector3(0.0, 0.0, 0.27)

	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var pivot := Node3D.new()
		pivot.name = "WingL" if i == 0 else "WingR"
		pivot.position = Vector3(side * 0.075, 0.055, -0.03)
		root.add_child(pivot)
		_part(_wing, _feather, pivot, "Wing").scale = Vector3(side, 1.0, 1.0)
		# The pale trailing primaries are the part that catches the light when he banks.
		_part(_primaries, _flight, pivot, "Primaries").scale = Vector3(side, 1.0, 1.0)
		var leg := _part(_leg_mesh, _skin, root)
		leg.position = Vector3(side * 0.045, -0.075, 0.10)
		leg.rotation.x = 0.5
	flap(root, 0.0, 0.0)
	return root


## A slow soaring flap. `amount` 0 = wings locked in the glide's shallow V, 1 = a full downbeat.
static func flap(node: Node3D, phase: float, amount: float) -> void:
	var left := node.get_node_or_null("WingL") as Node3D
	var right := node.get_node_or_null("WingR") as Node3D
	if left == null or right == null:
		return
	# The left wing's tip is at -X, so a positive Z turn drops it: a raised tip is the negative turn on the left.
	var lift: float = GLIDE_DIHEDRAL * (1.0 - amount * 0.6) + sin(phase) * 0.52 * amount
	left.rotation = Vector3(0.0, 0.0, -lift)
	right.rotation = Vector3(0.0, 0.0, lift)


## Open wings again after `fold()` or `slump()`.
static func spread(node: Node3D) -> void:
	for pivot in [node.get_node_or_null("WingL"), node.get_node_or_null("WingR")]:
		if pivot != null:
			(pivot as Node3D).scale = Vector3.ONE
	flap(node, 0.0, 0.0)


## Wings laid back along the body: a landing or a fall.
static func fold(node: Node3D) -> void:
	_pose_wings(node, 1.22, -0.14, Vector3(0.52, 1.0, 0.72))


## A corpse: the wings have dropped half open and lie slack.
static func slump(node: Node3D) -> void:
	_pose_wings(node, 0.34, 0.11, Vector3(0.82, 1.0, 1.0))


static func _pose_wings(node: Node3D, sweep_back: float, droop_z: float, wing_scale: Vector3) -> void:
	var left := node.get_node_or_null("WingL") as Node3D
	var right := node.get_node_or_null("WingR") as Node3D
	if left == null or right == null:
		return
	left.rotation = Vector3(0.0, sweep_back, droop_z)
	right.rotation = Vector3(0.0, -sweep_back, -droop_z)
	left.scale = wing_scale
	right.scale = wing_scale


## A burst of dark loose feathers where a round struck. It frees itself.
static func feather_puff(parent: Node3D, at: Vector3, amount: int = 14) -> void:
	_ensure_shared()
	if _puff_mesh == null:
		var flake := StandardMaterial3D.new()
		flake.albedo_color = FLIGHT_COLOR
		flake.cull_mode = BaseMaterial3D.CULL_DISABLED
		flake.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_puff_mesh = QuadMesh.new()
		_puff_mesh.size = Vector2(0.09, 0.17)
		_puff_mesh.material = flake
	var p := CPUParticles3D.new()
	p.name = "Feathers"
	p.mesh = _puff_mesh
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 2.2
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, -1.5, 0.0)
	p.damping_min = 1.2
	p.damping_max = 2.2
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.create_tween().tween_callback(p.queue_free).set_delay(2.6)


static func wing_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Leading edge, trailing edge, and the arm between them. Shoulder at the origin, spread along +X.
	var lead: Array = [Vector3(0.0, 0.0, -0.17), Vector3(0.48, 0.015, -0.13), Vector3(0.88, 0.030, -0.04), Vector3(1.20, 0.028, 0.10)]
	var trail: Array = [Vector3(0.0, 0.0, 0.30), Vector3(0.55, 0.0, 0.34), Vector3(0.98, 0.012, 0.31), Vector3(1.20, 0.020, 0.20)]
	for i in 3:
		_tri(st, lead[i], trail[i], trail[i + 1])
		_tri(st, lead[i], trail[i + 1], lead[i + 1])
	# The five splayed primary fingers at the tip.
	for j in 5:
		var root_x: float = 0.83 + float(j) * 0.018
		var tip_x: float = 1.16 + float(j) * 0.020
		var back_z: float = 0.16 + float(j) * 0.050
		_tri(st, Vector3(root_x, 0.01, 0.20 + float(j) * 0.018), Vector3(tip_x, 0.01, back_z), Vector3(root_x + 0.02, 0.01, 0.29 + float(j) * 0.018))
	return st.commit()


static func primaries_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A pale band under the fingers, slightly lower so it reads as the underside of the same wing.
	for j in 5:
		var x0: float = 0.86 + float(j) * 0.018
		var x1: float = 1.18 + float(j) * 0.020
		_tri(st, Vector3(x0, -0.006, 0.18 + float(j) * 0.018), Vector3(x1, -0.006, 0.17 + float(j) * 0.050), Vector3(x0 + 0.02, -0.006, 0.28 + float(j) * 0.018))
	return st.commit()


static func tail_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hub := Vector3(0.0, 0.0, 0.0)
	var tips: Array = [Vector3(-0.22, 0.0, 0.28), Vector3(-0.12, 0.0, 0.34), Vector3(0.0, 0.0, 0.37), Vector3(0.12, 0.0, 0.34), Vector3(0.22, 0.0, 0.28)]
	for i in 4:
		_tri(st, hub, tips[i], tips[i + 1])
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Wings are seen from above and below: give both faces the up normal and rely on the two-sided material.
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.add_vertex(c)
