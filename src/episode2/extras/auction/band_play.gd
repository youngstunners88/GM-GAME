extends Node
## (Streamed with the Episode 2 extras: loaded by path from Ep2AuctionHouse, no class_name.)
## A hall musician who really plays (founder 2026-11-17: "I want the issues of the instrumentalists to be fixed").
## The rigs came from Tripo with no playing clip, and the instruments were glued to one hand bone, so they floated while
## the borrowed Idle swung the arm. Here the instrument is HELD BY THE BODY (placed every frame from the chest, neck and
## hips the clip is playing), and both hands are put ON it by two Ep2ArmIK solvers: the fretting hand on the neck, the
## other bowing, strumming, plucking or cupping. The whole body keeps time with a sway and a nod.
##
## kind: "fiddle" | "banjo" | "bass" | "harmonica" | "lead". `instrument` / `bow` are kit pieces already dressed.

## Beats per minute the players keep (the hall score is an old-time reel near this tempo).
const BPM := 112.0
## Wrist sits this far back from the point the fingers close on.
const WRIST_BACK := 0.075

var kind: String = "lead"
var folk: Node3D
var instrument: Node3D
var bow: Node3D
## How strongly the hands are on the instrument (0 = the clip's arms). The scene can ease it.
var grip: float = 1.0

var _sk: Skeleton3D
var _ik: Dictionary = {}          # "Left"/"Right" -> Ep2ArmIK
var _bones: Dictionary = {}
var _t: float = 0.0
var _seed: float = 0.0
var _base_rot: Vector3


## Wire a musician. Returns false when the rig lacks a usable arm chain (it then keeps its clip and its hand-held prop).
func setup(p_folk: Node3D, p_kind: String, p_instrument: Node3D = null, p_bow: Node3D = null) -> bool:
	folk = p_folk
	kind = p_kind
	instrument = p_instrument
	bow = p_bow
	_seed = float(hash(str(folk.name)) % 1000) / 1000.0 * TAU
	var model: Node3D = folk.get("model") as Node3D
	if model == null:
		return false
	_base_rot = model.rotation
	var rigs: Array = model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return false
	_sk = rigs[0]
	for n in ["Hips", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		_bones[n] = _find(_sk, n)
	if _bones["Spine2"] < 0:
		_bones["Spine2"] = _find(_sk, "Spine1")
	for need in ["Hips", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		if int(_bones[need]) < 0:
			return false
	if kind != "lead":
		for side in ["Left", "Right"]:
			var ik := Ep2ArmIK.new()
			ik.name = "Play%sArm" % side
			ik.side = side
			ik.bone_names = PackedStringArray([_sk.get_bone_name(_bones[side + "Arm"]), _sk.get_bone_name(_bones[side + "ForeArm"]),
				_sk.get_bone_name(_bones[side + "Hand"]), _sk.get_bone_name(_bones["Hips"])])
			ik.reaching = true
			ik.influence = 1.0
			_sk.add_child(ik)
			_ik[side] = ik
	for piece in [instrument, bow]:
		if piece != null and piece.get_parent() != folk:
			if piece.get_parent() != null:
				piece.get_parent().remove_child(piece)
			folk.add_child(piece)
	set_process(true)
	_process(0.0)
	return true


## Bone index by its Mixamo/Tripo name, ignoring any "mixamorig:" style prefix.
static func _find(sk: Skeleton3D, n: String) -> int:
	var want: String = n.to_lower()
	for i in sk.get_bone_count():
		var have: String = sk.get_bone_name(i).to_lower()
		if have == want or have.ends_with(":" + want) or have.ends_with("_" + want):
			return i
	return -1


func _bone(n: String) -> Vector3:
	return _sk.global_transform * _sk.get_bone_global_pose(int(_bones[n])).origin


## Hand target in world space for a point the fingers close on, pulled back toward the shoulder by the wrist offset.
func _wrist(side: String, at: Vector3) -> Vector3:
	var sh: Vector3 = _bone(side + "Arm")
	return at - (at - sh).normalized() * WRIST_BACK * _unit()


func _unit() -> float:
	return folk.global_basis.get_scale().y


func _process(delta: float) -> void:
	if folk == null or _sk == null or not folk.is_inside_tree():
		return
	_t += delta
	var beat: float = _t * BPM / 60.0 * TAU            # one beat = TAU
	var model: Node3D = folk.get("model") as Node3D
	# Keep time: a sway on the bar, a dip on the beat. The lead singer moves most.
	var sway: float = 0.045 if kind == "lead" else 0.03
	model.rotation = _base_rot + Vector3(0.0, sin(beat * 0.5 + _seed) * sway * 0.6, sin(beat * 0.5 + _seed) * sway)
	model.position.y = -absf(sin(beat * 0.5)) * 0.012
	var u: float = _unit()
	var basis: Basis = folk.global_basis.orthonormalized()
	var F: Vector3 = basis.z
	var U: Vector3 = Vector3.UP
	var R: Vector3 = -basis.x                     # the folk faces +Z: his right hand is on -X
	var L: Vector3 = -R
	var neck: Vector3 = _bone("Neck") if int(_bones["Neck"]) >= 0 else _bone("Head")
	var chest: Vector3 = _bone("Spine2") if int(_bones["Spine2"]) >= 0 else neck - U * 0.3 * u
	var hips: Vector3 = _bone("Hips")
	var head: Vector3 = _bone("Head")
	var lw: Vector3
	var rw: Vector3
	match kind:
		"fiddle":
			# Body under the chin on his left collarbone, neck out to the left and forward, strings up.
			var Y: Vector3 = (F * 0.8 + L * 0.55 + U * 0.12).normalized()
			var Z: Vector3 = (U - Y * U.dot(Y)).normalized().rotated(Y, -0.35)
			var X: Vector3 = Y.cross(Z).normalized()
			var tail: Vector3 = neck + L * 0.08 * u + F * 0.04 * u - U * 0.08 * u
			var origin: Vector3 = tail + Y * 0.30 * u
			_place(instrument, X, Y, Z, origin, u)
			var vib: float = sin(_t * 37.0) * 0.004 + (0.02 if fmod(floor(beat / TAU), 4.0) >= 2.0 else 0.0)
			lw = origin + Y * (0.0 + vib) * u - Z * 0.025 * u          # first position: a real left arm reaches it, never over-straight
			# The bow: across the strings between bridge and fingerboard, long strokes on the beat pairs.
			var B: Vector3 = X if X.dot(R) > 0.0 else -X
			var contact: Vector3 = origin + Y * (-0.15) * u + Z * 0.04 * u
			var s: float = sin(beat * 0.5) * 0.21
			var frog: Vector3 = contact + B * (0.27 + s) * u
			if bow != null:
				_place(bow, Y.cross(-B).normalized(), -B, Y, frog, u)
			rw = frog
		"banjo":
			var Y: Vector3 = (L * 0.78 + U * 0.55 + F * 0.12).normalized()
			var Z: Vector3 = (F - Y * F.dot(Y)).normalized()
			var X: Vector3 = Y.cross(Z).normalized()
			var head_c: Vector3 = hips + U * 0.2 * u + F * 0.17 * u + R * 0.06 * u
			var origin: Vector3 = head_c + Y * 0.30 * u
			_place(instrument, X, Y, Z, origin, u)
			var slide: float = 0.03 * sin(beat * 0.25 + _seed)
			lw = origin + Y * (0.2 + slide) * u - Z * 0.03 * u
			var strum: float = sin(beat * 2.0)              # eighth notes
			rw = head_c + Z * 0.06 * u + Y * (0.06 + strum * 0.035) * u + R * 0.02 * u
		"bass":
			# Upright on its endpin, leaning back into him; the scroll above his head.
			# A bassist stands behind and to the right of it: the body sits off his left hip, turned out toward his right,
			# so the room sees him, not just the instrument.
			var face: Vector3 = F.rotated(Vector3.UP, -0.55)
			var Y: Vector3 = (U - face * 0.2).normalized()
			var Z: Vector3 = (face - Y * face.dot(Y)).normalized()
			var X: Vector3 = Y.cross(Z).normalized()
			var pin: Vector3 = folk.global_position + F * 0.36 * u + L * 0.22 * u
			var origin: Vector3 = pin + Y * 1.25 * u
			_place(instrument, X, Y, Z, origin, u)
			var walk: float = [0.0, -0.06, -0.12, -0.06][int(floor(beat / TAU)) % 4]       # a walking bass line down the neck
			lw = origin + Y * (0.22 + walk) * u - X * 0.04 * u + Z * 0.02 * u
			var pluck: float = maxf(0.0, sin(beat)) * 0.05
			rw = origin + Y * (-0.42) * u + Z * 0.13 * u + X * (0.02 - pluck) * u
		"harmonica":
			var mouth: Vector3 = head + F * 0.11 * u - U * 0.07 * u
			var slide: float = sin(beat * 0.5) * 0.025
			var hc: Vector3 = mouth + R * slide * u
			_place(instrument, R, U, F, hc, u)
			var wah: float = (0.5 + 0.5 * sin(beat)) * 0.04          # the cupped hand opening and closing
			lw = hc + L * 0.05 * u + F * 0.015 * u
			rw = hc + R * 0.06 * u + F * (0.05 + wah) * u - U * 0.02 * u
		_:
			return
	(_ik["Left"] as Ep2ArmIK).target_world = _wrist("Left", lw)
	(_ik["Right"] as Ep2ArmIK).target_world = _wrist("Right", rw)
	for side in _ik:
		(_ik[side] as Ep2ArmIK).influence = grip


func _place(piece: Node3D, X: Vector3, Y: Vector3, Z: Vector3, origin: Vector3, u: float) -> void:
	if piece == null:
		return
	piece.global_transform = Transform3D(Basis(X, Y, Z).orthonormalized().scaled(Vector3.ONE * u), origin)
