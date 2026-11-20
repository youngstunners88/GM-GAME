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
## Closest a wrist target sits to its shoulder (metres per unit of body scale): the elbow can fold this far and no farther.
const MIN_REACH := 0.16
## Each player's own playing clip (2026-11-21: motion captured from the founder's Flow reference videos, SmokeRealm-mocap
## scripts/solve_bvh.py -> tools/ep2_motion/retarget_bvh.py; tools/ep2_motion/clips_band.json). A GLB without it keeps the hall's clip.
const CLIP := {"fiddle": "Band_Fiddle", "banjo": "Band_Banjo", "bass": "Band_Bass", "harmonica": "Band_Harmonica", "lead": "Band_Lead"}
## Where in its loop each player starts (fraction of the clip), so the five never sway in unison.
const PHASE := {"fiddle": 0.0, "banjo": 0.37, "bass": 0.61, "harmonica": 0.18, "lead": 0.82}
## Wrist to the base of the fingers (m per unit of body scale): a fretting hand meets the neck there, not at the wrist.
const PALM_BASE := 0.09
## Fiddle chin rest height between the neck bone (0) and the head bone (1).
const CHIN_AT := 0.45
## Lips above the Head bone (which sits at the top of the neck on these rigs), m per unit of body scale.
const MOUTH_UP := 0.04

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
var _aim: HandAim


## Turns each hand on the instrument after the arm IK: these Tripo rigs have no finger bones, so a flat hand left at the clip's angle
## read as a wave (palm to the room). Fingers run along the hand bone's +Y; the palm faces its -X (left) / +X (right): the rest pose
## holds the palms forward (seen in renders, 2026-11-17).
class HandAim extends SkeletonModifier3D:
	var bones: Dictionary = {}       # side -> hand bone index
	var fingers: Dictionary = {}     # side -> world direction the fingers point
	var palm: Dictionary = {}        # side -> world direction the palm faces

	func _process_modification() -> void:
		var sk: Skeleton3D = get_skeleton()
		if sk == null or influence <= 0.001:
			return
		var inv: Basis = sk.global_transform.basis.orthonormalized().inverse()
		for side in bones:
			if not fingers.has(side) or not palm.has(side):
				continue
			var b: int = int(bones[side])
			var y: Vector3 = (inv * (fingers[side] as Vector3)).normalized()
			var p: Vector3 = inv * (palm[side] as Vector3)
			p = p - y * p.dot(y)
			if p.length_squared() < 1e-6 or not y.is_normalized():
				continue
			var x: Vector3 = p.normalized() * (-1.0 if side == "Left" else 1.0)     # the palm is the hand's -X (left) / +X (right)
			var want: Basis = Basis(x, y, x.cross(y))
			var parent: int = sk.get_bone_parent(b)
			var pb: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
			var cur: Quaternion = sk.get_bone_pose_rotation(b)
			sk.set_bone_pose_rotation(b, cur.slerp((pb.inverse() * want).get_rotation_quaternion(), influence))


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
	_play_own_clip()
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
		_aim = HandAim.new()
		_aim.name = "PlayHandAim"
		for side in ["Left", "Right"]:
			_aim.bones[side] = _bones[side + "Hand"]
		_sk.add_child(_aim)                # after both arms: the hand turns on the solved forearm
	for piece in [instrument, bow]:
		if piece != null and piece.get_parent() != folk:
			if piece.get_parent() != null:
				piece.get_parent().remove_child(piece)
			folk.add_child(piece)
	set_process(true)
	_process(0.0)
	return true


## Hold this player's own captured clip (looping, started at its own phase). Missing clip: the hall's Idle/Play/Talk stays.
func _play_own_clip() -> void:
	if not folk.has_method("anim_player") or not folk.has_method("hold_clip"):
		return
	var ap: AnimationPlayer = folk.call("anim_player") as AnimationPlayer
	var want: String = str(CLIP.get(kind, ""))
	if ap == null or want == "":
		return
	for a in ap.get_animation_list():
		var an: String = str(a).to_lower()
		if an == want.to_lower() or an.ends_with("/" + want.to_lower()) or an.ends_with("|" + want.to_lower()):
			var anim: Animation = ap.get_animation(a)
			anim.loop_mode = Animation.LOOP_LINEAR
			folk.call("hold_clip", want)
			ap.seek(anim.length * float(PHASE.get(kind, 0.0)), true)
			return


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
	var away: Vector3 = at - sh
	# Pull back by the wrist, but never past the forearm's fold: a grip close to the shoulder (a cupped harmonica) would otherwise put
	# the target ON the shoulder, where no two-bone arm can bend (it was 8 cm off).
	var back: float = minf(WRIST_BACK * _unit(), maxf(away.length() - MIN_REACH * _unit(), 0.0))
	return at - away.normalized() * back


## Shoulder-to-wrist length of one arm in world metres (upper arm + forearm, as posed).
func _arm_len(side: String) -> float:
	var fa: Vector3 = _bone(side + "ForeArm")
	return _bone(side + "Arm").distance_to(fa) + fa.distance_to(_bone(side + "Hand"))


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
	var fl := Vector3.ZERO           # finger and palm directions per hand; a zero palm faces the grip point
	var fr := Vector3.ZERO
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	var wrap_l := false              # true: lw is the WRIST itself (a hand wrapped round a neck), not a point the fingers close on
	var wrap_r := false
	match kind:
		"fiddle":
			# Body under the chin on his left collarbone, neck out to the left and forward, strings up.
			# 2026-11-21 (founder: fix the chin): the tail sat 8 cm below the neck bone, i.e. at mid-chest. The chin rest now sits
			# between the neck and head bones, out on the left collarbone, so the captured head dip lands on it.
			var Y: Vector3 = (F * 0.8 + L * 0.55 + U * 0.12).normalized()
			var Z: Vector3 = (U - Y * U.dot(Y)).normalized().rotated(Y, -0.35)
			var X: Vector3 = Y.cross(Z).normalized()
			var tail: Vector3 = neck.lerp(head, CHIN_AT) + L * 0.07 * u + F * 0.07 * u
			var origin: Vector3 = tail + Y * 0.30 * u
			_place(instrument, X, Y, Z, origin, u)
			var vib: float = sin(_t * 37.0) * 0.004 + (0.02 if fmod(floor(beat / TAU), 4.0) >= 2.0 else 0.0)
			# The fretting hand WRAPS the neck (founder: "not hover flat"): the hand stands on the outer side of the neck, palm
			# toward it, fingers rising over the fingerboard; the wrist hangs a palm's length below the grip.
			var side: Vector3 = X if X.dot(L) > 0.0 else -X
			var grip_l: Vector3 = origin + Y * (0.0 + vib) * u
			fl = (Z - side * 0.9).normalized()          # no finger bones to curl: the flat fingers lean over the fingerboard instead
			pl = -side
			lw = grip_l - fl * PALM_BASE * u + side * 0.025 * u
			wrap_l = true
			# The bow: across the strings between bridge and fingerboard, long strokes on the beat pairs.
			var B: Vector3 = X if X.dot(R) > 0.0 else -X
			var contact: Vector3 = origin + Y * (-0.15) * u + Z * 0.04 * u
			var s: float = sin(beat * 0.5) * 0.21
			var frog: Vector3 = contact + B * (0.27 + s) * u
			if bow != null:
				_place(bow, Y.cross(-B).normalized(), -B, Y, frog, u)
			rw = frog
			fr = -B                                  # the bow hand: fingers along the stick, palm down on it
			pr = -U
		"banjo":
			var Y: Vector3 = (L * 0.78 + U * 0.55 + F * 0.12).normalized()
			var Z: Vector3 = (F - Y * F.dot(Y)).normalized()
			var X: Vector3 = Y.cross(Z).normalized()
			var head_c: Vector3 = hips + U * 0.2 * u + F * 0.17 * u + R * 0.06 * u
			var origin: Vector3 = head_c + Y * 0.30 * u
			_place(instrument, X, Y, Z, origin, u)
			var slide: float = 0.03 * sin(beat * 0.25 + _seed)
			# Fretting hand wraps the neck (2026-11-21): hand under the neck's lower edge, palm up against it, fingers rising
			# round the edge onto the strings at the front; the wrist hangs a palm's length below the grip.
			var low: Vector3 = X if X.dot(U) < 0.0 else -X
			var grip_l: Vector3 = origin + Y * (0.2 + slide) * u
			fl = (-low + Z * 0.55).normalized()
			pl = -low
			lw = grip_l - fl * PALM_BASE * u - Z * 0.015 * u
			wrap_l = true
			var strum: float = sin(beat * 2.0)              # eighth notes
			rw = head_c + Z * 0.06 * u + Y * (0.06 + strum * 0.035) * u + R * 0.02 * u
			fr = -Y.cross(Z) if (-Y.cross(Z)).dot(U) < 0.0 else Y.cross(Z)       # across the strings, brushing down
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
			# Fretting hand wraps the neck (2026-11-21): on his side of it, palm against it, fingers round onto the strings in front;
			# it was a flat palm beside the neck.
			var grip_l: Vector3 = origin + Y * (0.22 + walk) * u
			var side: Vector3 = chest - grip_l
			side = (side - Y * side.dot(Y)).normalized()
			fl = (Z - side * 0.4).normalized()
			pl = -side
			lw = grip_l - fl * PALM_BASE * u + side * 0.03 * u
			wrap_l = true
			var pluck: float = maxf(0.0, sin(beat)) * 0.05
			rw = origin + Y * (-0.2) * u + Z * 0.12 * u + X * (0.02 - pluck) * u     # where the fingerboard ends: plucked within his reach
			# The bass stands on its endpin by his feet and does not follow his body: when his captured stance carries the shoulder
			# away (Band_Bass: 8 cm past reach, 2026-11-21; the old Idle was 4.6 cm short too), pluck higher up the same strings
			# instead of letting the hand fall short of them.
			var sh_r: Vector3 = _bone("RightArm")
			var reach: float = _arm_len("Right") * 0.97 + WRIST_BACK * u
			for i in 8:
				if rw.distance_to(sh_r) <= reach:
					break
				rw += Y * 0.03 * u
			fr = -Y
		"harmonica":
			# 2026-11-21: the harp sat at his collar (the Head bone is the top of the neck, not the mouth) with both hands flat beside
			# his cheeks. It now sits at the lips and both hands cup round it: palms toward each other, fingers rising forward
			# past it, wrists below; the right hand opens and closes (the wah).
			var mouth: Vector3 = head + F * 0.10 * u + U * MOUTH_UP * u
			var slide: float = sin(beat * 0.5) * 0.025
			var hc: Vector3 = mouth + R * slide * u
			_place(instrument, R, U, F, hc, u)
			var wah: float = (0.5 + 0.5 * sin(beat)) * 0.04          # the cupped hand opening and closing
			# wrists wide at the chin (close ones crossed the forearms over his chest), fingers up and IN so the two hands meet in
			# front of his nose (straight-up fingers covered his eyes; forward ones twisted the forearms flat)
			fl = (U * 0.7 + R * 0.55 + F * 0.3).normalized()
			fr = (U * 0.7 + L * 0.55 + F * 0.3).normalized()
			pl = R
			pr = L
			lw = hc + L * 0.085 * u + F * 0.03 * u - U * 0.06 * u
			rw = hc + R * 0.085 * u + F * (0.03 + wah * 0.5) * u - U * 0.06 * u
			wrap_l = true
			wrap_r = true
		_:
			return
	var wl: Vector3 = lw if wrap_l else _wrist("Left", lw)
	var wr: Vector3 = rw if wrap_r else _wrist("Right", rw)
	(_ik["Left"] as Ep2ArmIK).target_world = wl
	(_ik["Right"] as Ep2ArmIK).target_world = wr
	for side in _ik:
		(_ik[side] as Ep2ArmIK).influence = grip
	if _aim != null:
		_aim.fingers["Left"] = fl
		_aim.fingers["Right"] = fr
		_aim.palm["Left"] = pl if pl != Vector3.ZERO else lw - wl + (lw - _bone("LeftArm")) * 0.15
		_aim.palm["Right"] = pr if pr != Vector3.ZERO else rw - wr + (rw - _bone("RightArm")) * 0.15
		_aim.influence = grip * 0.85


func _place(piece: Node3D, X: Vector3, Y: Vector3, Z: Vector3, origin: Vector3, u: float) -> void:
	if piece == null:
		return
	piece.global_transform = Transform3D(Basis(X, Y, Z).orthonormalized().scaled(Vector3.ONE * u), origin)
