class_name Ep2BearKit
extends RefCounted
## The founder's Tripo bear, dressed for a LIVING wood (founder 2026-10-13: "they are not walking around, sleeping, reading
## magazines ... let's activate them and give them movements and awareness"). One place that builds a bear actor with every
## motion it needs and switches between them:
##   * its own archer clips (Idle, Archery_Aim_with_Lateral_Scan, Archery_Shot, Hit_Reaction_with_Bow, Angry_Ground_Stomp,
##     Leap_and_Punch, Shot_and_Fall_Backward),
##   * the Meshy library walk / run (Inferno's heavy-man gait) and the seated idle - the same 24-bone skeleton, so they drive the
##     bear directly (Ep2Actor drops their bone translations so the bear keeps its own proportions),
##   * props on bone holders: a magazine (reading), a longbow (archers), a "z z" above a sleeper, a "?" / "!" awareness mark.
## Poses are named states; Ep2BearBrain picks them. Every motion is driven by step(delta) (headless tests run it).

const RIG := "res://src/episode2/assets/bear_rigged.glb"
const WALK_CLIP := "res://src/episode2/assets/inferno_bull_walking_clip.glb"
const RUN_CLIP := "res://src/episode2/assets/inferno_bull_running_clip.glb"
const SIT_CLIPS := "res://src/episode2/assets/inferno_bull_sit_clips.glb"
const SIT := "Chair_Sit_Idle_M"
const READ_SIT := "Bear_Read_Seat"
const IDLE := "Idle"
const SCAN := "Archery_Aim_with_Lateral_Scan"
const SHOT := "Archery_Shot"
const HIT := "Hit_Reaction_with_Bow"
const STOMP := "Angry_Ground_Stomp"
const LEAP := "Leap_and_Punch"
const FALL := "Shot_and_Fall_Backward"
const SIT_DROP := 0.055          # rest-relative hips now keep the bear's height; only the seated sole gap remains
const WAKE_TIME := 2.2           # seconds a sleeper takes to roll up off the ground (the fall clip played backward at 1.6x)


## A bear actor at `pos` under `parent`, `height` metres tall, with every clip registered and the arms-down stance ready.
static func make_bear(parent: Node3D, pos: Vector3, height: float = 2.2) -> Ep2Actor:
	var b := Ep2Actor.new()
	b.name = "Bear"
	b.position = pos
	parent.add_child(b)
	if not b.setup(RIG, 1.9, height, {"walk": WALK_CLIP, "run": RUN_CLIP}, [IDLE, SCAN]):
		return b
	b.add_all_clips(SIT_CLIPS)
	if b.anim:
		var library: AnimationLibrary = b.anim.get_animation_library("")
		if not library.has_animation(READ_SIT):
			var seat: Animation = b.anim.get_animation(SIT).duplicate(true)
			# Keep the seated legs/hips, but the human clip's periodic torso hunch
			# pushes this short-necked bear's face through the book. Contact and gaze
			# layers own its restrained upper-body performance.
			for track in range(seat.get_track_count() - 1, -1, -1):
				var bone: String = str(seat.track_get_path(track)).get_slice(":", 1)
				if bone in ["Spine", "Spine01", "Spine02", "neck", "Head"] and seat.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					var rest: Quaternion = b.skeleton.get_bone_rest(b.skeleton.find_bone(bone)).basis.get_rotation_quaternion()
					for key in seat.track_get_key_count(track):
						seat.track_set_key_value(track, key, rest)
			seat.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(READ_SIT, seat)
	b.idle_clip = IDLE
	for c in [SIT]:
		if b.anim != null and b.anim.has_animation(c):
			b.anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
	for c in [FALL, LEAP, SHOT, HIT, STOMP]:
		if b.anim != null and b.anim.has_animation(c):
			b.anim.get_animation(c).loop_mode = Animation.LOOP_NONE
	if b.skeleton != null:
		var arms := Ep2BearArmsDown.new()
		arms.name = "ArmsDown"
		b.skeleton.add_child(arms)
		b.set_meta("arms", arms)
		var hold := Ep2BearArmsDown.new()            # reading: paws forward, holding the magazine up in front of the chest
		hold.name = "ArmsRead"
		hold.upper_dir = Vector3(0.50, -0.84, 0.06)
		hold.fore_dir = Vector3(0.50, 0.45, -0.74)
		hold.influence = 0.0
		b.skeleton.add_child(hold)
		b.set_meta("arms_read", hold)
		var head := Ep2BearHeadDown.new()
		head.name = "HeadDown"
		head.influence = 0.0
		b.skeleton.add_child(head)
		b.set_meta("head", head)
		var motion := Ep2MotionLayer.new()
		motion.actor = b
		motion.phase_offset = pos.x * 0.73 + pos.z * 0.19
		b.skeleton.add_child(motion)
		var contact := Ep2HandContacts.new()
		# Measured on the drawn paw surfaces (vertices 52285 / 24194), not the wrist origins.
		contact.palm_local_m = {"Left": Vector3(0.057665, 0.016540, -0.046777), "Right": Vector3(-0.057709, 0.016161, -0.046855)}
		for side in contact.palm_local_m:
			contact.palm_local_m[side] *= height / 1.9
		contact.influence = 0.0
		b.skeleton.add_child(contact)
		b.set_meta("contacts", contact)
	if b.anim != null:
		b.play(IDLE, 1.0, 0.0)
	return b


## Switch `b` to a named pose: idle, walk, run, sit_read, sleep, aim, shot, leap, stomp, hit, dead. Props follow the pose.
static func pose(b: Ep2Actor, state: String) -> void:
	if b.anim == null:
		return
	if b.has_meta("pose") and pose_name(b) == state:
		return                           # repeated requests cannot reset draw/page timing every frame
	var arms: SkeletonModifier3D = (b.get_meta("arms") if b.has_meta("arms") else null)
	var head: SkeletonModifier3D = (b.get_meta("head") if b.has_meta("head") else null)
	var arms_down: bool = state in ["idle", "stomp", "walk", "run"]
	var reading: bool = state == "sit_read"
	if arms:
		arms.influence = 1.0 if arms_down else 0.0
		# while walking the clip swings the arms; the modifier only lowers them a little so they don't swing out like an archer's
		if state in ["walk", "run"]:
			arms.influence = 0.85 if state == "walk" else 0.75
	if head:
		head.influence = 1.0 if reading else 0.0
	var hold: SkeletonModifier3D = (b.get_meta("arms_read") if b.has_meta("arms_read") else null)
	if hold:
		hold.influence = 1.0 if reading else 0.0
	_set_prop(b, "magazine", reading)
	# the library chair-sit keeps a man's chair height: on the short-legged bear the feet would hang 0.59 m up, so the
	# whole body drops onto a stump (measured with tools/ep2_shots/bear_poses_shot.gd: toes 0.59 m, hips 1.05 m at 2.2 m).
	# The stump is part of the WORLD (it stays when he gets up); tick_pose eases the body down onto it / back up off it.
	b.set_meta("drop_goal", -SIT_DROP * b.height_m if reading else 0.0)
	if reading and not b.has_meta("prop_stump"):
		var st: Node3D = _stump(b)
		b.set_meta("prop_stump", st)
		if b.model:
			b.model.position.y = -SIT_DROP * b.height_m          # placed seated: no slide down on the first frame
	_set_prop(b, "zzz", state == "sleep")
	b.set_meta("pose", state)
	b.set_meta("pose_t", 0.0)
	var contact: Ep2HandContacts = b.get_meta("contacts") if b.has_meta("contacts") else null
	if contact:
		contact.targets.clear()
		contact.finger_directions.clear()
		contact.prop_frame = null
		var carrying_bow: bool = b.has_meta("bow") and state not in ["dead", "sleep", "hit", "leap", "sit_read"]
		contact.influence = 1.0 if reading or carrying_bow else 0.0
		if reading:
			var magazine: Node3D = b.get_meta("prop_magazine")
			contact.targets = {"Left": magazine.get_node("LeftGrip"), "Right": magazine.get_node("RightGrip")}
		elif contact.influence > 0.0:
			var bow: Node3D = b.get_meta("bow")
			contact.prop_frame = bow
			contact.prop_bone = b.skeleton.find_bone("Spine")
			contact.targets = {"Left": bow.get_node("Grip")}
			contact.finger_directions = {"Left": Vector3.DOWN}
			if state == "aim":
				contact.targets["Right"] = bow.get_node("Nock")
				contact.finger_directions["Right"] = Vector3.RIGHT
	match state:
		"idle":
			b.play(IDLE, 1.0, 0.35)
		"walk":
			b.play(b.walk_clip, 0.9, 0.3)
		"run":
			b.play(b.run_clip, 1.0, 0.25)
		"sit_read":
			b.play(READ_SIT, 0.6, 0.6)
		"sleep":
			b.play(FALL, 1.0, 0.0)                                   # no blend: a frozen clip never finishes a crossfade
			b.anim.seek(_clip_len(b, FALL) - 0.05, true)
			b.anim.speed_scale = 0.0
		"wake":
			# getting up: the backward fall played in reverse from where he lies (same clip, so only the speed changes)
			if b.current_clip() != FALL:
				b.play(FALL, 1.0, 0.0)
				b.anim.seek(_clip_len(b, FALL) - 0.05, true)
			b.anim.speed_scale = -1.6
		"aim":
			b.play(IDLE, 1.0, 0.3)       # authored contact draw; the old scan clip throws the body outside bow reach
		"shot":
			b.play(IDLE, 1.0, 0.12)      # string/paw release and local recoil own the shot phase
		"leap":
			b.play(LEAP, 1.15, 0.12)
		"stomp":
			b.play(STOMP, 1.0, 0.2)
		"hit":
			b.play(HIT, 1.2, 0.08)
		"dead":
			b.play(FALL, 1.0, 0.1)


static func pose_name(b: Ep2Actor) -> String:
	return str(b.get_meta("pose", "idle"))


## Per-frame life of a pose: a sleeper breathes and his z's drift; a reader turns a page now and then.
static func tick_pose(b: Ep2Actor, delta: float) -> void:
	var st: String = pose_name(b)
	var t: float = float(b.get_meta("pose_t", 0.0)) + delta
	b.set_meta("pose_t", t)
	if b.model == null:
		return
	var base_s: float = float(b.get_meta("base_scale", b.model.scale.x))
	b.set_meta("base_scale", base_s)
	if st == "sleep":
		b.model.scale = Vector3.ONE * base_s          # chest motion owns breathing; support does not stretch
		var z: Node3D = b.get_meta("prop_zzz") if b.has_meta("prop_zzz") else null
		if z:
			z.position = Vector3(0.25, 0.9 + fmod(t * 0.35, 0.9), 0.0)
			(z as Label3D).modulate.a = 1.0 - fmod(t * 0.35, 0.9) / 0.9
	else:
		b.model.scale = Vector3.ONE * base_s
	if b.model:
		b.model.position.y = move_toward(b.model.position.y, float(b.get_meta("drop_goal", 0.0)), delta * 1.4)
	if st == "sit_read":
		_hold_magazine(b, t)
		var stump: Node3D = b.get_meta("prop_stump") if b.has_meta("prop_stump") else null
		if stump and b.skeleton and b.is_inside_tree() and t < 1.0:
			# the first second seated: slide the stump under his haunches (the seated clip's hips sit off the actor origin)
			var hb: int = b.skeleton.find_bone("Hips")
			var hw: Vector3 = b.skeleton.global_transform * b.skeleton.get_bone_global_pose(hb).origin
			var back: Vector3 = -Vector3(sin(b.facing), 0.0, cos(b.facing)) * 0.04 * b.height_m
			stump.global_position = Vector3(hw.x + back.x, stump.global_position.y, hw.z + back.z)
	if b.has_meta("bow"):
		_tick_bow(b, t, st, delta)


## The magazine sits IN his paws (midpoint of both hands, opened toward his face) - never floating in front of him.
static func _hold_magazine(b: Ep2Actor, t: float) -> void:
	var m: Node3D = b.get_meta("prop_magazine") if b.has_meta("prop_magazine") else null
	if m == null or not m.is_inside_tree():
		return
	# The BOOK owns independent edge contacts; it is not placed from the same paw midpoint we measure.
	m.position = Vector3(0.0, b.height_m * 0.48, b.height_m * 0.17)
	m.rotation = Vector3(-0.55, PI, 0.0)
	var page: Node3D = m.get_node("TurningPage")
	var k: float = clampf((fmod(t, 7.0) - 6.0), 0.0, 1.0)
	page.rotation.y = -0.22 + sin(k * PI) * 1.9
	# One paw supports the cover while the other follows the turning leaf toward the spine.
	var right: Marker3D = m.get_node("RightGrip")
	right.position = Vector3(0.23 - sin(k * PI) * 0.20, -0.10 + sin(k * PI) * 0.12, 0.015)


static func clip_len(b: Ep2Actor, clip: String) -> float:
	return _clip_len(b, clip)


static func _clip_len(b: Ep2Actor, clip: String) -> float:
	if b.anim == null or not b.anim.has_animation(clip):
		return 1.0
	return b.anim.get_animation(clip).length


# --- props ---------------------------------------------------------------------------------------------------------

static func _set_prop(b: Ep2Actor, which: String, on: bool) -> void:
	var key: String = "prop_" + which
	var n: Node3D = b.get_meta(key) if b.has_meta(key) else null
	if n == null and on:
		n = _make_prop(b, which)
		b.set_meta(key, n)
	if n != null:
		n.visible = on


static func _make_prop(b: Ep2Actor, which: String) -> Node3D:
	match which:
		"magazine":
			return _magazine(b)
		"zzz":
			var z := Label3D.new()
			z.text = "z Z z"
			z.font_size = 96
			z.outline_size = 18
			z.modulate = Color(0.95, 0.95, 1.0)
			z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			z.no_depth_test = false
			z.pixel_size = 0.004
			b.add_child(z)
			return z
	return null


## A magazine held open in both paws in front of the chest (the seated reading pose): two pages and a glossy cover.
## Age-appropriate: a hunting / honey glossy - "BEAR MONTHLY".
static func _magazine(b: Ep2Actor) -> Node3D:
	var root := Node3D.new()
	root.name = "Magazine"
	var h: float = b.height_m
	root.position = Vector3(0.0, h * 0.50, h * 0.20)          # in front of the chest at lap/chest height of the seated pose
	root.rotation = Vector3(-0.95, 0.0, 0.0)                   # tilted up toward his lowered face
	b.add_child(root)
	for spec in [["LeftGrip", -0.23], ["RightGrip", 0.23]]:
		var grip := Marker3D.new()
		grip.name = str(spec[0])
		grip.position = Vector3(float(spec[1]), -0.10, 0.0)
		root.add_child(grip)
	var page := StandardMaterial3D.new()
	page.albedo_color = Color(0.93, 0.90, 0.82)
	page.roughness = 0.9
	var cover := StandardMaterial3D.new()
	cover.albedo_color = Color(0.85, 0.25, 0.12)
	cover.roughness = 0.4
	for sx in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.24, 0.32, 0.012)
		p.mesh = bm
		p.material_override = page
		p.position = Vector3(0.125 * sx, 0.0, 0.0)
		p.rotation.y = -0.22 * sx
		root.add_child(p)
		var c := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.245, 0.325, 0.006)
		c.mesh = cm
		c.material_override = cover
		c.position = Vector3(0.125 * sx, 0.0, -0.01)
		c.rotation.y = -0.22 * sx
		root.add_child(c)
	var title := Label3D.new()
	title.text = "BEAR\nMONTHLY"
	title.font_size = 30
	title.outline_size = 6
	title.modulate = Color(1.0, 0.92, 0.5)
	title.position = Vector3(-0.13, 0.05, -0.045)              # on the front cover (one half of the open spread)
	title.rotation.y = PI + 0.22
	title.pixel_size = 0.0022
	root.add_child(title)
	var turning := MeshInstance3D.new()
	turning.name = "TurningPage"
	var turn_mesh := BoxMesh.new()
	turn_mesh.size = Vector3(0.235, 0.31, 0.002)
	turning.mesh = turn_mesh
	turning.material_override = page
	turning.position = Vector3(0.12, 0.0, 0.012)
	root.add_child(turning)
	return root


## A sawn pine stump under a seated bear's backside (top at the seated hips minus the haunch).
static func _stump(b: Ep2Actor) -> Node3D:
	var h: float = b.height_m
	var mi := MeshInstance3D.new()
	mi.name = "Stump"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.30 * h / 2.2
	cm.bottom_radius = 0.36 * h / 2.2
	cm.height = 0.36 * h / 2.2
	cm.radial_segments = 10
	mi.mesh = cm
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.30, 0.21, 0.14)
	bark.roughness = 0.95
	mi.material_override = bark
	var host: Node3D = b.get_parent() as Node3D if b.get_parent() is Node3D else b
	host.add_child(mi)
	var back: Vector3 = -Vector3(sin(b.facing), 0.0, cos(b.facing)) * 0.46 * h / 2.2
	mi.global_position = Vector3(b.global_position.x + back.x, cm.height * 0.5, b.global_position.z + back.z) if b.is_inside_tree() \
		else b.position + back + Vector3(0.0, cm.height * 0.5, 0.0)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = cm.top_radius * 0.96
	tm.bottom_radius = cm.top_radius * 0.96
	tm.height = 0.01
	top.mesh = tm
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color(0.62, 0.48, 0.30)
	top.material_override = ring
	top.position = Vector3(0.0, cm.height * 0.5 + 0.004, 0.0)
	mi.add_child(top)
	return mi


## A longbow in the left paw (archers): a stave of bent segments and a string.
static func add_bow(b: Ep2Actor) -> Node3D:
	if b.skeleton == null:
		return null
	var root := Node3D.new()
	root.name = "Bow"
	b.add_child(root)
	# Archer stands side-on: left arm extends toward +X, right paw draws toward the chest.
	root.position = Vector3(0.36, 1.35, 0.08) * b.height_m / 2.2
	root.rotation.y = PI * 0.5
	var grip := Marker3D.new()
	grip.name = "Grip"
	root.add_child(grip)
	var nock := Marker3D.new()
	nock.name = "Nock"
	nock.position.z = -0.5
	root.add_child(nock)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.22, 0.12)
	wood.roughness = 0.7
	var n: int = 7
	var length: float = 1.5
	for i in n:
		var t0: float = float(i) / float(n) - 0.5
		var t1: float = float(i + 1) / float(n) - 0.5
		var p0 := Vector3(0.0, t0 * length, 0.22 * (cos(t0 * PI * 2.0) - 1.0))
		var p1 := Vector3(0.0, t1 * length, 0.22 * (cos(t1 * PI * 2.0) - 1.0))
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.022
		cm.bottom_radius = 0.026
		cm.height = p0.distance_to(p1)
		cm.radial_segments = 6
		seg.mesh = cm
		seg.material_override = wood
		seg.position = (p0 + p1) * 0.5
		seg.look_at_from_position(seg.position, p1, Vector3.FORWARD)
		seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		root.add_child(seg)
	var sm_mat := StandardMaterial3D.new()
	sm_mat.albedo_color = Color(0.85, 0.82, 0.72)
	for i in 2:
		var string := MeshInstance3D.new()
		string.name = "String%d" % i
		var sm := CylinderMesh.new()
		sm.top_radius = 0.003
		sm.bottom_radius = 0.003
		string.mesh = sm
		string.material_override = sm_mat
		root.add_child(string)
	b.set_meta("bow", root)
	var torso: int = b.skeleton.find_bone("Spine")
	var torso_inv: Transform3D = (b.skeleton.global_transform * b.skeleton.get_bone_global_rest(torso)).affine_inverse()
	b.set_meta("bow_aim_frame", torso_inv * root.global_transform)
	root.position = Vector3(0.45, 1.0, 0.15) * b.height_m / 2.2
	root.rotation.y = 0.15
	b.set_meta("bow_carry_frame", torso_inv * root.global_transform)
	# Also works when a bow is equipped after the actor already entered aim.
	var contact: Ep2HandContacts = b.get_meta("contacts")
	contact.prop_frame = root
	contact.prop_bone = torso
	contact.prop_local = b.get_meta("bow_carry_frame")
	contact.targets = {"Left": grip}
	contact.finger_directions = {"Left": Vector3.DOWN}
	contact.influence = 1.0
	if pose_name(b) in ["aim", "shot"]:
		contact.prop_local = b.get_meta("bow_aim_frame")
		if pose_name(b) == "aim":
			contact.targets["Right"] = nock
			contact.finger_directions["Right"] = Vector3.RIGHT
		contact.influence = 1.0
	var arrow := MeshInstance3D.new()
	arrow.name = "NockedArrow"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.007
	shaft.bottom_radius = 0.007
	shaft.height = 0.95
	arrow.mesh = shaft
	arrow.material_override = wood
	arrow.rotation.x = PI * 0.5
	root.add_child(arrow)
	_tick_bow(b, 0.0, pose_name(b))
	return root


static func _tick_bow(b: Ep2Actor, t: float, state: String, delta: float = 1.0 / 60.0) -> void:
	var bow: Node3D = b.get_meta("bow")
	bow.visible = state not in ["dead", "sleep", "sit_read"]
	var draw: float = clampf(t / 0.7, 0.0, 1.0) if state == "aim" else maxf(0.0, 1.0 - t / 0.12) if state == "shot" else 0.0
	var nock: Node3D = bow.get_node("Nock")
	nock.position.z = -0.44 - 0.23 * draw
	var arrow: Node3D = bow.get_node("NockedArrow")
	arrow.visible = state == "aim"
	arrow.position = nock.position + Vector3(0, 0, 0.475)
	var contacts: Ep2HandContacts = b.get_meta("contacts")
	var frame: Transform3D = b.get_meta("bow_aim_frame" if state in ["aim", "shot"] else "bow_carry_frame")
	contacts.prop_local = contacts.prop_local.interpolate_with(frame, clampf(delta * 12.0, 0.0, 1.0))
	for i in 2:
		var end := Vector3(0.0, 0.75 if i == 0 else -0.75, -0.44)
		var line: MeshInstance3D = bow.get_node("String%d" % i)
		(line.mesh as CylinderMesh).height = end.distance_to(nock.position)
		line.position = (end + nock.position) * 0.5
		line.basis = Basis.looking_at(end - nock.position, Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)


static func arrow_origin(b: Ep2Actor) -> Vector3:
	if b.has_meta("bow"):
		return (b.get_meta("bow") as Node3D).get_node("Nock").global_position
	return b.global_position + Vector3(0.0, b.height_m * 0.62, 0.0)


## The awareness mark over a bear's head: "?" amber (heard / half-seen), "!" red (seen: coming for you), with the bear's name.
static func set_mark(b: Ep2Actor, text: String, color: Color) -> void:
	var lb: Label3D = (b.get_meta("mark") if b.has_meta("mark") else null)
	if lb == null:
		lb = Label3D.new()
		lb.name = "AwarenessMark"
		lb.font_size = 72
		lb.outline_size = 16
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.pixel_size = 0.006
		lb.position = Vector3(0.0, b.height_m + 0.55, 0.0)
		lb.no_depth_test = true
		b.add_child(lb)
		b.set_meta("mark", lb)
	lb.text = text
	lb.modulate = color
	lb.visible = text != ""
