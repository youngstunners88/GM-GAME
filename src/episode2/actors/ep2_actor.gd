class_name Ep2Actor
extends Node3D
## A rigged Episode 2 character that moves like a person (founder 2026-10-02: "he doesn't move around as a real
## GTA player"): walks to a point on a real walk cycle (speed-matched so the feet do not skate), turns smoothly
## toward where he is going, stops, faces what he is talking to, reaches with two-bone arm IK, and carries props on
## bone attachments. One class for Inferno Bull, the FPS companion and any later NPC - the choreography lives
## in the owner (e.g. the Smelting Facility), never in here.
##
## Conventions: the node's origin is at the FEET; `facing` is a yaw where 0 looks down +Z (a model that faces +Z in
## its glTF needs no offset). Everything is driven by `step(delta)` so headless tests can run it without a frame clock.

signal arrived

const TURN_RATE := 6.0            # how fast the body swings toward its heading (1/s)
const ARRIVE_DIST := 0.06

var model: Node3D = null
var anim: AnimationPlayer = null
var skeleton: Skeleton3D = null
var facing: float = 0.0
var height_m: float = 2.4
## Walking speed (m/s) of the walk clip at speed_scale 1: scales with body size (a 1.7 m body walks ~1.3 m/s).
var natural_mps: float = 1.8
var idle_clip: String = ""
var walk_clip: String = "walk"
var run_clip: String = "run"

var _goal: Vector3 = Vector3.ZERO
var _walking: bool = false
var _speed: float = 1.6
var _face_goal: float = NAN
var _clip: String = ""
var _reach: Dictionary = {}      # side -> {"ik": Ep2ArmIK, "w": float, "goal": float, "ramp": float}
var _attachments: Dictionary = {}
var _hop: Dictionary = {}          # a scripted jump arc: {from, to, t, dur, h}


## Instance `scene_path`, scale it so `native_height` becomes `height`, and register extra clips.
## `clips` is {clip_name: res:// path of an armature-only GLB}; `loops` lists clips that must repeat.
func setup(scene_path: String, native_height: float, height: float, clips: Dictionary = {}, loops: Array = []) -> bool:
	if not ResourceLoader.exists(scene_path):
		return false
	model = (load(scene_path) as PackedScene).instantiate() as Node3D
	if model == null:
		return false
	height_m = height
	model.scale = Vector3.ONE * (height / native_height)
	natural_mps = 0.77 * height
	add_child(model)
	var aps: Array = model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		anim = aps[0]
	var sks: Array = model.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		skeleton = sks[0]
	for cn in clips:
		add_clip(str(cn), str(clips[cn]))
	if anim:
		var own_lib: AnimationLibrary = anim.get_animation_library("")
		if own_lib:
			for an in own_lib.get_animation_list():
				_drop_bone_translations(own_lib.get_animation(an))
		for c in loops:
			if anim.has_animation(c):
				anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
		for c in [walk_clip, run_clip]:
			if anim.has_animation(c):
				anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
	if skeleton:
		for bn in ["LeftHand", "RightHand", "Head"]:
			attachment(bn)
		for sd in ["Left", "Right"]:
			var ik := Ep2ArmIK.new()
			ik.name = "ArmIK_" + sd
			ik.side = sd
			ik.influence = 0.0
			skeleton.add_child(ik)
			_reach[sd] = {"ik": ik, "w": 0.0, "goal": 0.0, "ramp": 0.35}
	return true


## The Meshy clips are baked with a translation key on EVERY bone (the old skeleton's bone lengths). A character rigged
## on different proportions (the founder's Tripo Bull) must keep its own bone lengths, so only the Hips keeps moving.
static func _drop_bone_translations(a: Animation) -> void:
	for i in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and not str(a.track_get_path(i)).ends_with(":Hips"):
			a.remove_track(i)


## Copy the first animation of an armature-only Meshy GLB into this actor's player under `clip_name`.
func add_clip(clip_name: String, path: String) -> void:
	if anim == null or not ResourceLoader.exists(path):
		return
	var src: Node = (load(path) as PackedScene).instantiate()
	var aps: Array = src.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var sp: AnimationPlayer = aps[0]
		var names: PackedStringArray = sp.get_animation_list()
		var lib: AnimationLibrary = anim.get_animation_library("")
		if not names.is_empty() and lib and not lib.has_animation(clip_name):
			var cl: Animation = sp.get_animation(names[0]).duplicate(true)
			_drop_bone_translations(cl)
			lib.add_animation(clip_name, cl)
	src.free()


## A BoneAttachment3D on `bone` (created once); children follow the bone (hand props, the lamp, the glass).
func attachment(bone: String) -> BoneAttachment3D:
	if _attachments.has(bone):
		return _attachments[bone]
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "Att_" + bone
	ba.bone_name = bone
	skeleton.add_child(ba)
	_attachments[bone] = ba
	return ba


## A metre-scaled holder under the bone attachment: bone space is in rig units (a 2.4 m Meshy body has a ~0.0121
## skeleton scale), so anything parented straight to the attachment is invisibly tiny. Children of the holder use
## world metres, in the bone's orientation. (This is why the Bull's whiskey glass was never visible.)
func holder(bone: String) -> Node3D:
	var key: String = "holder_" + bone
	if _attachments.has(key):
		return _attachments[key]
	var ba: BoneAttachment3D = attachment(bone)
	if ba == null:
		return null
	var h := Node3D.new()
	h.name = "Holder"
	ba.add_child(h)
	var sc: float = maxf(skeleton.global_transform.basis.get_scale().x, 0.0001)
	h.scale = Vector3.ONE / sc
	_attachments[key] = h
	return h


## Copy EVERY clip of a GLB that carries its own AnimationPlayer (e.g. the seated clip set).
func add_all_clips(path: String) -> void:
	if anim == null or not ResourceLoader.exists(path):
		return
	var src: Node = (load(path) as PackedScene).instantiate()
	var aps: Array = src.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var sp: AnimationPlayer = aps[0]
		var lib: AnimationLibrary = anim.get_animation_library("")
		for cn in sp.get_animation_list():
			if lib and not lib.has_animation(cn):
				var cl: Animation = sp.get_animation(cn).duplicate(true)
				_drop_bone_translations(cl)
				lib.add_animation(cn, cl)
	src.free()


## World position of a hand (Left/Right), for props and hand-overs.
func hand_world(side: String) -> Vector3:
	var ba: BoneAttachment3D = attachment(side + "Hand")
	if ba and ba.is_inside_tree():
		return ba.global_position
	return global_position + Vector3(0.0, height_m * 0.5, 0.0)


func head_world() -> Vector3:
	var ba: BoneAttachment3D = attachment("Head")
	if ba and ba.is_inside_tree():
		return ba.global_position
	return global_position + Vector3(0.0, height_m * 0.9, 0.0)


# --- locomotion ------------------------------------------------------------------------------------------

## Walk to `p` (y ignored) and emit `arrived`. `speed` <= 0 uses the default walking speed.
func walk_to(p: Vector3, speed: float = -1.0) -> void:
	_goal = Vector3(p.x, position.y, p.z)
	_speed = speed if speed > 0.0 else natural_mps
	_walking = true
	_face_goal = NAN


func stop() -> void:
	_walking = false


## A scripted HOP: leap from where he stands to `p` over `duration` seconds along a parabola `height` metres high
## (the lava river, a ledge). Emits `arrived` on landing. Skill: ep2-lava-hop.
func hop_to(p: Vector3, duration: float = 0.9, height: float = 1.5) -> void:
	_walking = false
	_hop = {"from": position, "to": Vector3(p.x, position.y, p.z), "t": 0.0, "dur": maxf(duration, 0.1), "h": height}


func is_hopping() -> bool: return not _hop.is_empty()


## Forget any earlier face_point() goal (a rider's heading belongs to the vehicle, not to a spot he once looked at).
func clear_face_goal() -> void:
	_face_goal = NAN


## Turn (smoothly) to look at world point `p`.
func face_point(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	_face_goal = atan2(d.x, d.z)


func face_yaw(yaw: float) -> void:
	_face_goal = yaw


func is_walking() -> bool: return _walking


func is_facing(p: Vector3, tol: float = 0.2) -> bool:
	var d: Vector3 = p - global_position
	return absf(angle_difference(facing, atan2(d.x, d.z))) <= tol


## Play a clip with a crossfade. Re-requesting the playing clip is a no-op.
func play(clip: String, speed: float = 1.0, blend: float = 0.3) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if clip == _clip:
		anim.speed_scale = speed
		return
	_clip = clip
	anim.play(clip, blend, speed)


func current_clip() -> String: return _clip


# --- reaching --------------------------------------------------------------------------------------------

## Ease the `side` hand onto world point `p` (arm IK). `lean` (radians) bends the spine toward `p` to extend the reach.
func reach(side: String, p: Vector3, ramp: float = 0.35, lean: float = 0.0) -> void:
	if not _reach.has(side):
		return
	var r: Dictionary = _reach[side]
	var ik: Ep2ArmIK = r["ik"]
	ik.target_world = p
	ik.lean_toward = p
	ik.spine_lean = lean
	ik.reaching = true
	r["goal"] = 1.0
	r["ramp"] = maxf(ramp, 0.01)


func release(side: String, ramp: float = 0.35) -> void:
	if _reach.has(side):
		_reach[side]["goal"] = 0.0
		_reach[side]["ramp"] = maxf(ramp, 0.01)


## 0..1 how far the reach has eased in.
func reach_weight(side: String) -> float:
	return float(_reach[side]["w"]) if _reach.has(side) else 0.0


func reach_shortfall(side: String) -> float:
	return (_reach[side]["ik"] as Ep2ArmIK).shortfall if _reach.has(side) else 0.0


# --- per-frame -------------------------------------------------------------------------------------------

func step(delta: float) -> void:
	if not _hop.is_empty():
		_step_hop(delta)
		return
	var heading: float = facing
	if _walking:
		var to: Vector3 = _goal - position
		to.y = 0.0
		var dist: float = to.length()
		if dist <= ARRIVE_DIST:
			position.x = _goal.x
			position.z = _goal.z
			_walking = false
			arrived.emit()
		else:
			heading = atan2(to.x, to.z)
			# turn first, walk once roughly facing the goal (a person pivots, then strides)
			var off: float = absf(angle_difference(facing, heading))
			var go: float = clampf(1.0 - off / 1.2, 0.0, 1.0)
			var stride: float = minf(_speed * go * delta, dist)
			position += to / dist * stride
	elif not is_nan(_face_goal):
		heading = _face_goal
	facing = lerp_angle(facing, heading, clampf(TURN_RATE * delta, 0.0, 1.0))
	rotation.y = facing
	if anim:
		if _walking:
			var run: bool = _speed > natural_mps * 1.6 and anim.has_animation(run_clip)
			var c: String = run_clip if run else walk_clip
			if anim.has_animation(c):
				var base: float = natural_mps * (2.2 if run else 1.0)
				play(c, clampf(_speed / base, 0.4, 2.2), 0.25)
		elif idle_clip != "" and (_clip == walk_clip or _clip == run_clip):
			play(idle_clip, 1.0, 0.3)
	for sd in _reach:
		var r: Dictionary = _reach[sd]
		var w: float = r["w"]
		var goal: float = r["goal"]
		w = move_toward(w, goal, delta / float(r["ramp"]))
		r["w"] = w
		var ik: Ep2ArmIK = r["ik"]
		ik.influence = w
		if w <= 0.0 and goal <= 0.0:
			ik.reaching = false


func _step_hop(delta: float) -> void:
	_hop["t"] = float(_hop["t"]) + delta
	var k: float = clampf(float(_hop["t"]) / float(_hop["dur"]), 0.0, 1.0)
	var a: Vector3 = _hop["from"]
	var b: Vector3 = _hop["to"]
	position = a.lerp(b, k) + Vector3(0.0, float(_hop["h"]) * 4.0 * k * (1.0 - k), 0.0)
	var d: Vector3 = b - a
	if Vector2(d.x, d.z).length() > 0.01:
		facing = lerp_angle(facing, atan2(d.x, d.z), clampf(TURN_RATE * 2.0 * delta, 0.0, 1.0))
	rotation.y = facing
	if anim and anim.has_animation(run_clip):
		play(run_clip, 0.7, 0.15)
	if k >= 1.0:
		position = b
		_hop = {}
		arrived.emit()
