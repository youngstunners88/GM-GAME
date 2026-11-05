class_name Ep2VultureMesh
extends RefCounted
## The trail's turkey vulture, built from real bird proportions instead of a cross of flat triangles: a long body, a small bare red
## head on a short neck, a fan tail, and two shoulder pivots carrying long fingered wings (about 2.5 m tip to tip at scale 1).
##
## The vulture in `ep2_carrion_vultures.gd` and this one now come from the same silhouette. The caller owns motion: `flap()` turns
## the wing pivots, `fold()` lays them along the body for a fall or a landing, and the returned node keeps named pivots
## ("WingL", "WingR", "Neck") for the owner to pose.

const FEATHER_COLOR := Color(0.085, 0.070, 0.058)
const FLIGHT_COLOR := Color(0.17, 0.155, 0.135)
const SKIN_COLOR := Color(0.34, 0.115, 0.080)

static func feather_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = FEATHER_COLOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.92
	return m


static func flight_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = FLIGHT_COLOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	return m


static func skin_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SKIN_COLOR
	m.roughness = 0.80
	return m


## Build one vulture. `scale` is the whole bird; 1.0 gives a ~2.5 m wingspan.
static func build(scale: float = 1.0) -> Node3D:
	var feather := feather_material()
	var flight := flight_material()
	var skin := skin_material()
	var root := Node3D.new()
	root.name = "Vulture"
	root.scale = Vector3.ONE * scale

	# Body: a long ellipsoid, nose toward -Z.
	var body := MeshInstance3D.new()
	body.name = "Body"
	var ball := SphereMesh.new()
	ball.radius = 0.115
	ball.height = 0.62
	ball.radial_segments = 12
	ball.rings = 7
	body.mesh = ball
	body.rotation.x = PI * 0.5 - 0.16
	body.position = Vector3(0.0, 0.02, 0.0)
	body.material_override = feather
	root.add_child(body)

	# A short bare neck and the small red head, held a little forward.
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0.0, 0.06, -0.25)
	root.add_child(neck)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var h := SphereMesh.new()
	h.radius = 0.062
	h.height = 0.16
	h.radial_segments = 8
	h.rings = 5
	head.mesh = h
	head.position = Vector3(0.0, 0.0, -0.10)
	head.material_override = skin
	neck.add_child(head)
	var beak := MeshInstance3D.new()
	beak.name = "Beak"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.030
	cone.height = 0.13
	cone.radial_segments = 7
	beak.mesh = cone
	beak.position = Vector3(0.0, -0.012, -0.21)
	beak.rotation.x = -PI * 0.5
	beak.material_override = skin
	neck.add_child(beak)

	# Fan tail, spread enough to read from below.
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = tail_mesh()
	tail.position = Vector3(0.0, 0.0, 0.27)
	tail.material_override = feather
	root.add_child(tail)

	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var pivot := Node3D.new()
		pivot.name = "WingL" if i == 0 else "WingR"
		pivot.position = Vector3(side * 0.075, 0.055, -0.03)
		pivot.rotation.z = -side * 0.05
		root.add_child(pivot)
		var wing := MeshInstance3D.new()
		wing.name = "Wing"
		wing.mesh = wing_mesh()
		wing.scale = Vector3(side, 1.0, 1.0)
		wing.material_override = feather
		pivot.add_child(wing)
		# The pale trailing primaries are the part that catches the light when he banks.
		var tips := MeshInstance3D.new()
		tips.name = "Primaries"
		tips.mesh = primaries_mesh()
		tips.scale = Vector3(side, 1.0, 1.0)
		tips.material_override = flight
		pivot.add_child(tips)
		var leg := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.012
		stick.bottom_radius = 0.010
		stick.height = 0.17
		stick.radial_segments = 5
		leg.mesh = stick
		leg.material_override = skin
		leg.position = Vector3(side * 0.045, -0.075, 0.10)
		leg.rotation.x = 0.5
		root.add_child(leg)
	return root


## A slow soaring flap. `amount` 0 = wings locked in the glide, 1 = a full downbeat.
static func flap(node: Node3D, phase: float, amount: float, bank: float = 0.0) -> void:
	var left := node.get_node_or_null("WingL") as Node3D
	var right := node.get_node_or_null("WingR") as Node3D
	if left == null or right == null:
		return
	var beat: float = sin(phase) * 0.52 * amount
	var dihedral: float = 0.10 + 0.16 * (1.0 - amount)
	left.rotation.z = dihedral + beat
	right.rotation.z = -dihedral - beat
	left.rotation.x = -0.04 * amount + bank * 0.10
	right.rotation.x = -0.04 * amount + bank * 0.10


## Wings laid back along the body: a fall, a landing, or a corpse.
static func fold(node: Node3D) -> void:
	var left := node.get_node_or_null("WingL") as Node3D
	var right := node.get_node_or_null("WingR") as Node3D
	if left == null or right == null:
		return
	left.rotation = Vector3(0.0, -0.18, 0.10)
	right.rotation = Vector3(0.0, 0.18, -0.10)
	left.scale = Vector3(0.56, 1.0, 1.0)
	right.scale = Vector3(0.56, 1.0, 1.0)


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
