class_name Ep2StableYard
extends Node3D
## Founder stable yard, restored at the original Episode 2 surface-set coordinates.
## One chamber-owned clock; no independent process, story beats, sale or rewards.
signal voice_line_requested(line_id: String, voice_id: String)

const DUDE := "res://src/episode2/assets/town/dude_stable_owner.glb"
const ASSISTANT := "res://src/episode2/assets/town/stable_assistant.glb"
const DUDE_VOICE := "Pe1gOSDKAuczOZqgCiEm"
const GREET := "dude_greet_01"
const STABLE_POS := Vector3(-16.0, 0.0, 1222.0)
const PADDOCK := Rect2(-24.0, 1204.0, 20.0, 36.0)
const ACCESS_CLEAR := Rect2(-4.0, 1216.0, 16.0, 12.0)
const TALK_RADIUS := 3.0
const CLIPS := ["idle", "walk", "run", "turn", "jump"]
const HORSES: Array = [
	[Vector3(-13.0, 0, 1213.5), PI, "horse_stand"],
	[Vector3(-13.0, 0, 1230.0), PI, "horse_stand"],
	[Vector3(-7.0, 0, 1209.0), 0.3, "horse_graze"],
	[Vector3(-7.0, 0, 1227.0), -0.5, "horse_graze"],
	[Vector3(-9.0, 0, 1234.0), -PI * 0.5, "horse_walk"],
]
const DUDE_PATH: Array = [Vector3(-13.4, 0, 1221.0), Vector3(-13.4, 0, 1224.0)]
const ASSISTANT_PATH: Array = [Vector3(-7.5, 0, 1216.8), Vector3(-7.5, 0, 1220.0), Vector3(-10.0, 0, 1220.0), Vector3(-10.0, 0, 1216.8)]

var actors: Array[Ep2TownFolk] = []
var horses: Array[Node3D] = []
var _brains: Array = []
var _horse_anims: Array = []
var _solids: Array = []
var _time: float = 0.0
var _talk_cd: float = 0.0
var _quiet: bool = false
var _distant_dt: float = 0.0


static func build(parent: Node3D, props: Array, walls: Array) -> Ep2StableYard:
	var yard := Ep2StableYard.new()
	yard.name = "StableYard"
	parent.add_child(yard)
	yard._build_set(walls)
	yard._build_horses(props)
	if ResourceLoader.exists(DUDE) and ResourceLoader.exists(ASSISTANT):
		yard._build_actor("Dude", DUDE, 1.84, DUDE_PATH, 0.75, 9.0, props)
		yard._build_actor("StableAssistant", ASSISTANT, 1.72, ASSISTANT_PATH, 0.8, 3.0, props)
	return yard


func _wood() -> StandardMaterial3D:
	return Ep2GoldTown._tex_mat("tex_siding.jpg", Color(0.51, 0.40, 0.27), 0.7)


func _box(label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = at
	add_child(n)
	return n


func _wall(a: Vector2, b: Vector2, walls: Array, visual: bool = true) -> void:
	walls.append([a, b])
	var mid: Vector2 = (a + b) * 0.5
	var body := StaticBody3D.new()
	body.name = "StableFenceCollision"
	body.position = Vector3(mid.x, 0.65, mid.y)
	body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(a.distance_to(b), 1.3, 0.12)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	if not visual: return
	var steps: int = maxi(1, int(ceil(a.distance_to(b) / 2.4)))
	var mat: Material = _wood()
	for i in steps + 1:
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		_box("PaddockPost", Vector3(p.x, 0.65, p.y), Vector3(0.14, 1.3, 0.14), mat)
	for y in [0.5, 1.0]:
		var rail := _box("PaddockRail", Vector3(mid.x, y, mid.y), Vector3(a.distance_to(b), 0.12, 0.09), mat)
		rail.rotation.y = body.rotation.y


func _build_set(walls: Array) -> void:
	# Original facade, not the unrelated Level1–3 stable. No new large texture.
	var barn := Sprite3D.new()
	barn.name = "OriginalStableFacade"
	barn.texture = load("res://src/assets/sprites/sprite_prop_stable.png")
	barn.pixel_size = 20.0 / 1348.0
	barn.position = STABLE_POS + Vector3(0, 131.0 * barn.pixel_size, 0)
	barn.rotation.y = PI * 0.5
	barn.shaded = true
	barn.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(barn)
	# Solid barn footprint behind the facade; the owner works outside its doors.
	for edge in [[Vector2(-23, 1218.8), Vector2(-16, 1218.8)], [Vector2(-16, 1218.8), Vector2(-16, 1225.2)],
		[Vector2(-16, 1225.2), Vector2(-23, 1225.2)], [Vector2(-23, 1225.2), Vector2(-23, 1218.8)]]:
		_wall(edge[0], edge[1], walls, false)
	# East gate is six metres wide and thirteen metres off the quad's approach road.
	for edge in [[Vector2(-24, 1204), Vector2(-4, 1204)], [Vector2(-24, 1240), Vector2(-4, 1240)],
		[Vector2(-24, 1204), Vector2(-24, 1240)], [Vector2(-4, 1204), Vector2(-4, 1218)], [Vector2(-4, 1224), Vector2(-4, 1240)],
		[Vector2(-14.6, 1212), Vector2(-14.6, 1215)], [Vector2(-14.6, 1228.5), Vector2(-14.6, 1231.5)]]:
		_wall(edge[0], edge[1], walls)
	var sign := Label3D.new()
	sign.name = "StableSign"
	sign.text = "STABLES"
	sign.font_size = 44
	sign.pixel_size = 0.014
	sign.position = STABLE_POS + Vector3(0.1, 3.45, 0)
	sign.rotation.y = PI * 0.5
	add_child(sign)


func _solid(node: Node3D, radius: float, height: float, props: Array) -> void:
	var row: Array = [Vector2(node.position.x, node.position.z), radius]
	props.append(row)
	_solids.append([node, row])
	var body := StaticBody3D.new()
	body.name = "YardBody"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	body.add_child(shape)
	node.add_child(body)


static func configure_clips(ap: AnimationPlayer) -> void:
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key in ap.get_animation_list():
		var n: String = str(key).to_lower()
		ap.get_animation(key).loop_mode = Animation.LOOP_LINEAR if n.begins_with("idle") or n.begins_with("walk") or n.begins_with("run") else Animation.LOOP_NONE


func _build_actor(label: String, path: String, height: float, route: Array, speed: float, wait: float, props: Array) -> void:
	var folk := Ep2TownFolk.new()
	folk.name = label
	folk.looping_clips.assign(["idle", "walk", "run"])
	folk.procedural_bob = false
	folk.clip_blend = 0.18
	folk.walk_clip = "walk"
	folk.walk_clip_speed = speed
	add_child(folk)
	if not folk.setup(path, height):
		folk.queue_free()
		return
	folk.place(route[0])
	folk.face_yaw(PI * 0.5)
	folk.rotation.y = PI * 0.5
	configure_clips(folk.anim_player())
	folk.hold_clip("idle")
	folk.anim_player().seek(0.7 + actors.size() * 2.1, true)
	actors.append(folk)
	_brains.append({"route": route, "index": 0, "wait": wait, "rest": wait, "speed": speed})
	_solid(folk, 0.37, height, props)


func _build_horses(props: Array) -> void:
	if not ResourceLoader.exists(Ep2TownLife.HORSE): return
	var scene: PackedScene = load(Ep2TownLife.HORSE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 241024
	for i in HORSES.size():
		var horse: Node3D = scene.instantiate()
		horse.name = "StableHorse%d" % i
		horse.position = HORSES[i][0]
		horse.rotation.y = float(HORSES[i][1])
		add_child(horse)
		horses.append(horse)
		var ap: AnimationPlayer = horse.find_children("*", "AnimationPlayer", true, false)[0]
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clip: String = HORSES[i][2]
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		ap.play(clip)
		ap.speed_scale = 0.68 if clip == "horse_walk" else 1.0
		var phase: float = rng.randf_range(0.0, ap.get_animation(clip).length)
		ap.seek(phase, true)
		_horse_anims.append(ap)
		_solid(horse, 0.95, 1.8, props)


func can_talk(player: Vector3) -> bool:
	return not _quiet and actors.size() == 2 and player.distance_to(actors[0].position) <= TALK_RADIUS


func try_talk(player: Vector3) -> bool:
	if not can_talk(player) or _talk_cd > 0.0: return false
	_talk_cd = 2.5
	actors[0].stop()
	actors[0].face_point(player)
	voice_line_requested.emit(GREET, DUDE_VOICE)
	return true


func step(delta: float, player: Vector3, quiet: bool = false) -> void:
	if delta <= 0.0: return
	_quiet = quiet
	_talk_cd = maxf(0, _talk_cd - delta)
	# Offscreen routines tick at2Hz; nearby people and animals retain full rate.
	_distant_dt += delta
	if player.distance_to(STABLE_POS) > 150.0 and _distant_dt < 0.5: return
	var dt: float = _distant_dt
	_distant_dt = 0.0
	if not quiet: _time += dt
	for i in actors.size():
		var folk: Ep2TownFolk = actors[i]
		var brain: Dictionary = _brains[i]
		if quiet or player.distance_to(folk.position) < 3.0:
			folk.stop()
			if not quiet: folk.face_point(player)
		else:
			brain["wait"] = float(brain["wait"]) - dt
			if not folk.is_walking() and float(brain["wait"]) <= 0.0:
				brain["index"] = (int(brain["index"]) + 1) % (brain["route"] as Array).size()
				folk.walk_to(brain["route"][brain["index"]], float(brain["speed"]))
				brain["wait"] = float(brain["rest"]) + 4.0
		folk.step(dt)
		folk.anim_player().advance(dt)
	if horses.size() == 5:
		var travel: float = fposmod(_time * 0.65, 8.0)
		horses[4].position.z = 1233.0 + (travel if travel < 4.0 else 8.0 - travel)
		horses[4].rotation.y = -PI * 0.5 if travel < 4.0 else PI * 0.5
	for ap in _horse_anims:
		(ap as AnimationPlayer).advance(dt if not quiet else 0.0)
	for entry in _solids:
		var p: Vector3 = (entry[0] as Node3D).position
		(entry[1] as Array)[0] = Vector2(p.x, p.z)


func snapshot() -> Dictionary:
	var people: Array = []
	for i in actors.size():
		var f: Ep2TownFolk = actors[i]
		people.append({"pos": f.position, "facing": f.facing, "walking": f.is_walking(), "goal": f._goal,
			"clip": f.current_clip(), "phase": f.anim_player().current_animation_position,
			"index": _brains[i]["index"], "wait": _brains[i]["wait"]})
	return {"time": _time, "talk_cd": _talk_cd, "people": people,
		"horse_phases": _horse_anims.map(func(ap): return ap.current_animation_position)}


func restore(data: Dictionary) -> void:
	_time = float(data.get("time", 0.0))
	_talk_cd = float(data.get("talk_cd", 0.0))
	var people: Array = data.get("people", [])
	for i in mini(actors.size(), people.size()):
		var row: Dictionary = people[i]
		var f: Ep2TownFolk = actors[i]
		f.place(row.get("pos", DUDE_PATH[0] if i == 0 else ASSISTANT_PATH[0]))
		f.face_yaw(float(row.get("facing", PI * 0.5)))
		f.rotation.y = f.facing
		_brains[i]["index"] = int(row.get("index", 0))
		_brains[i]["wait"] = float(row.get("wait", 0.0))
		if row.get("walking", false): f.walk_to(row["goal"], float(_brains[i]["speed"]))
		f.step(0.0)
		f.play_clip(str(row.get("clip", "idle")))
		f.anim_player().seek(float(row.get("phase", 0.0)), true)
	var phases: Array = data.get("horse_phases", [])
	for i in mini(phases.size(), _horse_anims.size()):
		(_horse_anims[i] as AnimationPlayer).seek(float(phases[i]), true)
	if horses.size() == 5:
		var travel: float = fposmod(_time * 0.65, 8.0)
		horses[4].position.z = 1233.0 + (travel if travel < 4.0 else 8.0 - travel)
		horses[4].rotation.y = -PI * 0.5 if travel < 4.0 else PI * 0.5
	for entry in _solids:
		var p: Vector3 = (entry[0] as Node3D).position
		(entry[1] as Array)[0] = Vector2(p.x, p.z)
