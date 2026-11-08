class_name AuctionRoadChamber
extends Ep2Interlude
## THE ROAD TO THE AUCTION (founder brief PROMPT_LAKE_HORSE_REPAIR_AUCTION_ROAD_2026-11-08).
## After day-88 and Logan's Lake: one short diagonal ride (north-east) from the lake to the auction grounds. Not an open-world leg and not a
## combat arena, and NO Hammersmen on it - they already rode the lake trail and the river; Jack Hammer's first distant sighting belongs to
## the auction (its own lock, not this room).
##   QUIET  lake -> open ground: day-88 can breathe.
##   CLAIM  (protocol pressure) a broken-down claim wagon across the road: a clerk checks his papers, a claimant warns that "the big ones are
##          already taking numbers at the auction". Talk, not a firefight; the wagon is pushed aside once they have spoken.
##   SPOOK  (environment / animal pressure) vultures lift off a bison carcass in a dust gust; the horse bolts for a few seconds (reuses
##          Ep2TrailVultures, the wildlife pass's shootable flock - no new creature system).
##   ARRIVE the auction grounds' fence and sign: the room hands on (end of this slice; the auction lock owns what follows).
## A shot person falls and stays down (COMMON-SENSE RULE); the road stays open either way.

enum Beat { QUIET, CLAIM, SPOOK, ARRIVE }
const ROAD_YAW := PI * 0.25                        # the diagonal: north-east out of the lake
const ROAD_HALF := 3.0
const CORRIDOR := 24.0                             # how far either side of the road he may roam (open ground, not a canyon)
const START_S := -4.0
const CLAIM_S := 130.0                             # the claim wagon across the road
const CLAIM_TALK_R := 9.0
const SPOOK_S := 235.0                             # the carcass beside the road
const SPOOK_R := 28.0
const ARRIVE_S := 345.0                            # the auction grounds' gate
const MOUNTED_SPEED := 7.0                         # the ridden pace of the session's other horse legs (world_routes)
const MOUNTED_EYE := 2.18
const BOLT_SPEED := 11.5
const BOLT_SECONDS := 3.6
const HORSE_CLIP_SPEED := 1.9
const PERSON_HEIGHT := 1.78
const CLERK_MODEL := "res://src/episode2/extras/people/townsman_clerk.glb"
const CLAIMANT_MODEL := "res://src/episode2/extras/people/townsman_bald_worker.glb"
const WAGON_MODEL := "res://src/episode2/assets/town/donkey_cart.glb"
const CLAIM_LINES := [
	["CLAIM CLERK", "Hold up, rider. Claim office business - licenses before the auction. Let's see the paper."],
	["LIL BLUNT", "Mike Dean's four. Signed and hanging on his wall. And this horse is paid for."],
	["CLAIMANT", "Papers don't hurry a dead axle. The big ones are already taking numbers at the auction - day-eighty-eight's got everybody moving."],
	["CLAIM CLERK", "You're in order. Ride on, and mind the birds past the bend. Something died out there."],
]
const SPOOK_LINE := "LIL BLUNT: Whoa - easy, easy! It's just birds... and a whole lot of dust."
const ARRIVE_LINE := "The auction grounds. Numbers are being taken."

var _forward := Vector3(sin(ROAD_YAW), 0.0, cos(ROAD_YAW))
var _right := Vector3(cos(ROAD_YAW), 0.0, -sin(ROAD_YAW))
var _mounted: bool = true
var _horse: Node3D
var _horse_anim: AnimationPlayer
var _wagon: Node3D
var _clerk: Ep2TownFolk
var _claimant: Ep2TownFolk
var _down: Dictionary = {}                        # "clerk"/"claimant" -> true once shot
var _claim_line: int = -1
var _claim_t: float = 0.0
var _claim_done: bool = false
var _wagon_shift: float = 0.0
var _vultures: Ep2TrailVultures
var _carcass: Node3D
var _dust: CPUParticles3D
var _spooked: bool = false
var _bolt_t: float = -1.0
var _rise_t: float = -1.0
var _arrived: bool = false


func _init() -> void:
	title_card = "THE ROAD TO THE AUCTION"
	viewmodel_exposure = 0.82
	camera_min = Vector3(-400, -3, -400)
	camera_max = Vector3(400, 120, 400)


func _chamber_id() -> String: return "auction_road"
func _beat_label(b: int) -> String: return Beat.keys()[clampi(b, 0, Beat.size() - 1)]
func _build_steps() -> Array: return [_light, _ground, _road_props, _build_wagon, _build_spook, _build_gate, _build_horse]


## Road frame: s along the diagonal, d to its right.
func at(s: float, d: float = 0.0) -> Vector3:
	return _forward * s + _right * d


func road_s(p: Vector3) -> float:
	return p.dot(_forward)


func _light() -> void:
	var env := Environment.new()
	_env_node.environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.52, 0.66)
	sky_mat.sky_horizon_color = Color(0.86, 0.78, 0.62)
	sky_mat.ground_horizon_color = Color(0.70, 0.58, 0.40)
	sky_mat.ground_bottom_color = Color(0.30, 0.22, 0.14)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.62, 0.50)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.84, 0.74, 0.56)
	env.fog_density = 0.0022                      # heat haze: the far end reads as distance, not a wall
	_sun.rotation_degrees = Vector3(-38, -20, 0)
	_sun.light_color = Color(1.0, 0.86, 0.64)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 90.0


func _ground() -> void:
	var plane := MeshInstance3D.new()
	plane.name = "Desert"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(900, 900)
	plane.mesh = mesh
	plane.material_override = _plain(Color(0.62, 0.50, 0.34), 0.97)
	plane.position = at(170.0)
	_visuals.add_child(plane)
	var road := MeshInstance3D.new()
	road.name = "AuctionRoad"
	var strip := PlaneMesh.new()
	strip.size = Vector2(ROAD_HALF * 2.0, ARRIVE_S + 40.0)
	road.mesh = strip
	road.material_override = _plain(Color(0.50, 0.38, 0.25), 0.99)
	road.position = at((ARRIVE_S + 40.0) * 0.5 - 10.0) + Vector3(0, 0.02, 0)
	road.rotation.y = ROAD_YAW
	_visuals.add_child(road)


## Scrub, rocks and a few marker posts: enough to read speed on the open ground.
func _road_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 881
	var rock: StandardMaterial3D = _plain(Color(0.47, 0.38, 0.30), 0.95)
	var scrub: StandardMaterial3D = _plain(Color(0.42, 0.44, 0.26), 0.95)
	for i in 90:
		var s: float = rng.randf_range(-20.0, ARRIVE_S + 60.0)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var d: float = side * rng.randf_range(ROAD_HALF + 2.0, 70.0)
		if absf(s - SPOOK_S) < 8.0 and absf(d - 9.0) < 6.0:
			continue                              # keep the carcass clear
		var p: Vector3 = at(s, d)
		if rng.randf() < 0.45:
			var size: float = rng.randf_range(0.4, 1.8)
			_box(Vector3(size * 1.3, size * 0.7, size), p + Vector3(0, size * 0.3, 0), rock, _visuals).rotation.y = rng.randf() * TAU
		else:
			_sphere(rng.randf_range(0.35, 0.8), p + Vector3(0, 0.3, 0), scrub, _visuals, 0.6)
	var post: StandardMaterial3D = _plain(Color(0.34, 0.23, 0.13), 0.9)
	for s in [30.0, 90.0, 180.0, 290.0]:
		_box(Vector3(0.12, 1.2, 0.12), at(s, ROAD_HALF + 0.8) + Vector3(0, 0.6, 0), post, _visuals)


func _build_wagon() -> void:
	_wagon = Node3D.new()
	_wagon.name = "ClaimWagon"
	_visuals.add_child(_wagon)
	_wagon.position = at(CLAIM_S, 0.4)
	_wagon.rotation.y = ROAD_YAW + PI * 0.5        # broadside across the road
	var scene: PackedScene = load(WAGON_MODEL) if ResourceLoader.exists(WAGON_MODEL) else null
	var model: Node3D = scene.instantiate() as Node3D if scene != null else null
	if model != null:
		_wagon.add_child(model)
		model.rotation.z = 0.12                   # the dead axle: it lists to one side
	else:
		_box(Vector3(3.6, 1.0, 1.7), Vector3(0, 0.8, 0), _plain(Color(0.4, 0.27, 0.15)), _wagon)
	var sign := Label3D.new()
	sign.text = "CLAIM OFFICE · LICENSES CHECKED"
	sign.font_size = 40
	sign.pixel_size = 0.006
	sign.modulate = Color(0.95, 0.88, 0.7)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.position = Vector3(0, 2.6, 0)
	_wagon.add_child(sign)


func _build_people() -> void:
	if _clerk == null and Ep2Extras.has(CLERK_MODEL):
		_clerk = _person("ClaimClerk", CLERK_MODEL, at(CLAIM_S - 2.6, -2.2))
	if _claimant == null and Ep2Extras.has(CLAIMANT_MODEL):
		_claimant = _person("Claimant", CLAIMANT_MODEL, at(CLAIM_S + 0.5, 3.4))
		_claimant.hold_clip("Rest")


func _person(label: String, path: String, p: Vector3) -> Ep2TownFolk:
	var folk := Ep2TownFolk.new()
	folk.name = label
	folk.looping_clips.assign(["Idle", "Talk", "Rest", "Alert"])
	_visuals.add_child(folk)
	folk.setup(path, PERSON_HEIGHT, Color(0.35, 0.3, 0.25))
	folk.position = p
	folk.face_point(at(CLAIM_S - 20.0))
	folk.hold_clip("Idle")
	return folk


func _build_spook() -> void:
	_carcass = Node3D.new()
	_carcass.name = "BisonCarcass"
	_visuals.add_child(_carcass)
	_carcass.position = at(SPOOK_S, 9.0)
	_carcass.rotation.y = 0.7
	var hide_mat: StandardMaterial3D = _plain(Color(0.25, 0.17, 0.10), 0.95)
	var bone: StandardMaterial3D = _plain(Color(0.86, 0.82, 0.72), 0.8)
	_sphere(0.9, Vector3(0, 0.45, 0), hide_mat, _carcass, 0.55)
	_sphere(0.55, Vector3(0, 0.4, 1.1), hide_mat, _carcass, 0.7)
	for i in 4:
		_box(Vector3(0.06, 0.06, 0.9), Vector3(-0.3 + 0.2 * i, 0.75, -0.2), bone, _carcass).rotation.x = 0.4
	_vultures = Ep2TrailVultures.new()
	_vultures.name = "CarcassVultures"
	_visuals.add_child(_vultures)
	_vultures.position = _carcass.position + Vector3(0, -22.0, 0)    # down on the carcass until something spooks them
	_vultures.visible = false
	_dust = CPUParticles3D.new()
	_dust.name = "DustGust"
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 90
	_dust.lifetime = 3.2
	_dust.explosiveness = 0.55
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(10, 1, 10)
	_dust.direction = Vector3(-1, 0.3, 0)
	_dust.spread = 35.0
	_dust.initial_velocity_min = 4.0
	_dust.initial_velocity_max = 9.0
	_dust.gravity = Vector3(0, 0.4, 0)
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 4.5
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.78, 0.66, 0.48, 0.28)
	quad.material = mat
	_dust.mesh = quad
	_dust.position = at(SPOOK_S - 6.0, 4.0) + Vector3(0, 1.2, 0)
	_visuals.add_child(_dust)


func _build_gate() -> void:
	var gate := Node3D.new()
	gate.name = "AuctionGate"
	_visuals.add_child(gate)
	gate.position = at(ARRIVE_S + 6.0)
	gate.rotation.y = ROAD_YAW
	var wood: StandardMaterial3D = _plain(Color(0.36, 0.24, 0.13), 0.9)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.3, 4.2, 0.3), Vector3(side * 4.0, 2.1, 0), wood, gate)
		for k in 6:
			_box(Vector3(0.14, 1.3, 0.14), Vector3(side * (6.0 + 3.0 * k), 0.65, 0), wood, gate)
			_box(Vector3(3.0, 0.1, 0.06), Vector3(side * (7.5 + 3.0 * k), 1.0, 0), wood, gate)
	_box(Vector3(8.6, 0.6, 0.18), Vector3(0, 4.0, 0), wood, gate)
	var words := Label3D.new()
	words.text = "AUCTION GROUNDS · NUMBERS TAKEN HERE"
	words.font_size = 52
	words.pixel_size = 0.008
	words.modulate = Color(0.98, 0.86, 0.5)
	words.position = Vector3(0, 4.0, -0.12)
	words.rotation.y = PI
	gate.add_child(words)
	var canvas: StandardMaterial3D = _plain(Color(0.86, 0.80, 0.68), 0.9)
	for i in 4:
		var tent := _box(Vector3(5, 3, 5), Vector3(-12.0 + 8.0 * i, 1.5, 18.0 + 3.0 * (i % 2)), canvas, gate)
		tent.rotation.y = 0.2 * i


func _build_horse() -> void:
	_horse = Node3D.new()
	_horse.name = "RoadHorse"
	add_child(_horse)
	var scene: PackedScene = load(LogansLakeChamber.HORSE_MODEL) if ResourceLoader.exists(LogansLakeChamber.HORSE_MODEL) else null
	var model: Node3D = scene.instantiate() as Node3D if scene != null else null
	if model != null:
		model.rotation.y = -PI * 0.5                  # the supplied horse faces +X; the actor faces local +Z (as at the lake)
		_horse.add_child(model)
		for node in model.find_children("*", "AnimationPlayer", true, false):
			_horse_anim = node as AnimationPlayer
			break
		if _horse_anim != null:
			for clip in _horse_anim.get_animation_list():
				_horse_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	else:
		_box(Vector3(0.76, 0.82, 1.75), Vector3(0.0, 1.02, 0.0), _plain(Color(0.33, 0.2, 0.11)), _horse)


func _on_setup() -> void:
	print("[EP2] auction road started")
	_mounted = bool(handoff.get("road_mounted", true))
	_player_pos = at(START_S)
	_look_yaw = ROAD_YAW
	_look_pitch = 0.0
	_set_ground(0)
	_claim_line = -1
	_claim_t = 0.0
	_claim_done = false
	_wagon_shift = 0.0
	_down.clear()
	_spooked = false
	_bolt_t = -1.0
	_rise_t = -1.0
	_arrived = false
	Ep2Extras.start(self)
	_vm.set_world_shadows(false)
	_vm.set_own_light(WoodsQuadChamber.VM_KEY_ENERGY, _sun)
	if not _hud.search_requested.is_connected(start_rig):
		_hud.search_requested.connect(start_rig)
	_horse.visible = _mounted
	walk_speed = MOUNTED_SPEED if _mounted else walk_speed
	eye_height = MOUNTED_EYE if _mounted else FPS_EYE_HEIGHT
	_place_horse(_player_pos, ROAD_YAW)
	_advance_to(Beat.QUIET)


func _on_beat_entered(b: int) -> void:
	match b:
		Beat.QUIET: _hud.objective = "Ride north-east to the auction grounds." if _mounted else "Walk north-east to the auction grounds."
		Beat.CLAIM: _hud.objective = "A claim wagon blocks the road. Show the clerk your papers."
		Beat.SPOOK: _hud.objective = "Ride on to the auction grounds."
		Beat.ARRIVE: _hud.objective = ARRIVE_LINE


func start_rig(_payment: String = "") -> bool:
	if not has_player_control():
		return false
	if _beat == Beat.CLAIM and _claim_line < 0 and _can_talk():
		_next_claim_line()
		return true
	return false


func _can_talk() -> bool:
	return not _claim_done and _player_pos.distance_to(at(CLAIM_S - 3.0)) < CLAIM_TALK_R and not _down.has("clerk")


func _next_claim_line() -> void:
	_claim_line += 1
	if _claim_line >= CLAIM_LINES.size():
		_finish_claim()
		return
	var row: Array = CLAIM_LINES[_claim_line]
	_hud.speech("%s: %s" % [row[0], row[1]], 4.2, false)
	_claim_t = 4.2
	var speaker: Ep2TownFolk = _clerk if row[0] == "CLAIM CLERK" else (_claimant if row[0] == "CLAIMANT" else null)
	if speaker != null and not _down.has(speaker.name):
		speaker.play_clip("Talk")


func _finish_claim() -> void:
	_claim_done = true
	_claim_line = CLAIM_LINES.size()
	for folk in [_clerk, _claimant]:
		if folk != null and not _down.has(folk.name):
			folk.hold_clip("Idle")
	_advance_to(Beat.SPOOK)


func _tick(delta: float) -> void:
	_build_people()
	var s: float = road_s(_player_pos)
	if _vultures != null:
		_vultures.listener = _player_pos
	# CLAIM: the wagon holds the road until they have spoken (or nobody is left standing to speak)
	if _beat == Beat.QUIET and s > CLAIM_S - 40.0:
		_advance_to(Beat.CLAIM)
	if _claim_t > 0.0:
		_claim_t -= delta
		if _claim_t <= 0.0:
			_next_claim_line()
	if not _claim_done and _down.has("clerk"):                # nobody left to check papers: the road is his
		_finish_claim()
	if _claim_done and _wagon_shift < 1.0:
		_wagon_shift = minf(1.0, _wagon_shift + delta * 0.5)   # they roll the dead cart off the road
		_wagon.position = at(CLAIM_S, 0.4 + 7.5 * _wagon_shift)
	for folk in [_clerk, _claimant]:
		if folk != null and not _down.has(folk.name) and _player_pos.distance_to(folk.position) < 10.0:
			folk.face_point(_player_pos)
		if folk != null:
			folk.step(delta)
	# SPOOK: the birds lift off the carcass in a gust and the horse bolts
	if not _spooked and _claim_done and _player_pos.distance_to(_carcass.position) < SPOOK_R:
		_spook()
	if _rise_t >= 0.0:
		_rise_t += delta
		var k: float = clampf(_rise_t / 3.0, 0.0, 1.0)
		_vultures.position.y = _carcass.position.y - 22.0 * (1.0 - k * k * (3.0 - 2.0 * k))
		if k >= 1.0:
			_rise_t = -1.0
	if _bolt_t >= 0.0:
		_bolt_t += delta
		_player_pos = _collide(_player_pos + _forward * BOLT_SPEED * delta)
		_look_yaw = lerp_angle(_look_yaw, ROAD_YAW, clampf(delta * 2.0, 0.0, 1.0))
		eye_height = MOUNTED_EYE + 0.06 * sin(_bolt_t * 21.0)
		if _bolt_t >= BOLT_SECONDS:
			_bolt_t = -1.0
			eye_height = MOUNTED_EYE
	_tick_horse(delta)
	# ARRIVE
	if not _arrived and s >= ARRIVE_S:
		_arrived = true
		_advance_to(Beat.ARRIVE)
		_resolve({"end_session": true, "auction_arrived": true, "road_mounted": _mounted, "claim_talked": _claim_line >= CLAIM_LINES.size()
			and not _down.has("clerk"), "spooked": _spooked, "companion": ""})
		return
	var prompt := ""
	if _beat == Beat.CLAIM and _claim_line < 0 and _can_talk():
		prompt = "Show your papers [E]"
	if prompt != "" and not TouchUi.keys_shown():
		prompt = prompt.replace(" [E]", "")
	_hud.set_search_prompt(prompt)


func _spook() -> void:
	_spooked = true
	_vultures.visible = true
	_rise_t = 0.0
	_dust.restart()
	_dust.emitting = true
	_hud.speech(SPOOK_LINE, 3.5, false)
	if _mounted:
		_bolt_t = 0.0
		var path := "res://src/episode2/extras/audio/town/horse_whinny.ogg"
		if Ep2Extras.has(path):
			var player := AudioStreamPlayer3D.new()
			player.stream = load(path)
			player.bus = "SFX"
			_horse.add_child(player)
			player.play()
			player.finished.connect(player.queue_free)


func _place_horse(p: Vector3, yaw: float) -> void:
	_horse.position = Vector3(p.x, 0.0, p.z)
	_horse.rotation = Vector3(0, yaw, 0)


func _tick_horse(delta: float) -> void:
	if not _mounted or _horse == null:
		return
	var moved := Vector3(_player_pos.x - _horse.position.x, 0, _player_pos.z - _horse.position.z)
	var yaw: float = _horse.rotation.y
	if moved.length() > 0.002:
		yaw = lerp_angle(yaw, atan2(moved.x, moved.z), clampf(delta * 8.0, 0.0, 1.0))
	_place_horse(_player_pos, yaw)
	if _horse_anim == null:
		return
	var speed: float = moved.length() / maxf(delta, 0.0001)
	var clip: String = "horse_walk" if speed > 0.05 else "horse_stand"
	if _horse_anim.has_animation(clip) and (_horse_anim.current_animation != clip or not _horse_anim.is_playing()):
		_horse_anim.play(clip, 0.25)
	_horse_anim.speed_scale = clampf(speed / HORSE_CLIP_SPEED, 0.4, 5.5) if clip == "horse_walk" else 1.0


## Open ground either side of the road; the claim wagon holds the road until the talk is done.
func _collide(p: Vector3) -> Vector3:
	var s: float = clampf(p.dot(_forward), START_S - 2.0, ARRIVE_S + 4.0)
	var d: float = clampf(p.dot(_right), -CORRIDOR, CORRIDOR)
	if not _claim_done and s > CLAIM_S - 4.0 and road_s(_player_pos) <= CLAIM_S - 4.0:
		s = CLAIM_S - 4.0                         # the wagon, the clerk and the claimant across the way: he has to stop and talk
	return at(s, d) + Vector3(0, p.y, 0)


## A round at a person drops him where he stands (COMMON-SENSE RULE); a round at the birds goes to the flock.
func _on_player_shot() -> void:
	if _camera == null:
		return
	var eye: Vector3 = _camera.global_position
	var dir: Vector3 = -_camera.global_transform.basis.z
	for folk in [_clerk, _claimant]:
		if folk == null or _down.has(folk.name):
			continue
		var centre: Vector3 = folk.global_position + Vector3(0, 1.0, 0)
		var t: float = (centre - eye).dot(dir)
		if t > 0.0 and t < 120.0 and (eye + dir * t).distance_to(centre) < 0.45:
			_down[folk.name] = true
			_down["clerk" if folk == _clerk else "claimant"] = true
			folk.rotation.x = -PI * 0.5
			folk.position.y = 0.25
			if _hud != null:
				_hud.hit_marker(true)
			if _claim_line >= 0 and not _claim_done:
				_finish_claim()
			return
	if _vultures != null and _vultures.visible and _vultures.ray_distance(eye, dir) >= 0.0:
		_vultures.shoot(eye, dir, 2 if armory.equipped == Ep2ArmoryState.BUFF else 1)


func claim_done() -> bool: return _claim_done
func spooked() -> bool: return _spooked
func is_bolting() -> bool: return _bolt_t >= 0.0
func is_mounted() -> bool: return _mounted
