extends RefCounted
## THE MPFB2 BACKGROUND FOLK (founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21): the Stockpile's six workers and the auction hall's
## five extra people. Made with MPFB2 from MakeHuman's CC0 assets (tools/ep2_blender/build_mpfb_folk.py), all on ONE skeleton, so a
## single clip library (folk_clips.glb: Idle, Walk, Dig, Lift, Tend, Bid - CMU mocap, tools/ep2_motion/clips_stockpile.json) is
## copied onto every figure here instead of being baked into eleven GLBs. Streamed (Ep2Extras); loaded by path, no class_name.

const DIR := "res://src/episode2/extras/folk_mpfb/"
const CLIPS := DIR + "folk_clips.glb"
const LOOPING := ["Idle", "Walk", "Dig", "Lift", "Tend"]

static var _src_clips: Dictionary = {}       # clip name -> Animation (track paths relative to the donor's Skeleton3D, prefix stripped)
static var _src_hips_y: float = 0.0          # the donor's hips rest height (the clips' hip bob and crouch are scaled per figure)


static func available(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb") and ResourceLoader.exists(CLIPS)


## A figure as an Ep2TownFolk under `parent`, `height` metres tall, with the shared clips installed (null when not streamed in).
static func make(parent: Node, id: String, height: float, ground_fn: Callable = Callable()) -> Ep2TownFolk:
	if not available(id):
		return null
	var f := Ep2TownFolk.new()
	f.name = id
	f.looping_clips.assign(LOOPING)
	if ground_fn.is_valid():
		f.ground_fn = ground_fn
	parent.add_child(f)
	if not f.setup(DIR + id + ".glb", height):
		f.queue_free()
		return null
	if not _install(f):
		f.queue_free()
		return null
	return f


static func _load_clips() -> bool:
	if not _src_clips.is_empty():
		return true
	var src: Node = (load(CLIPS) as PackedScene).instantiate()
	var aps: Array = src.find_children("*", "AnimationPlayer", true, false)
	var sks: Array = src.find_children("*", "Skeleton3D", true, false)
	if aps.is_empty() or sks.is_empty():
		src.free()
		return false
	var ap := aps[0] as AnimationPlayer
	var sk := sks[0] as Skeleton3D
	var prefix: String = str(ap.get_node(ap.root_node).get_path_to(sk)) + ":"
	var hips: int = _hips(sk)
	_src_hips_y = sk.get_bone_rest(hips).origin.y if hips >= 0 else 1.0
	for name in ap.get_animation_list():
		var a: Animation = (ap.get_animation(name) as Animation).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			var path: String = str(a.track_get_path(t))
			var kind: int = a.track_get_type(t)
			var bone: String = path.substr(prefix.length())
			# rotations for every bone; position only on the hips (the bob, the crouch); scale never
			if not path.begins_with(prefix) or not (kind == Animation.TYPE_ROTATION_3D or (kind == Animation.TYPE_POSITION_3D and _is_hips(bone))):
				a.remove_track(t)
			else:
				a.track_set_path(t, NodePath(bone))
		var key: String = str(name).get_slice("|", str(name).get_slice_count("|") - 1)
		_src_clips[key] = a
	src.free()
	return not _src_clips.is_empty()


static func _install(f: Ep2TownFolk) -> bool:
	if f.model == null or not _load_clips():
		return false
	var sks: Array = f.model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return false
	var sk := sks[0] as Skeleton3D
	var to: String = str(f.model.get_path_to(sk)) + ":"
	var hips: int = _hips(sk)
	var k: float = (sk.get_bone_rest(hips).origin.y / maxf(_src_hips_y, 0.01)) if hips >= 0 else 1.0
	var ap: AnimationPlayer = f.anim_player()
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		f.model.add_child(ap)
		ap.root_node = NodePath("..")
	sk.motion_scale = k                  # the donor's hip bob and crouch at this figure's own hip height (the clips import compressed)
	var lib := AnimationLibrary.new()
	for clip in _src_clips:
		var a: Animation = (_src_clips[clip] as Animation).duplicate(true)
		for t in a.get_track_count():
			a.track_set_path(t, NodePath(to + str(a.track_get_path(t))))
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
		lib.add_animation(clip, a)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	f._bind_clips()
	return f.anim_player() != null and f.anim_player().has_animation("Idle")


static func _is_hips(bone: String) -> bool:
	var b: String = bone.to_lower()
	return b.ends_with("hips") or b.ends_with("pelvis")


static func _hips(sk: Skeleton3D) -> int:
	for i in sk.get_bone_count():
		if _is_hips(sk.get_bone_name(i)):
			return i
	return -1


## A hand bone of an MPFB figure ("Left" / "Right").
static func bone(f: Ep2TownFolk, part: String) -> int:
	var sks: Array = f.model.find_children("*", "Skeleton3D", true, false) if f.model != null else []
	if sks.is_empty():
		return -1
	var sk := sks[0] as Skeleton3D
	for i in sk.get_bone_count():
		var n: String = sk.get_bone_name(i)
		if n.ends_with(part) and n.length() - part.length() <= 11:      # "mixamorig:LeftHand" / "mixamorig_LeftHand" / "LeftHand"
			return i
	return -1


static func skeleton(f: Ep2TownFolk) -> Skeleton3D:
	var sks: Array = f.model.find_children("*", "Skeleton3D", true, false) if f.model != null else []
	return sks[0] as Skeleton3D if not sks.is_empty() else null


## Two Ep2ArmIK solvers on a figure's arms (pushing a barrow's grips, clapping), off until a caller sets `reaching`.
static func arm_iks(f: Ep2TownFolk) -> Dictionary:
	var sk: Skeleton3D = skeleton(f)
	var out: Dictionary = {}
	if sk == null:
		return out
	var hips: int = _hips(sk)
	for side in ["Left", "Right"]:
		var arm: int = bone(f, side + "Arm")
		var fore: int = bone(f, side + "ForeArm")
		var hand: int = bone(f, side + "Hand")
		if arm < 0 or fore < 0 or hand < 0 or hips < 0:
			return {}
		var ik := Ep2ArmIK.new()
		ik.name = side + "ArmIK"
		ik.side = side
		ik.bone_names = PackedStringArray([sk.get_bone_name(arm), sk.get_bone_name(fore), sk.get_bone_name(hand), sk.get_bone_name(hips)])
		ik.reaching = false
		ik.influence = 0.0
		sk.add_child(ik)
		out[side] = ik
	return out
