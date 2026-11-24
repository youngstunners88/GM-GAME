extends Node3D
## THE STOCKPILE'S WORKERS (founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21): five MPFB2 townsmen (CC0, mpfb_folk.gd) at work in
## and around the open depot behind Bldg_F, plus the Reserve's one inspect. Built by the town chamber (gold_town.gd) when the streamed
## extras are mounted; loaded by path, no class_name.
##   - one shovels gold nuggets from a heap into the crates beside it (five, not six: the streamed pack's room, 2026-11-21) (Dig, the shovel laid along both hands every frame),
##   - two push loaded wheelbarrows on a fixed loop between the back-lot miners' ore pile and the depot yard: Walk, both hands on the
##     grips (Ep2ArmIK), the wheel turns with the distance rolled, the barrow is set down on its legs whenever he stops, the load is
##     on from the ore pile to the yard and gone after he tips it,
##   - one weighs at the platform scale (Lift), one tends the fire (Tend).
## Common sense (ep2-world-common-sense): every body and barrow is a solid circle in the town's props list (moved with them), a
## barrow stops when anyone stands in its way, nobody's loop crosses a wall or another worker, and gunfire makes them all stop, set
## down what they carry and look toward it before going back to work (notify_danger, called beside the miners').
## Atmosphere only: no numbers, fees or timers.

const SITE := preload("res://src/episode2/extras/stockpile/stockpile_site.gd")
const FOLK := preload("res://src/episode2/extras/folk_mpfb/mpfb_folk.gd")

const BODY_R := 0.42
const BARROW_R := 0.5
const DANGER_HOLD := 7.0
const DIRT := Color(0.84, 0.77, 0.68)
const PUSH_SPEED := 0.9                  # m/s: the Walk clip's own stride (retarget: 0.908 m/s), so the feet do not slide
const LEAD := 1.65                       # from his feet to the barrow's axle along the path: the grips just ahead of his hips
const WHEEL_R := 0.22
const LOAD_HOLD := 4.0
const TIP_HOLD := 3.0
const RESERVE_REACH := 1.9
const RESERVE_LINE := "THE RESERVE. Stone and iron, sealed shut - what the town puts by is kept back here until it is needed."

## The wheelbarrow loop in the Stockpile's frame (x along the front, +z out into the yard; the back-lot miners are at x ~ -24..-30).
## Loaded from the ore pile (A) up the near lane to the yard (E, tipped there), back by the outer lane. Checked against every wall,
## blocker and worker by tests/ep2_stockpile_test.
## The U-turn is on the yard's west side: the fallen rail lies east of it, the fire pit south of the near lane.
const LOOP_LOCAL: Array = [Vector2(-23.6, 4.2), Vector2(-16.0, 5.8), Vector2(-8.0, 5.8), Vector2(-4.4, 5.8), Vector2(-3.8, 7.0),
	Vector2(-6.0, 8.4), Vector2(-16.0, 8.4), Vector2(-23.0, 6.6)]
const LOAD_AT := 0
const TIP_AT := 3
## [id, height, station (local x, z), work point (local), clip, tool]
const STATIONS: Array = [
	["sp_shovel_a", 1.78, Vector2(2.55, 5.15), Vector2(3.6, 6.0), "Dig", "shovel"],
	["sp_weigher", 1.70, Vector2(-3.2, 3.15), Vector2(-3.2, 2.25), "Lift", ""],
	["sp_fire", 1.68, Vector2(-7.2, 2.75), Vector2(-6.05, 3.97), "Tend", ""],
]
const BARROWS: Array = [["sp_barrow_a", 1.80, 0.0], ["sp_barrow_b", 1.76, 0.5]]      # [id, height, start phase along the loop]
const HEAP := Vector2(3.6, 6.0)
const CRATES: Array = [Vector2(4.95, 5.0), Vector2(2.35, 7.0)]

class Worker:
	var folk: Ep2TownFolk
	var id: String = ""
	var clip: String = "Idle"
	var work: Vector3 = Vector3.ZERO
	var tool: Node3D = null
	var rest: Vector3 = Vector3.ZERO
	var circle: Array = []                       # the live [Vector2, r] entry in the town's props list
	var alert_t: float = 0.0
	var danger: Vector3 = Vector3.ZERO
	var skel: Skeleton3D = null
	var hand_l: int = -1
	var hand_r: int = -1
	# a barrow pusher
	var barrow: Node3D = null
	var wheel: Node3D = null
	var load_node: Node3D = null
	var grips: Array = []
	var ik: Dictionary = {}
	var s: float = 0.0
	var hold: float = 0.0
	var loaded: bool = false
	var lift: float = 0.0
	var spin: float = 0.0
	var barrow_circle: Array = []
	var axle: Vector3 = Vector3.ZERO             # where the wheel stands (kept while the barrow rests on its legs)
	var grip_mid: Vector3 = Vector3.ZERO         # the grips' midpoint in the barrow's frame, standing on its legs
	var shoulder_h: float = 1.4                  # his shoulder joint above his feet, and his arm's reach (from his own rest pose)
	var reach: float = 0.55

var workers: Array = []
var circles: Array = []                          # every live circle this node owns (all also in the town's props list)
var _loop: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()
var _loop_len: float = 0.0
var _town: Node = null
var _prompt_shown: bool = false
var inspected: int = 0


## Build the workers into this node (already in the tree). `props` is the town's collision list; `town` the chamber (player position,
## HUD, player control) or null in a test. Returns how many workers stand.
func build(props: Array, town: Node = null) -> int:
	_town = town
	for c in get_children():
		c.queue_free()
	workers.clear()
	circles.clear()
	if not SITE.stockpile_drawn:
		return 0
	_build_loop()
	var kit: Node3D = (load(SITE.KIT) as PackedScene).instantiate() as Node3D if ResourceLoader.exists(SITE.KIT) else null
	if kit != null:
		var heap: Node3D = _copy(kit, "NuggetHeap")
		if heap != null:
			heap.position = _w(HEAP)
			heap.rotation.y = 0.7
			add_child(heap)
		props.append([_xz(_w(HEAP)), 0.75])
	for c in CRATES:
		var cr: Node3D = Ep2GoldTown._glb(self, Ep2GoldTown.CRATE, _w(c), float(c.x), 1.0)
		if cr != null:
			props.append([_xz(_w(c)), 0.5])
	props.append([_xz(_w(Vector2(SITE.FIRE_PIT.x, SITE.FIRE_PIT.z))), 1.05])      # the pit ring is too low to be in the model's blockers
	var rng := RandomNumberGenerator.new()
	rng.seed = 1121
	for row in STATIONS:
		var w := _make(str(row[0]), float(row[1]), _w(row[2]), props, rng)
		if w == null:
			continue
		w.work = _w(row[3])
		w.folk.face_point(w.work)
		w.folk.rotation.y = w.folk.facing
		w.clip = str(row[4])
		w.folk.hold_clip(w.clip)
		_desync(w.folk, rng)
		if str(row[5]) == "shovel" and kit != null:
			w.tool = _copy(kit, "Shovel")
			if w.tool != null:
				w.tool.top_level = true
				w.folk.add_child(w.tool)
				w.rest = w.folk.position + (w.work - w.folk.position).normalized() * 0.45 + Vector3(0.25, 0.0, 0.0)
	for row in BARROWS:
		var start: float = float(row[2]) * _loop_len
		var w := _make(str(row[0]), float(row[1]), _at(start), props, rng)
		if w == null:
			continue
		w.s = start
		w.loaded = start < _tip_s()
		if kit != null:
			w.barrow = _copy(kit, "Wheelbarrow")
		if w.barrow != null:
			add_child(w.barrow)
			w.wheel = w.barrow.find_child("Wheel", true, false) as Node3D
			w.load_node = w.barrow.find_child("Load", true, false) as Node3D
			for g in ["Grip_L", "Grip_R"]:
				w.grips.append(w.barrow.find_child(g, true, false))
			w.ik = FOLK.arm_iks(w.folk)
			if w.grips.size() == 2 and w.grips[0] != null and w.grips[1] != null:
				w.grip_mid = ((w.grips[0] as Node3D).position + (w.grips[1] as Node3D).position) * 0.5
			_measure_arm(w)
			w.barrow_circle = [Vector2.ZERO, BARROW_R]
			props.append(w.barrow_circle)
			circles.append(w.barrow_circle)
		w.clip = "Walk"
		w.folk.hold_clip("Walk")
		_place_barrow(w, 0.0)
	if kit != null:
		kit.free()
	return workers.size()


func _make(id: String, h: float, at: Vector3, props: Array, rng: RandomNumberGenerator) -> Worker:
	var f: Ep2TownFolk = FOLK.make(self, id, h, Ep2GoldTown.ground_y)
	if f == null:
		return null
	f.clip_blend = 0.25
	_dirty(f.model)
	f.place(at)
	var w := Worker.new()
	w.id = id
	w.folk = f
	w.skel = FOLK.skeleton(f)
	w.hand_l = FOLK.bone(f, "LeftHand")
	w.hand_r = FOLK.bone(f, "RightHand")
	w.circle = [_xz(at), BODY_R]
	props.append(w.circle)
	circles.append(w.circle)
	workers.append(w)
	return w


var _shouted: Dictionary = {}
var last_shout: String = ""
## A shot or a fight near the depot: everyone stops, sets down what he carries and looks toward it, then goes back to work.
func notify_danger(where: Vector3, radius: float = 40.0) -> void:
	for w in workers:
		if Vector2(w.folk.position.x - where.x, w.folk.position.z - where.z).length() > radius:
			continue
		w.alert_t = DANGER_HOLD
		w.danger = where
	last_shout = Ep2TownPeople.shout_from(workers.map(func(w) -> Node3D: return w.folk), where, "shot", _shouted)   # P3-E


func _process(delta: float) -> void:
	for w in workers:
		if not is_instance_valid(w.folk):
			continue
		if w.barrow != null:
			_step_barrow(w, delta)
		else:
			if w.alert_t > 0.0:
				w.alert_t -= delta
				w.folk.face_point(w.danger)
				w.folk.hold_clip("Idle")
				if w.alert_t <= 0.0:
					w.folk.face_point(w.work)
					w.folk.hold_clip(w.clip)
			w.folk.step(delta)
			if w.tool != null:
				_lay_shovel(w)
		w.circle[0] = Vector2(w.folk.position.x, w.folk.position.z)
	_step_reserve()


## Pushing: progress along the loop unless someone (Lil Blunt, another worker or barrow) stands in the way of the wheel; dwell at the
## ore pile (loaded) and in the yard (tipped). On alert he stops where he is, sets the barrow down, lets go and looks.
func _step_barrow(w: Worker, delta: float) -> void:
	var moving: bool = false
	if w.alert_t > 0.0:
		w.alert_t -= delta
		w.folk.face_point(w.danger)
	elif w.hold > 0.0:
		w.hold -= delta
		if w.hold <= 0.0:
			w.s = fmod(w.s + 0.05, _loop_len)        # past the stop, on his way
	else:
		var nose: Vector3 = _at(w.s + LEAD + 0.9)
		if not _blocked(w, nose):
			var before: float = w.s
			w.s += PUSH_SPEED * delta
			for stop in [[_load_s(), true], [_tip_s(), false]]:
				var at: float = float(stop[0])
				if _crossed(before, w.s, at):
					w.s = at
					w.hold = LOAD_HOLD if bool(stop[1]) else TIP_HOLD
					w.loaded = bool(stop[1])
			w.s = fmod(w.s, _loop_len)
			w.spin -= (PUSH_SPEED * delta) / WHEEL_R
			moving = w.hold <= 0.0
	var holding: bool = w.alert_t <= 0.0 and w.hold <= 0.0
	w.lift = move_toward(w.lift, _lift_for(w) if holding else 0.0, delta * 0.8)
	var at: Vector3 = _at(w.s)
	w.folk.position.x = at.x
	w.folk.position.z = at.z
	if w.alert_t <= 0.0:
		w.folk.face_point(_at(w.s + LEAD))
	w.folk.hold_clip("Walk" if moving else "Idle")
	w.folk.step(delta)
	_place_barrow(w, delta, holding)
	for side in w.ik:
		var ik: Ep2ArmIK = w.ik[side]
		var g: Node3D = w.grips[0 if side == "Left" else 1]
		ik.reaching = holding and g != null
		ik.influence = move_toward(ik.influence, 1.0 if holding else 0.0, delta * 3.0)
		if g != null:
			ik.target_world = g.global_position
	w.barrow_circle[0] = _xz(w.barrow.position) if w.barrow != null else Vector2.ZERO


## THE BARROW FOLLOWS HIS HANDS: its grips go where his arms naturally hold them (a little ahead of him, arms angled down), the wheel
## stays on the ground, so the lift angle and the axle's place follow from that. Set down, it rests on its legs where it stopped.
func _place_barrow(w: Worker, _delta: float, holding: bool = true) -> void:
	if w.barrow == null:
		return
	var feet: Vector3 = _at(w.s)
	var ahead: Vector3 = _at(w.s + LEAD)
	var dir: Vector3 = Vector3(ahead.x - feet.x, 0.0, ahead.z - feet.z)
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	if holding or w.axle == Vector3.ZERO:
		var hold_at: Vector3 = _shoulders(w) + dir * (w.reach * 0.45)
		hold_at.y = 0.0
		var back: float = w.grip_mid.y * sin(w.lift) + w.grip_mid.z * cos(w.lift)          # grips behind the axle (negative)
		w.axle = hold_at - dir * back
	else:
		dir = (Basis(Vector3.UP, w.barrow.rotation.y) * Vector3.BACK).normalized() if w.barrow.rotation != Vector3.ZERO else dir
	var yaw: float = atan2(dir.x, dir.z)
	var y: float = Ep2GoldTown.ground_y(w.axle) + WHEEL_R
	w.barrow.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, w.lift), Vector3(w.axle.x, y, w.axle.z))
	if w.wheel != null:
		w.wheel.rotation.x = w.spin
	if w.load_node != null:
		w.load_node.visible = w.loaded


## Midway between his two shoulder joints, as the clip has them now (the walk carries the chest a little behind the feet).
func _shoulders(w: Worker) -> Vector3:
	var sk: Skeleton3D = w.skel
	var l: int = FOLK.bone(w.folk, "LeftArm")
	var r: int = FOLK.bone(w.folk, "RightArm")
	if sk == null or l < 0 or r < 0:
		return w.folk.global_position
	return ((sk.global_transform * sk.get_bone_global_pose(l)).origin + (sk.global_transform * sk.get_bone_global_pose(r)).origin) * 0.5


## The lift angle that puts the grips at his hands' natural height (shoulder less 0.78 of his reach), wheel on the ground.
func _lift_for(w: Worker) -> float:
	var want: float = w.shoulder_h - w.reach * 0.78 - WHEEL_R
	var lo: float = -0.1
	var hi: float = 0.7
	for i in 18:
		var mid: float = (lo + hi) * 0.5
		if w.grip_mid.y * cos(mid) - w.grip_mid.z * sin(mid) < want:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## His shoulder height and arm reach, from his own rest pose (the MPFB figures differ in build).
func _measure_arm(w: Worker) -> void:
	var sk: Skeleton3D = w.skel
	var arm: int = FOLK.bone(w.folk, "RightArm")
	if sk == null or arm < 0 or w.hand_r < 0:
		return
	var a: Vector3 = (sk.global_transform * sk.get_bone_global_rest(arm)).origin
	var h: Vector3 = (sk.global_transform * sk.get_bone_global_rest(w.hand_r)).origin
	w.shoulder_h = a.y - w.folk.global_position.y
	w.reach = a.distance_to(h) * 0.97


## Someone in the way of the wheel: Lil Blunt, any other worker, any other barrow.
func _blocked(w: Worker, nose: Vector3) -> bool:
	var p := Vector2(nose.x, nose.z)
	if _town != null and "_player_pos" in _town:
		var pp: Vector3 = _town.get("_player_pos")
		if Vector2(pp.x, pp.z).distance_to(p) < 1.1:
			return true
	for o in workers:
		if o == w:
			continue
		if Vector2(o.folk.position.x, o.folk.position.z).distance_to(p) < 1.2:
			return true
		if o.barrow != null and _xz(o.barrow.position).distance_to(p) < 1.3:
			return true
	return false


## The shovel along both hands: the upper hand on the D-grip, the blade beyond the lower one. On alert it is stood beside him.
func _lay_shovel(w: Worker) -> void:
	if w.skel == null or w.hand_l < 0 or w.hand_r < 0:
		return
	var r: Vector3 = (w.skel.global_transform * w.skel.get_bone_global_pose(w.hand_r)).origin
	var l: Vector3 = (w.skel.global_transform * w.skel.get_bone_global_pose(w.hand_l)).origin
	if w.alert_t > 0.0:
		_orient(w.tool, w.rest, Vector3(0.1, 1.0, 0.0).normalized())
		return
	var hi: Vector3 = r if r.y >= l.y else l
	var lo: Vector3 = l if r.y >= l.y else r
	var axis: Vector3 = (hi - lo).normalized() if hi.distance_to(lo) > 0.08 else Vector3.UP
	_orient(w.tool, hi - axis * 1.5, axis)


func _orient(tool: Node3D, origin: Vector3, up: Vector3) -> void:
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	tool.global_transform = Transform3D(Basis(side, up, side.cross(up).normalized()), origin)


## THE RESERVE'S ONE INSPECT: standing at its door, [E] reads the placard (one line, no numbers). The prompt is only set and cleared
## on the way in and out, so it never fights a story beat's own prompt.
func _step_reserve() -> void:
	if _town == null or not SITE.reserve_drawn or not ("_player_pos" in _town):
		return
	var pp: Vector3 = _town.get("_player_pos")
	var spot: Vector3 = SITE.reserve_xform() * SITE.RESERVE_INSPECT
	var near: bool = Vector2(pp.x - spot.x, pp.z - spot.z).length() < RESERVE_REACH and pp.y < 2.0
	if near and _town.has_method("has_player_control") and not _town.has_player_control():
		near = false
	var hud: Node = _town.get("_hud") if "_hud" in _town else null
	if near != _prompt_shown and hud != null:
		hud.set_search_prompt(("Read the placard [E]" if TouchUi.keys_shown() else "Read the placard") if near else "")
		_prompt_shown = near
	if near and Input.is_action_just_pressed("interact"):
		inspect()


func inspect() -> void:
	inspected += 1
	var hud: Node = _town.get("_hud") if _town != null and "_hud" in _town else null
	if hud != null:
		hud.toast(RESERVE_LINE, 4.5)


# ---------------------------------------------------------------- the loop as a closed polyline in world space
func _build_loop() -> void:
	_loop = PackedVector3Array()
	_cum = PackedFloat32Array()
	for p in LOOP_LOCAL:
		_loop.append(_w(p))
	_loop_len = 0.0
	for i in _loop.size():
		_cum.append(_loop_len)
		_loop_len += _loop[i].distance_to(_loop[(i + 1) % _loop.size()])


func _at(s: float) -> Vector3:
	s = fposmod(s, _loop_len)
	for i in _loop.size():
		var a: Vector3 = _loop[i]
		var b: Vector3 = _loop[(i + 1) % _loop.size()]
		var l: float = a.distance_to(b)
		if s <= _cum[i] + l or i == _loop.size() - 1:
			var p: Vector3 = a.lerp(b, clampf((s - _cum[i]) / maxf(l, 0.001), 0.0, 1.0))
			p.y = Ep2GoldTown.ground_y(p)
			return p
	return _loop[0]


func _load_s() -> float:
	return _cum[LOAD_AT]


func _tip_s() -> float:
	return _cum[TIP_AT]


func loop_points() -> PackedVector3Array:
	return _loop


func _crossed(a: float, b: float, at: float) -> bool:
	if b < _loop_len:
		return a < at and b >= at
	return a < at or fposmod(b, _loop_len) >= at


static func _w(p) -> Vector3:
	var v: Vector3 = Vector3(p.x, 0.0, p.y) if p is Vector2 else p
	return SITE.xform() * v


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _copy(kit: Node3D, piece: String) -> Node3D:
	var src: Node3D = kit.find_child(piece, true, false) as Node3D
	if src == null:
		return null
	var n: Node3D = src.duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	SITE.dress(n)
	return n


func _desync(f: Ep2TownFolk, rng: RandomNumberGenerator) -> void:
	var ap: AnimationPlayer = f.anim_player()
	if ap != null and ap.current_animation != "":
		ap.seek(rng.randf_range(0.0, maxf(ap.current_animation_length - 0.1, 0.0)), true)


## Work dirt over the clothes (multiplied onto their own colour, never a colour swap), like the back-lot miners.
func _dirty(root: Node) -> void:
	if root == null:
		return
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var d := src.duplicate() as BaseMaterial3D
			d.albedo_color = src.albedo_color * DIRT
			m.set_surface_override_material(i, d)
