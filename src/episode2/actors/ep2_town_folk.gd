class_name Ep2TownFolk
extends Node3D
## A townsperson built from a static Tripo model (the sheriff, the stranger, the barman): human, never a bear (founder 2026-10-14: "the cowboy is a man,
## the town has no bears"). The model is scaled to `height_m`, stands on its feet, and is animated the way a statue can be: it walks with a stride bob and
## sway, turns toward what it looks at, breathes, and swaps between baked arm poses ("Idle" arms down, "Draw" gun arm out) - child meshes of the GLB named
## after the pose. No rig, so no tearing and a few KB of pack.
signal arrived

var height_m: float = 1.8
var facing: float = 0.0
var model: Node3D = null
var pose_name: String = "idle"
var dead: bool = false
var _goal: Vector3 = Vector3.ZERO
var _walking: bool = false
var _speed: float = 1.4
var _phase: float = 0.0
var _t: float = 0.0
var _fall: float = 0.0
var _kick: float = 0.0
var _path: Array = []
var _anim: AnimationPlayer = null
var _rigged: bool = false
var _clip: String = ""                               # the clip actually playing (lowercased)
var _base_clip: String = "Idle"                      # what he holds when standing still
## Armory autonomy (ep2-armory-npc-autonomy): the clip played while moving ("Walk", "StairsUp", "Carry"), a cross-fade between
## clips so nothing snaps, and optional height travel (stairs, the gallery) - all off by default so other folk are unchanged.
var walk_clip: String = "Walk"
var clip_blend: float = 0.0
var use_height: bool = false
var _floor_y: float = 0.0


## Load `path` (a GLB), scale it to `height`, put its feet on the origin. Falls back to a plain figure so a build without the art still plays.
func setup(path: String, height: float, fallback_tint: Color = Color(0.4, 0.3, 0.2), center_xz: bool = true) -> bool:
	height_m = height
	if ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate() as Node3D
	if model == null:
		model = _fallback(fallback_tint)
		add_child(model)
		return false
	add_child(model)
	var bb: AABB = _aabb(model)
	var s: float = height / maxf(bb.size.y, 0.01)
	model.scale = Vector3.ONE * s
	# a model baked with two arm poses is already centred (the union box would shift it when the gun arm is out): only stand it on its feet
	model.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * s if center_xz else 0.0, -bb.position.y * s, -(bb.position.z + bb.size.z * 0.5) * s if center_xz else 0.0)
	_bind_clips()
	set_pose("idle")
	return true


## A rigged GLB (the Armory's Rich and Utah, tools/ep2_blender/build_armory_folk.py) arrives with an
## AnimationPlayer and authored clips; a static Tripo body does not. Rigged folk are driven by real
## clips instead of the statue bob, everything else about them is unchanged.
func _bind_clips() -> void:
	_anim = null
	_rigged = false
	if model == null:
		return
	for c in model.find_children("*", "AnimationPlayer", true, false):
		_anim = c
		break
	_rigged = _anim != null and not _anim.get_animation_list().is_empty()
	if _rigged:
		play_clip(_base_clip)


## Play an authored clip by name ("Idle", "Counter", "Walk", "Greet", "Point", "Carry"), tolerant of
## the importer's prefixes and of a name-cased request. Returns false when there is no such clip.
func play_clip(name: String, speed: float = 1.0) -> bool:
	if not _rigged:
		return false
	var want: String = name.to_lower()
	for a in _anim.get_animation_list():
		var an: String = str(a).to_lower()
		if an == want or an.ends_with("/" + want) or an.ends_with("|" + want) or an.begins_with(want):
			if _clip == want and _anim.is_playing() and _anim.current_animation == str(a):
				_anim.speed_scale = speed
				return true
			_clip = want
			_anim.speed_scale = speed
			_anim.play(str(a), clip_blend if clip_blend > 0.0 else -1.0)
			return true
	return false


func has_clips() -> bool:
	return _rigged


## Hold a prop (the Sharps, a crate) in a hand: a BoneAttachment3D on the rig's bone whose name matches `bone` ("Hand.R" or "hand_r"), carrying `prop` at
## `pos` / `rot_deg` in the bone's frame. A prop of the same name is replaced. The model's own scale is undone so the prop keeps its real size.
## False when there is no rig / no such bone (the caller keeps the prop elsewhere).
func attach_prop(prop_node: Node3D, bone: String, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> bool:
	drop_prop(str(prop_node.name))
	if model == null:
		return false
	var want: String = _bone_key(bone)
	for sk in model.find_children("*", "Skeleton3D", true, false):
		var skel: Skeleton3D = sk
		for i in skel.get_bone_count():
			var have: String = _bone_key(skel.get_bone_name(i))
			if have == want or have.ends_with("_" + want):
				var att := BoneAttachment3D.new()
				att.name = "Hold_" + str(prop_node.name)
				skel.add_child(att)
				att.bone_name = skel.get_bone_name(i)
				att.add_child(prop_node)
				prop_node.position = pos
				prop_node.rotation_degrees = rot_deg
				var s: float = absf(model.scale.x) if absf(model.scale.x) > 1e-4 else 1.0
				prop_node.scale = Vector3.ONE / s
				return true
	return false


## A bone name compared loosely: "Hand.R", "hand_r" and "mixamorig:RightHand" / "mixamorig_RightHand" (a rig prefix) all read the same way.
static func _bone_key(n: String) -> String:
	return n.to_lower().replace(".", "_").replace(":", "_").replace("/", "_")


## Take a held prop out of the hand (it is freed). No-op when nothing by that name is held.
func drop_prop(prop_name: String) -> void:
	if model == null:
		return
	for a in model.find_children("Hold_" + prop_name, "BoneAttachment3D", true, false):
		a.get_parent().remove_child(a)
		a.queue_free()


func held_prop(prop_name: String) -> Node3D:
	if model == null:
		return null
	for a in model.find_children("Hold_" + prop_name, "BoneAttachment3D", true, false):
		return (a as Node).get_child(0) as Node3D if a.get_child_count() > 0 else null
	return null


func anim_player() -> AnimationPlayer:
	return _anim


func current_clip() -> String:
	return _clip


## The clip he returns to when he stops walking (the Armory's two stand at the counter, not at parade rest).
func hold_clip(name: String) -> void:
	_base_clip = name
	if _rigged and _clip != name.to_lower():
		play_clip(name)


func _fallback(c: Color) -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = height_m * 0.78
	body.mesh = cm
	body.material_override = m
	body.position = Vector3(0.0, height_m * 0.45, 0.0)
	n.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	head.mesh = sm
	head.material_override = m
	head.position = Vector3(0.0, height_m - 0.16, 0.0)
	n.add_child(head)
	return n


static func _aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null or not m.visible:
			continue
		var xf := Transform3D.IDENTITY
		var c: Node = m
		while c != null and c != root:
			if c is Node3D:
				xf = (c as Node3D).transform * xf
			c = c.get_parent()
		var bx: AABB = xf * m.mesh.get_aabb()
		out = bx if first else out.merge(bx)
		first = false
	return out


## Show the baked arm pose `p` ("idle", "draw", ...): the GLB's child mesh named like it (case-insensitive); a model with a single mesh ignores this.
func set_pose(p: String) -> void:
	pose_name = p
	if _rigged and play_clip(p):
		return
	if model == null:
		return
	var metas: Array = []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		metas.append(mi)
	if metas.size() < 2:
		return
	var found: bool = false
	for mi in metas:
		if str((mi as Node).name).to_lower().begins_with(p.to_lower()):
			found = true
	for mi in metas:
		(mi as MeshInstance3D).visible = (not found) or str((mi as Node).name).to_lower().begins_with(p.to_lower())


func walk_to(p: Vector3, speed: float = 1.4) -> void:
	_goal = Vector3(p.x, p.y if use_height else 0.0, p.z)
	_speed = speed
	_walking = true


## A list of points walked in order (one after another).
func walk_path(points: Array, speed: float = 1.4) -> void:
	_path = points.duplicate()
	if not _path.is_empty():
		walk_to(_path.pop_front(), speed)


func stop() -> void:
	_walking = false
	_path = []


## Put him at `p` at once (with its height when `use_height` is on: the Armory gallery is 3.8 m up).
func place(p: Vector3) -> void:
	_floor_y = p.y if use_height else 0.0
	position = Vector3(p.x, _floor_y, p.z)
	_walking = false
	_path = []


## The floor height he stands on (0 in the street; the gallery's 3.8 in the Armory).
func floor_y() -> float:
	return _floor_y


func is_walking() -> bool:
	return _walking or not _path.is_empty()


func face_point(p: Vector3) -> void:
	facing = atan2(p.x - position.x, p.z - position.z)


func face_yaw(y: float) -> void:
	facing = y


## He hits the ground (the stranger shot in the draw): tips over backwards and lies there.
func fall_dead() -> void:
	dead = true
	_walking = false
	_path = []


## A little kick back when he fires.
func kick() -> void:
	_kick = 1.0


func step(delta: float) -> void:
	_t += delta
	var moving: bool = false
	if _walking and not dead:
		var d: Vector3 = _goal - Vector3(position.x, _floor_y, position.z)
		if not use_height:
			d.y = 0.0
		var flat := Vector3(d.x, 0.0, d.z)
		if d.length() < 0.06:
			_walking = false
			if not _path.is_empty():
				walk_to(_path.pop_front(), _speed)
			else:
				arrived.emit()
		else:
			moving = true
			if flat.length() > 0.02:
				facing = lerp_angle(facing, atan2(d.x, d.z), clampf(8.0 * delta, 0.0, 1.0))
			# speed is ground speed: on a stair the rise rides along with the run
			var stepv: Vector3 = d * minf(1.0, (_speed * delta) / maxf(flat.length() if flat.length() > 0.02 else d.length(), 0.001))
			position.x += stepv.x
			position.z += stepv.z
			_floor_y += stepv.y
			_phase += delta * _speed * 4.6
	rotation.y = lerp_angle(rotation.y, facing, clampf(7.0 * delta, 0.0, 1.0))
	if model == null:
		return
	_kick = maxf(0.0, _kick - delta * 6.0)
	if dead:
		_fall = minf(1.0, _fall + delta * 2.6)
		var k: float = _fall * _fall * (3.0 - 2.0 * _fall)
		model.rotation = Vector3(-1.45 * k, 0.0, 0.0)
		model.position.y = 0.0 + 0.16 * k
		return
	if _rigged:
		# the clips carry the body: only the stride lift and a shot's recoil ride on top
		var want: String = walk_clip if moving else _base_clip
		if _clip != want.to_lower():
			play_clip(want)
		model.rotation = Vector3(-0.08 * _kick, 0.0, 0.0)
		# mocap clips carry their own bob; the procedural stride lift is only for the old authored figures
		position.y = _floor_y + ((absf(sin(_phase)) * 0.035) if moving and not use_height else 0.0)
		return
	model.rotation = Vector3(-0.08 * _kick, 0.0, (0.035 * sin(_phase) if moving else 0.0))
	position.y = (absf(sin(_phase)) * 0.035) if moving else 0.0
	var breath: float = 1.0 + 0.004 * sin(_t * 2.0)
	model.scale = Vector3(model.scale.x, absf(model.scale.x) * breath, model.scale.z)
