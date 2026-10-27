class_name Ep2LoganSkiff
extends Node3D
## Lake-only skiff routine. The founder's Logan skin/clips stay unchanged.
## A rest-aware two-bone solve keeps palms on independent rigid oar grips and
## boots on the actual footrest. No bone scaling or foreign clip retargeting.
enum State { MOORED, WALK_TO_BOAT, BOARD, ROW }
const MODEL := "res://src/episode2/extras/lake/rowing_skiff.glb"
const WATER_Y := -0.18
const MOOR := Vector3(2.2, -0.15, 13.0)
const STROKE_SECONDS := 2.7
var state: int = State.MOORED
var ready_art: bool = false
var circuit_distance: float = 0.0
var stroke_phase: float = 0.0
var board_blend: float = 0.0
var boat: Node3D
var actor: Ep2TownFolk
var oars: Array[Node3D] = []
var grips: Array[Node3D] = []
var blades: Array[Node3D] = []
var _seat: Node3D
var _floor: Node3D
var _stern: Node3D
var _rope: MeshInstance3D
var _sk: Skeleton3D
var _rest: Dictionary = {}
var _ids: Dictionary = {}
var _palms: Dictionary = {}
var _normals: Dictionary = {}
var _hip_actor := Vector3.ZERO
var _foot_basis_actor: Dictionary = {}
var _lean: float = 0.0
var _water_material: ShaderMaterial
var hull_widths := PackedFloat32Array()
var _shore_mark := Vector3.ZERO
var _time: float = 0.0
var _walk_distance: float = 0.0
var _walk_i: int = 0
var _walk_from: Vector3
var _walk_start_time: float = 0.0
var _board_from: Transform3D
var _board_feet: Array[Vector3] = []
var _route_i: int = 0
var _route: Array[Vector3] = [Vector3(9, 0, 18), Vector3(13, 0, 25), Vector3(8, 0, 31), Vector3(3, 0, 24), Vector3(2.2, 0, 13)]
var _walk_route: Array[Vector3] = [Vector3(-3.4, 0, 10), Vector3(2.2, 0, 10), Vector3(2.2, 0, 11.2), Vector3(2.2, -0.20, 11.9), Vector3(2.2, -0.25, 12.5)]
var _wake: MeshInstance3D

func build(parent: Node3D, logan: Ep2TownFolk, water: ShaderMaterial = null) -> bool:
	_water_material = water
	actor = logan
	if actor != null: _shore_mark = actor.position
	if ready_art or actor == null or not Ep2Extras.has(MODEL): return ready_art
	name = "LogansWorkingSkiff"
	if get_parent() == null: parent.add_child(self)
	boat = (load(MODEL) as PackedScene).instantiate() as Node3D
	boat.name = "RowingSkiff"
	add_child(boat)
	boat.position = MOOR
	_seat = boat.find_child("SeatContact", true, false) as Node3D
	_floor = boat.find_child("FloorContact", true, false) as Node3D
	_stern = boat.find_child("SternMooring", true, false) as Node3D
	for i in 18:
		var marker := boat.find_child("WaterCut_%02d" % i, true, false) as Node3D
		hull_widths.append(marker.position.x if marker != null else 0.0)
	if _water_material != null:
		_water_material.set_shader_parameter("boat_half_width", hull_widths)
		_water_material.set_shader_parameter("boat_present", true)
	for side in ["L", "R"]:
		oars.append(boat.find_child("OarPivot_" + side, true, false) as Node3D)
		grips.append(boat.find_child("GripContact_" + side, true, false) as Node3D)
		blades.append(boat.find_child("BladeContact_" + side, true, false) as Node3D)
	Ep2Pbr.dress(boat, {"LakeCedar": ["planks_weathered", .8, 0.0, 1.0, Color(.17, .095, .04)], "LakeOarGrip": ["leather_brown", .25, 0.0, 1.0]}, [], true)
	_sk = actor.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in _sk.get_bone_count():
		var key: String = str(_sk.get_bone_name(i)).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
		_ids[key] = i
		_rest[key] = _sk.get_bone_global_rest(i)
	_sk.force_update_all_bone_transforms()
	_hip_actor = actor.to_local(_rest_world("Hips").origin)
	for side in ["Left", "Right"]:
		_foot_basis_actor[side] = actor.global_basis.inverse() * _rest_world(side + "Foot").basis
		var hand: Transform3D = _rest[side + "Hand"]
		var index: Vector3 = (_rest[side + "HandIndex1"] as Transform3D).origin
		var pinky: Vector3 = (_rest[side + "HandPinky1"] as Transform3D).origin
		var mid: Vector3 = (index + pinky) * .5
		_palms[side] = hand.affine_inverse() * mid
		var forward: Vector3 = (mid - hand.origin).normalized()
		var normal: Vector3 = forward.cross(index - pinky).normalized()
		if normal.dot(Vector3.BACK) < 0.0: normal = -normal
		_normals[side] = normal
	_rope = MeshInstance3D.new()
	_rope.name = "FittedMooringLine"
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(.38, .29, .15)
	rope_mat.roughness = .95
	_rope.material_override = rope_mat
	add_child(_rope)
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.2, 5.0)
	_wake = MeshInstance3D.new()
	_wake.name = "RowingWake"
	_wake.mesh = plane
	_wake.position = Vector3(0.0, -0.02, -3.4)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://src/episode2/art/lake_wake.gdshader")
	_wake.material_override = wm
	_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boat.add_child(_wake)
	_wake.hide()
	ready_art = true
	_update_mooring()
	return true

func reset_routine() -> void:
	if not ready_art: return
	_sk.clear_bones_global_pose_override()
	state = State.MOORED
	_lean = 0.0
	_time = 0.0
	circuit_distance = 0.0
	_walk_distance = 0.0
	_walk_i = 0
	_route_i = 0
	board_blend = 0.0
	boat.position = MOOR
	boat.rotation = Vector3.ZERO
	_rope.show()
	_wake.hide()
	actor.procedural_bob = false
	actor.stop()
	actor.use_height = true
	actor.place(_shore_mark)
	actor.face_yaw(PI)
	actor.rotation.y = PI
	for oar in oars: oar.rotation = Vector3.ZERO
	_update_mooring()
	_update_water_cut()

func advance(delta: float, may_depart: bool) -> void:
	if not ready_art: return
	_time += delta
	if state == State.MOORED:
		boat.position.y = MOOR.y + sin(_time * .72) * .006
		boat.rotation.z = sin(_time * .62) * .006
		_update_mooring()
		if may_depart:
			state = State.WALK_TO_BOAT
			_walk_from = actor.position
			_walk_start_time = _time
			actor.use_height = true
			actor.procedural_bob = false
			actor.stop()
	elif state == State.WALK_TO_BOAT:
		_walk(delta)
	elif state == State.BOARD:
		board_blend = minf(1.0, board_blend + delta / 1.25)
		_seat_actor(board_blend)
		_pose_seated(board_blend)
		if board_blend >= 1.0:
			state = State.ROW
			_time = 0.0
			_rope.hide()
			_wake.show()
	elif state == State.ROW:
		_row(delta)
	_update_water_cut()

func _walk(delta: float) -> void:
	var target: Vector3 = _walk_route[_walk_i]
	var flat := Vector3(target.x - actor.position.x, 0, target.z - actor.position.z)
	var distance: float = minf(flat.length(), delta * .85)
	if flat.length() > .001:
		var dir: Vector3 = flat.normalized()
		actor.position.x += dir.x * distance
		actor.position.z += dir.z * distance
		_walk_distance += distance
		actor.facing = atan2(dir.x, dir.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, actor.facing, minf(1.0, delta * 5.0))
	var start_ground: float = _walk_from.y
	var segment: float = Vector2(target.x - _walk_from.x, target.z - _walk_from.z).length()
	var left: float = Vector2(target.x - actor.position.x, target.z - actor.position.z).length()
	var ground: float = lerpf(start_ground, target.y, 1.0 - left / maxf(segment, .001))
	actor.position.y = ground - smoothstep(0.0, .4, _time - _walk_start_time) * .055
	actor._floor_y = actor.position.y
	_sk.clear_bones_global_pose_override()
	_sk.force_update_all_bone_transforms()
	var cycle: float = fposmod(_walk_distance / .90, 1.0)
	for j in 2:
		var side: String = "Left" if j == 0 else "Right"
		var p: float = fposmod(cycle + float(j) * .5, 1.0)
		var dz: float = .27 - p * .90 if p < .6 else -.27 * cos(PI * (p - .6) / .4)
		var lift: float = 0.0 if p < .6 else .09 * sin(PI * (p - .6) / .4)
		var foot: Vector3 = _rest_world(side + "Foot").origin
		foot += actor.global_basis * Vector3(0, .055 + lift, dz)
		_solve_chain(side + "UpLeg", side + "Leg", side + "Foot", foot, actor.global_basis * Vector3(0, .2, 1))
		_set_pose_world(side + "Foot", Transform3D(_rest_world(side + "Foot").basis, foot))
	_sk.force_update_all_bone_transforms()
	if left < .03:
		_walk_from = target
		_walk_i += 1
		if _walk_i >= _walk_route.size():
			state = State.BOARD
			_board_from = actor.global_transform
			_board_feet = [_pose_world("LeftFoot").origin, _pose_world("RightFoot").origin]

func _row(delta: float) -> void:
	stroke_phase = fposmod(_time / STROKE_SECONDS, 1.0)
	var power: float = sin(PI * clampf(stroke_phase / .55, 0.0, 1.0))
	var target: Vector3 = _route[_route_i]
	var d := Vector3(target.x - boat.position.x, 0, target.z - boat.position.z)
	var travel: float = minf(d.length(), delta * (.36 + .20 * power))
	if d.length() > .01:
		boat.position += d.normalized() * travel
		boat.rotation.y = lerp_angle(boat.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 1.1))
	circuit_distance += travel
	boat.position.y = MOOR.y + sin(_time * .72) * .007
	boat.rotation.z = sin(_time * .9) * .006
	if d.length() < .08: _route_i = (_route_i + 1) % _route.size()
	var sweep: float = lerpf(-.32, .32, stroke_phase / .55) if stroke_phase < .55 else lerpf(.32, -.32, smoothstep(0.0, 1.0, (stroke_phase - .55) / .45))
	_lean = -sweep * .30
	var recovery: float = 0.0 if stroke_phase < .55 else sin(PI * (stroke_phase - .55) / .45)
	for i in 2:
		var sign_side: float = -1.0 if i == 0 else 1.0
		oars[i].rotation = Vector3(0.0, sign_side * sweep, -sign_side * lerpf(.24, .07, recovery))
	_seat_actor(1.0)
	_pose_seated(1.0)

func _seat_actor(blend: float) -> void:
	var basis: Basis = boat.global_basis * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, _lean)
	var desired: Vector3 = _seat.global_position + boat.global_basis * Vector3(0, .12, 0) - basis * _hip_actor
	var k: float = smoothstep(0.0, 1.0, blend)
	actor.global_basis = Basis(Quaternion(_board_from.basis.orthonormalized()).slerp(Quaternion(basis.orthonormalized()), k)) if blend < 1.0 else basis
	actor.global_position = _board_from.origin.lerp(desired, k) if blend < 1.0 else desired
	actor.facing = actor.rotation.y
	actor._floor_y = actor.position.y

func _rest_world(key: String) -> Transform3D:
	return _sk.global_transform * (_rest[key] as Transform3D)

func _pose_world(key: String) -> Transform3D:
	return _sk.global_transform * _sk.get_bone_global_pose(int(_ids[key]))

func _set_pose_world(key: String, pose: Transform3D) -> void:
	_sk.set_bone_global_pose_override(int(_ids[key]), _sk.global_transform.affine_inverse() * pose, 1.0, true)
	_sk.force_update_all_bone_transforms()

func _segment(key: String, child: String, from: Vector3, to: Vector3) -> void:
	var rest: Transform3D = _rest_world(key)
	var vector: Vector3 = _rest_world(child).origin - rest.origin
	var turn := Quaternion(vector.normalized(), (to - from).normalized())
	_set_pose_world(key, Transform3D(Basis(turn) * rest.basis, from))

func _solve_chain(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var h: Vector3 = _pose_world(upper).origin
	var a: Vector3 = _rest_world(upper).origin
	var b: Vector3 = _rest_world(lower).origin
	var c: Vector3 = _rest_world(end).origin
	var l1: float = a.distance_to(b)
	var l2: float = b.distance_to(c)
	var d: Vector3 = target - h
	var length: float = minf(d.length(), l1 + l2 - .001)
	var axis: Vector3 = d.normalized()
	var mid: float = (l1 * l1 - l2 * l2 + length * length) / (2 * maxf(.001, length))
	var radius: float = sqrt(maxf(0.0, l1 * l1 - mid * mid))
	var perpendicular: Vector3 = (pole - axis * pole.dot(axis)).normalized()
	var joint: Vector3 = h + axis * mid + perpendicular * radius
	var reachable: Vector3 = h + axis * length
	_segment(upper, lower, h, joint)
	_segment(lower, end, joint, reachable)

func _pose_seated(blend: float) -> void:
	_sk.clear_bones_global_pose_override()
	_sk.force_update_all_bone_transforms()
	var k: float = smoothstep(0.0, 1.0, blend)
	for i in 2:
		var side: String = "Left" if i == 0 else "Right"
		# Source anatomical left is +X; Logan faces the stern while rowing.
		var actor_x: float = actor.to_local(_rest_world(side + "Foot").origin).x
		var boat_sign: float = -1.0 if actor_x > 0 else 1.0
		var foot: Vector3 = _floor.global_position + boat.global_basis * Vector3(boat_sign * .15, .12, 0)
		if k < 1.0:
			var center: Vector3 = (_board_feet[0] + _board_feet[1]) * .5
			var end_center: Vector3 = _floor.global_position + boat.global_basis * Vector3(0, .12, 0)
			var offset: Vector3 = _board_feet[i] - center
			offset = offset.normalized() * lerpf(offset.length(), .15, k)
			foot = center.lerp(end_center, k) + Basis(Vector3.UP, PI * k) * offset
		_solve_chain(side + "UpLeg", side + "Leg", side + "Foot", foot, actor.global_basis * Vector3(0, .2, 1))
		var flat_basis: Basis = actor.global_basis * Basis(Vector3.RIGHT, -_lean) * (_foot_basis_actor[side] as Basis)
		_set_pose_world(side + "Foot", Transform3D(flat_basis, foot))
		var grip_i: int = 0 if boat_sign < 0 else 1
		var hand_rest: Transform3D = _rest_world(side + "Hand")
		var local_palm: Vector3 = _palms[side]
		var middle: Transform3D = _rest_world(side + "HandMiddle1")
		var axis: Vector3 = (middle.origin - hand_rest.origin).normalized()
		var finger_dir: Vector3 = boat.global_basis * Vector3(0, 0, -1)
		var q := Quaternion(axis, finger_dir)
		var normal: Vector3 = (_sk.global_basis * (_normals[side] as Vector3)).normalized()
		var mapped: Vector3 = q * normal
		var wanted: Vector3 = -boat.global_basis.y.normalized()
		var twist: float = atan2(finger_dir.dot(mapped.cross(wanted)), mapped.dot(wanted))
		q = Quaternion(finger_dir, twist) * q
		var hand_basis: Basis = Basis(q) * hand_rest.basis
		var grip: Vector3 = grips[grip_i].global_position
		var current_palm: Vector3 = _pose_world(side + "Hand") * local_palm
		var palm: Vector3 = current_palm.lerp(grip, k)
		var wrist: Vector3 = palm - hand_basis * local_palm
		_solve_chain(side + "Arm", side + "ForeArm", side + "Hand", wrist, actor.global_basis * Vector3(signf(actor_x), -.2, .15))
		# Keep the solved wrist (never stretch the forearm to an unreachable prop).
		var solved: Vector3 = _pose_world(side + "Hand").origin
		_set_pose_world(side + "Hand", Transform3D(hand_basis, solved))
		for finger in ["Index", "Middle", "Ring", "Pinky"]:
			for joint in range(1, 4):
				var key: String = side + "Hand" + finger + str(joint)
				var child: String = side + "Hand" + finger + str(joint + 1)
				var rest: Transform3D = _rest[key]
				var direction: Vector3 = ((_rest[child] as Transform3D).origin - rest.origin).normalized()
				var hinge: Vector3 = direction.cross(_normals[side]).normalized()
				var local_axis: Vector3 = rest.basis.inverse() * hinge
				var id: int = int(_ids[key])
				var local_pose: Transform3D = _sk.get_bone_rest(id)
				local_pose.basis = local_pose.basis * Basis(Quaternion(local_axis.normalized(), [.48, .85, .75][joint - 1] * k))
				var parent_id: int = _sk.get_bone_parent(id)
				_sk.set_bone_global_pose_override(id, _sk.get_bone_global_pose(parent_id) * local_pose, 1.0, true)
				_sk.force_update_all_bone_transforms()
	_sk.force_update_all_bone_transforms()

func palm_position(side: String) -> Vector3:
	return _pose_world(side + "Hand") * (_palms[side] as Vector3)

func seat_error() -> float:
	return _pose_world("Hips").origin.distance_to(_seat.global_position + boat.global_basis * Vector3(0, .12, 0))

func _update_mooring() -> void:
	var a := Vector3(3.4, .17, 10.0)
	var b: Vector3 = to_local(_stern.global_position)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var p: Vector3 = a.lerp(b, float(i) / 20.0) + Vector3(0, -.14 * sin(PI * float(i) / 20.0), 0)
		var q: Vector3 = a.lerp(b, float(i + 1) / 20.0) + Vector3(0, -.14 * sin(PI * float(i + 1) / 20.0), 0)
		var w := Vector3(.009, 0, 0)
		for v in [p-w, q+w, q-w, p-w, p+w, q+w]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	_rope.mesh = st.commit()

func _update_water_cut() -> void:
	if _water_material != null and boat != null:
		_water_material.set_shader_parameter("boat_inverse", boat.global_transform.affine_inverse())
