class_name Ep2DrinkPose
extends RefCounted
## SITTING AND DRINKING (founder 2026-10-24: "sitting and drinking in the saloon as well as the balcony above"; skill ep2-saloon-drinkers).
##
## The townsfolk rigs (Meshy auto-rig: Hips, Spine02/01/Spine, neck, Head, *Shoulder/*Arm/*ForeArm/*Hand, *UpLeg/*Leg/*Foot) carry only
## standing clips. Rather than re-export thirteen founder-approved models, the drink clips are BUILT IN THE ENGINE from each person's own
## skeleton: aim each bone (shortest arc from its rest direction) at a target direction in the character's frame, solve the drinking arm
## with a two-bone reach to a point (the table, then the mouth), and key the result as an ordinary looping Animation. Nothing about the
## model changes; the clip only exists while the game runs.
##   SitDrink   - seated on a chair (thighs forward, shins down, hips at seat height), glass resting on the table, raised to the mouth.
##   StandDrink - standing at the rail (legs as at rest), glass held at the chest, raised to the mouth.

const SEAT_TOP := 0.46          # Bar_Chair seat height (m)
const TABLE_TOP := 0.79         # Bar_Table top (m)
const LOOP := 6.4               # seconds per sip
## [time, glass target]: "rest" = on the table / at the chest, "mouth" = at the lips
const BEATS: Array = [[0.0, "rest"], [2.2, "rest"], [2.9, "mouth"], [3.8, "mouth"], [4.6, "rest"], [6.4, "rest"]]


## Build `name` ("SitDrink" or "StandDrink") for `skel` and add it to `player`'s default library. `fwd` / `up` are the character's
## forward and up IN SKELETON SPACE; `unit` = metres per skeleton unit (the model's scale). Returns false when the rig lacks the bones.
static func install(player: AnimationPlayer, skel: Skeleton3D, fwd: Vector3, up: Vector3, unit: float, seated: bool) -> bool:
	var need := ["Hips", "Spine", "Head", "RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand",
		"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
	var idx := {}
	for n in need:
		var i: int = _find(skel, n)
		if i < 0:
			return false
		idx[n] = i
	fwd = fwd.normalized()
	up = (up - fwd * up.dot(fwd)).normalized()
	var right: Vector3 = fwd.cross(up).normalized()          # the character's own right: facing +z with +y up, that is -x
	var poses: Array = []                                     # one {bone: Quaternion} per beat, plus the hips position
	for beat in BEATS:
		poses.append(_solve(skel, idx, fwd, up, right, unit, seated, str(beat[1]) == "mouth"))
	var anim := Animation.new()
	anim.length = LOOP
	anim.loop_mode = Animation.LOOP_LINEAR
	var root: Node = player.get_node(player.root_node)
	var path: String = str(root.get_path_to(skel))
	var bones: Array = poses[0]["rot"].keys()
	for b in bones:
		var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [path, skel.get_bone_name(b)]))
		for k in BEATS.size():
			anim.rotation_track_insert_key(t, float(BEATS[k][0]), poses[k]["rot"][b])
	var tp: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(tp, NodePath("%s:%s" % [path, skel.get_bone_name(idx["Hips"])]))
	for k in BEATS.size():
		anim.position_track_insert_key(tp, float(BEATS[k][0]), poses[k]["hips_pos"])
	var lib: AnimationLibrary = player.get_animation_library("") if player.has_animation_library("") else null
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	var name: String = "SitDrink" if seated else "StandDrink"
	if lib.has_animation(name):
		lib.remove_animation(name)
	lib.add_animation(name, anim)
	return true


## Seeded saloon variant used by the ambient cast. The compatibility entry point above still builds the original
## 6.4-second clip; this one gives a person their own 5.0-8.5-second sip, idle, laugh and tobacco-smoke clips.
## Every animation carries its mouth/exhale times as metadata so the performance controller can synchronise sound
## and smoke even when the clip was started part-way through its loop.
static func install_variant(player: AnimationPlayer, skel: Skeleton3D, fwd: Vector3, up: Vector3, unit: float, seated: bool, seed_value: int) -> bool:
	var need := ["Hips", "Spine", "Head", "RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand",
		"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
	var idx := {}
	for n in need:
		var i: int = _find(skel, n)
		if i < 0:
			return false
		idx[n] = i
	for shoulder in ["LeftShoulder", "RightShoulder"]:
		var i: int = _find(skel, shoulder)
		if i >= 0:
			idx[shoulder] = i
	fwd = fwd.normalized()
	up = (up - fwd * up.dot(fwd)).normalized()
	var right: Vector3 = fwd.cross(up).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var prefix: String = "Sit" if seated else "Stand"
	var glass_lift: float = rng.randf_range(-0.025, 0.035)
	var length: float = rng.randf_range(5.0, 8.5)
	var a: float = length * rng.randf_range(0.25, 0.34)
	var b: float = a + length * rng.randf_range(0.08, 0.12)
	var c: float = b + length * rng.randf_range(0.12, 0.18)
	var d: float = c + length * rng.randf_range(0.08, 0.12)
	var sip: Array = [[0.0, false, 0.0], [a, false, 0.0], [b, true, 0.0], [c, true, 0.0], [d, false, 0.0], [length, false, 0.0]]
	if not _bake_variant(player, skel, idx, fwd, up, right, unit, seated, prefix + "Drink", length, sip, "sip", glass_lift, [b], []):
		return false
	var idle: Array = [[0.0, false, 0.0], [2.0, false, 0.0]]
	_bake_variant(player, skel, idx, fwd, up, right, unit, seated, prefix + "Idle", 2.0, idle, "idle", glass_lift, [], [])
	var laugh_length: float = rng.randf_range(1.6, 2.3)
	var laugh: Array = []
	var shakes: Array = [0.0, 1.0, -1.0, 0.85, -0.7, 0.0]
	for k in shakes.size():
		laugh.append([laugh_length * float(k) / 5.0, false, float(shakes[k])])
	_bake_variant(player, skel, idx, fwd, up, right, unit, seated, prefix + "Laugh", laugh_length, laugh, "laugh", glass_lift, [laugh_length * 0.18], [])
	var smoke_length: float = rng.randf_range(4.8, 6.4)
	var inhale: float = smoke_length * 0.28
	var exhale: float = smoke_length * 0.58
	var smoke: Array = [[0.0, false, 0.0], [inhale * 0.55, false, 0.0], [inhale, true, 0.0],
		[smoke_length * 0.43, true, 0.0], [exhale, false, 0.0], [smoke_length, false, 0.0]]
	_bake_variant(player, skel, idx, fwd, up, right, unit, seated, prefix + "Smoke", smoke_length, smoke, "smoke", glass_lift, [inhale], [exhale])
	return true


## Bake one variant action. A beat is [seconds, free-hand/glass-at-mouth, laugh-shake].
static func _bake_variant(player: AnimationPlayer, skel: Skeleton3D, idx: Dictionary, fwd: Vector3, up: Vector3, right: Vector3,
		unit: float, seated: bool, clip_name: String, length: float, beats: Array, action: String, glass_lift: float, mouths: Array, exhales: Array) -> bool:
	var poses: Array = []
	for beat in beats:
		poses.append(_solve(skel, idx, fwd, up, right, unit, seated, bool(beat[1]), action, glass_lift, float(beat[2])))
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.set_meta("mouth_times", mouths.duplicate())
	anim.set_meta("exhale_times", exhales.duplicate())
	var root: Node = player.get_node(player.root_node)
	var path: String = str(root.get_path_to(skel))
	var bones: Array = poses[0]["rot"].keys()
	for bone in bones:
		var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [path, skel.get_bone_name(int(bone))]))
		for k in beats.size():
			anim.rotation_track_insert_key(t, float(beats[k][0]), poses[k]["rot"][bone])
	var tp: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(tp, NodePath("%s:%s" % [path, skel.get_bone_name(idx["Hips"])]))
	for k in beats.size():
		anim.position_track_insert_key(tp, float(beats[k][0]), poses[k]["hips_pos"])
	var lib: AnimationLibrary = player.get_animation_library("") if player.has_animation_library("") else null
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	if lib.has_animation(clip_name):
		lib.remove_animation(clip_name)
	lib.add_animation(clip_name, anim)
	return true


static func _find(skel: Skeleton3D, n: String) -> int:
	var want: String = n.to_lower()
	for i in skel.get_bone_count():
		var have: String = skel.get_bone_name(i).to_lower()
		if have == want or have.ends_with(":" + want) or have.ends_with("_" + want):
			return i
	return -1


## One beat's pose. Forward kinematics over the rest skeleton with our local rotations, so every aim is computed against the
## already-posed parent (hips first, then spine, legs, arms).
static func _solve(skel: Skeleton3D, idx: Dictionary, fwd: Vector3, up: Vector3, right: Vector3, unit: float, seated: bool, at_mouth: bool,
		action: String = "sip", glass_lift: float = 0.0, shake: float = 0.0) -> Dictionary:
	var local_rot: Dictionary = {}
	for i in skel.get_bone_count():
		local_rot[i] = skel.get_bone_rest(i).basis.get_rotation_quaternion()
	var hips_pos: Vector3 = skel.get_bone_rest(idx["Hips"]).origin
	if seated:
		# hips down onto the seat and a hand's width back
		var floor_y: float = 0.0
		hips_pos = hips_pos - up * (hips_pos.dot(up) - floor_y - (SEAT_TOP + 0.07) / unit) - fwd * (0.04 / unit)
	var G := func(i: int) -> Transform3D: return _global(skel, i, local_rot, hips_pos, idx["Hips"])
	# spine: a little forward over the table (seated) / upright with a slight lean on the rail (standing)
	var lean: float = 0.12 if seated else 0.05
	if action == "laugh":
		lean = (-0.16 if seated else -0.10) + shake * 0.025       # back from the table, not another sip
	_tilt(skel, idx["Spine"], local_rot, G, right, lean)
	if seated:
		for side in ["Left", "Right"]:
			var s: float = -1.0 if side == "Left" else 1.0
			_aim(skel, idx[side + "UpLeg"], local_rot, G, (fwd * 1.0 - up * 0.12 + right * s * 0.08).normalized())
			_aim(skel, idx[side + "Leg"], local_rot, G, (-up * 1.0 + fwd * 0.08).normalized())
			_aim(skel, idx[side + "Foot"], local_rot, G, (fwd * 1.0 - up * 0.35).normalized())
	if action == "laugh":
		_tilt(skel, idx["Head"], local_rot, G, right, 0.24 + shake * 0.055)   # chin up
		for side in ["Left", "Right"]:
			var key: String = side + "Shoulder"
			if idx.has(key):
				var s: float = -1.0 if side == "Left" else 1.0
				_tilt(skel, idx[key], local_rot, G, fwd, shake * s * 0.075)  # alternating shoulder shake
	# the free (left) arm: forearm resting forward on the table / hanging easy
	if seated:
		_aim(skel, idx["LeftArm"], local_rot, G, (-up * 0.75 + fwd * 0.55 - right * 0.12).normalized())
		_aim(skel, idx["LeftForeArm"], local_rot, G, (fwd * 1.0 + right * 0.25 - up * 0.05).normalized())
	else:
		_aim(skel, idx["LeftArm"], local_rot, G, (-up * 1.0 + fwd * 0.12 - right * 0.1).normalized())
		_aim(skel, idx["LeftForeArm"], local_rot, G, (-up * 0.85 + fwd * 0.4).normalized())
	# the drinking (right) arm: two-bone reach to the glass target
	var shoulder: Vector3 = (G.call(idx["RightArm"]) as Transform3D).origin
	var a: float = skel.get_bone_rest(idx["RightForeArm"]).origin.length()
	var b: float = skel.get_bone_rest(idx["RightHand"]).origin.length()
	var target: Vector3
	var head: Vector3 = (G.call(idx["Head"]) as Transform3D).origin
	if at_mouth and action == "sip":
		target = head + up * (0.03 / unit) + fwd * (0.13 / unit) - right * (0.02 / unit)
	elif seated:
		target = Vector3(shoulder) - up * (shoulder.dot(up) - TABLE_TOP / unit - 0.04 / unit) + fwd * (0.30 / unit) + right * (0.06 / unit)
	else:
		target = shoulder - up * (0.30 / unit) + fwd * (0.28 / unit) - right * (0.02 / unit)
	if not (at_mouth and action == "sip"):
		target += up * (glass_lift / unit)
	var pole: Vector3 = shoulder + right * (0.35 / unit) - up * (0.45 / unit) - fwd * (0.1 / unit)
	var elbow: Vector3 = _two_bone(shoulder, target, a, b, pole)
	_aim(skel, idx["RightArm"], local_rot, G, (elbow - shoulder).normalized())
	_aim(skel, idx["RightForeArm"], local_rot, G, (target - elbow).normalized())
	if action == "smoke" and at_mouth:
		# The cigar is in the FREE hand. Raise that hand to the lips while the whiskey stays at rest.
		var left_shoulder: Vector3 = (G.call(idx["LeftArm"]) as Transform3D).origin
		var la: float = skel.get_bone_rest(idx["LeftForeArm"]).origin.length()
		var lb: float = skel.get_bone_rest(idx["LeftHand"]).origin.length()
		var cigar_target: Vector3 = head + up * (0.015 / unit) + fwd * (0.125 / unit) + right * (0.025 / unit)
		var left_pole: Vector3 = left_shoulder - right * (0.35 / unit) - up * (0.45 / unit) - fwd * (0.1 / unit)
		var left_elbow: Vector3 = _two_bone(left_shoulder, cigar_target, la, lb, left_pole)
		_aim(skel, idx["LeftArm"], local_rot, G, (left_elbow - left_shoulder).normalized())
		_aim(skel, idx["LeftForeArm"], local_rot, G, (cigar_target - left_elbow).normalized())
	var rot: Dictionary = {}
	for n in ["Spine", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot", "LeftArm", "LeftForeArm", "RightArm", "RightForeArm"]:
		rot[idx[n]] = local_rot[idx[n]]
	if action == "laugh":
		rot[idx["Head"]] = local_rot[idx["Head"]]
		for side in ["Left", "Right"]:
			var key: String = side + "Shoulder"
			if idx.has(key):
				rot[idx[key]] = local_rot[idx[key]]
	rot[idx["Hips"]] = local_rot[idx["Hips"]]
	return {"rot": rot, "hips_pos": hips_pos}


## Global (skeleton-space) transform of bone `i` under the trial local rotations (rest origins, our rotations, the moved hips).
static func _global(skel: Skeleton3D, i: int, local_rot: Dictionary, hips_pos: Vector3, hips: int) -> Transform3D:
	var chain: Array = []
	var b: int = i
	while b >= 0:
		chain.push_front(b)
		b = skel.get_bone_parent(b)
	var t := Transform3D()
	for c in chain:
		var origin: Vector3 = hips_pos if c == hips else skel.get_bone_rest(c).origin
		t = t * Transform3D(Basis(local_rot[c] as Quaternion), origin)
	return t


## Turn bone `i` (shortest arc) so the direction to its child points along `dir` in skeleton space.
static func _aim(skel: Skeleton3D, i: int, local_rot: Dictionary, G: Callable, dir: Vector3) -> void:
	var child_dir: Vector3 = _child_offset(skel, i)
	if child_dir.length() < 1e-6:
		return
	var g: Transform3D = G.call(i)
	var now: Vector3 = (g.basis * child_dir).normalized()
	var q := Quaternion(now, dir.normalized()) if now.dot(dir) > -0.999 else Quaternion(g.basis.x.normalized(), PI)
	var new_global: Basis = Basis(q) * g.basis
	var parent: int = skel.get_bone_parent(i)
	var pg: Basis = (G.call(parent) as Transform3D).basis if parent >= 0 else Basis()
	local_rot[i] = (pg.inverse() * new_global).orthonormalized().get_rotation_quaternion()


## Lean bone `i` forward about the character's right axis by `angle` radians.
static func _tilt(skel: Skeleton3D, i: int, local_rot: Dictionary, G: Callable, right: Vector3, angle: float) -> void:
	var g: Transform3D = G.call(i)
	var new_global: Basis = Basis(right, -angle) * g.basis    # about the right axis, a NEGATIVE turn tips the top forward
	var parent: int = skel.get_bone_parent(i)
	var pg: Basis = (G.call(parent) as Transform3D).basis if parent >= 0 else Basis()
	local_rot[i] = (pg.inverse() * new_global).orthonormalized().get_rotation_quaternion()


## The bone's own direction: the rest offset of its first child (in the bone's frame).
static func _child_offset(skel: Skeleton3D, i: int) -> Vector3:
	for c in skel.get_bone_children(i):
		var o: Vector3 = skel.get_bone_rest(c).origin
		if o.length() > 1e-5:
			return o.normalized()
	return Vector3.ZERO


## Elbow position for a two-bone chain from `s` reaching `t` (upper length `a`, lower `b`), bending toward `pole`.
static func _two_bone(s: Vector3, t: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var to_t: Vector3 = t - s
	var d: float = clampf(to_t.length(), 0.001, (a + b) * 0.999)
	var dir: Vector3 = to_t.normalized()
	var cos_a: float = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var perp: Vector3 = (pole - s) - dir * (pole - s).dot(dir)
	perp = perp.normalized() if perp.length() > 1e-5 else Vector3.UP
	return s + dir * a * cos_a + perp * a * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
