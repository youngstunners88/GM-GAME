class_name Ep2GatlingPost
extends Node3D
## THE COLT GATLING ON ITS POST (founder 2026-10-20: "Utah demonstrates it on its carriage, then Lil Blunt can take the crank and fire it from the
## mount. But this Gun is outside the armory store"; skill ep2-armory-guns).
##
## A six-barrel Colt Gatling on an iron pintle post in the Armory's front yard. NOT FOR SALE and never in `Ep2ArmoryState.SHOP`: it is a
## showpiece Utah demonstrates, and Lil Blunt may take the crank. It is a fixed emplacement, not a loadout slot - he never carries it away - and its
## drum is finite (never refilled for free, never minted).
##
## The model (tools/ep2_blender/build_sharps_gatling.py -> Ep2Extras.GATLING) is Gatling_Post -> Gat_Yaw -> Gat_Pitch -> {Gat_Barrels, Gat_Crank} with
## Gat_Muzzle / Gat_Eye / Gat_Eject empties and a Range_Plate (swinging plate) and Range_Bale for the firing yard. This node owns the aim (clamped arc),
## the crank / barrel spin, bursts (rounds per second, one round each), hitscan against the yard's plates, tracers, flash, casings and dust.
## Pure logic + light visuals: `step(delta)` is called by the chamber, so a test can drive it headless.
##
## Conventions: yaws are LOOK yaws (the chamber's `_look_yaw`: forward = (sin y, 0, cos y)); the bore at rest points along `heading`.

signal burst_started
signal round_fired
signal plate_rang(index: int)
signal emptied

const SHOTS_PER_SEC := 9.0
const SPIN_MAX := 15.0                    # rad/s of the barrel cluster at full crank
const SPIN_UP := 0.45
const SPIN_DOWN := 1.3
const DRUM := 150                         # one drum, finite: it is a demonstration piece, not a magazine for sale
const ARC_YAW := 0.87                     # +-50 degrees either side of the bore at rest
const PITCH_MIN := -0.12
const PITCH_MAX := 0.36
const AIM_SENS := 0.0030
const RANGE_M := 160.0
const PLATE_RADIUS := 0.27
const PLATE_CENTRE := Vector3(0.0, -0.48, 0.0)       # the plate's centre below its swing pivot (Range_Swing)
const BALE_TARGET := Vector3(0.0, 0.85, 0.0)         # the paper target on the bale (Range_Bale-local)
const FLASH_T := 0.05
const SPREAD := 0.010                                # radians of random scatter, hot barrels or not
const BURST_MAX := 2.6
## The Gatling's own bronze (founder 2026-10-25 "full quality pass - readable, period"): the kit's shared Brass (0.72, 0.55, 0.25) read as
## pale cream on the Colt's big drum and jacket in desert sun. Period gun bronze is deeper; outdoors the metal can stay high (the desert sky
## is in every reflection), indoors it is held lower so the hideout's fire-lit display gun does not go black (no reflection probes on the web).
const BRONZE := Color(0.56, 0.41, 0.21)
const DRESS_YARD := {"Brass": ["brass_worn", 0.45, 0.82, 0.8, BRONZE]}
const DRESS_INDOORS := {"Brass": ["brass_worn", 0.45, 0.66, 0.85, BRONZE]}
const SOUND_DIR := "res://src/assets/sounds/"
const SHOT_SOUNDS := ["ep2_revolver_blast_1.mp3", "ep2_revolver_blast_2.mp3", "ep2_revolver_blast_3.mp3"]
const GATLING_SOUND_DIR := "res://src/episode2/extras/audio/town/"
const GATLING_SHOT_SOUNDS := ["gatling_shot_a.ogg", "gatling_shot_b.ogg", "gatling_shot_c.ogg"]
const CRANK_LOOP_SOUND := "gatling_crank_loop.ogg"
const TAIL_SOUND := "gatling_tail.ogg"
const SHOT_POOL_SIZE := 6
const SHOT_VOLUME_DB := -4.0               # the revolver blast was -7 dB: the Colt is 3 dB hotter, with overlapping voices
const TAIL_MIN_ROUNDS := 6

var rounds: int = DRUM
var heading: float = 0.0                  # look yaw of the bore at rest
var aim_yaw: float = 0.0                  # look yaw of the bore now
var aim_pitch: float = 0.0
var shots_fired: int = 0
var plates_rung: int = 0
var bale_hits: int = 0
var spin: float = 0.0                     # rad/s of the barrel cluster
var model: Node3D = null
var targets: Array = []                   # [{kind, node, swing, ang, vel, hits}] in the order they were added

var _post: Node3D = null
var _yaw_n: Node3D = null
var _pitch_n: Node3D = null
var _barrels: Node3D = null
var _crank: Node3D = null
var _muzzle: Node3D = null
var _eye: Node3D = null
var _eject: Node3D = null
var _sign_anchor: Node3D = null
var _plate_tpl: Node3D = null
var _bale_tpl: Node3D = null
var _burst_t: float = 0.0
var _burst_rounds: int = 0
var _acc: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tracers: Array = []                  # [{node, t}]
var _tracer_i: int = 0
var _flash: OmniLight3D = null
var _flash_mesh: MeshInstance3D = null
var _flash_t: float = 0.0
var _casings: CPUParticles3D = null
var _dust: CPUParticles3D = null
var _players: Array[AudioStreamPlayer3D] = []
var _shot_streams: Array[AudioStream] = []
var _shot_fallback: Array[bool] = []       # true where the Colt recording is missing and a revolver blast stands in
var _next_player: int = 0
var _crank_audio: AudioStreamPlayer3D = null
var _tail_audio: AudioStreamPlayer3D = null
var _barrel_angle: float = 0.0
var _sight_ray_set: bool = false          # mounted only: the player's actual camera ray, not a second, parallel bore ray
var _sight_origin: Vector3 = Vector3.ZERO
var _sight_dir: Vector3 = Vector3(0.0, 0.0, 1.0)


## Load the Gatling GLB, set the bore at rest toward `look_yaw`. False (nothing drawn) when the streamed extras are not mounted.
func build(path: String, look_yaw: float, seed: int = 1874) -> bool:
	_rng.seed = seed
	_sight_ray_set = false
	_burst_rounds = 0
	if not ResourceLoader.exists(path):
		return false
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return false
	var scene: Node3D = ps.instantiate() as Node3D
	_post = scene.find_child("Gatling_Post", true, false) as Node3D
	if _post == null:
		scene.free()
		return false
	_plate_tpl = scene.find_child("Range_Plate", true, false) as Node3D
	_bale_tpl = scene.find_child("Range_Bale", true, false) as Node3D
	for tpl in [_plate_tpl, _bale_tpl]:
		if tpl != null:
			(tpl as Node3D).get_parent().remove_child(tpl)
	_post.get_parent().remove_child(_post)
	scene.free()
	model = _post
	heading = look_yaw
	aim_yaw = look_yaw
	_post.rotation.y = look_yaw - PI * 0.5          # the model's bore is +x; look yaw is measured from +z
	add_child(_post)
	Ep2Pbr.dress(_post, DRESS_YARD)                 # photo-scanned bronze, blued steel, walnut, iron (founder 2026-10-25 quality pass)
	_yaw_n = _post.find_child("Gat_Yaw", true, false) as Node3D
	_pitch_n = _post.find_child("Gat_Pitch", true, false) as Node3D
	_barrels = _post.find_child("Gat_Barrels", true, false) as Node3D
	_crank = _post.find_child("Gat_Crank", true, false) as Node3D
	_muzzle = _post.find_child("Gat_Muzzle", true, false) as Node3D
	_eye = _post.find_child("Gat_Eye", true, false) as Node3D
	_eject = _post.find_child("Gat_Eject", true, false) as Node3D
	_sign_anchor = _post.find_child("Gat_Sign", true, false) as Node3D
	if _yaw_n == null or _pitch_n == null or _muzzle == null or _eye == null:
		return false
	_build_fx()
	_apply_aim()
	return true


## The board's "NOT FOR SALE" lettering, drawn on its back face (the game paints it; the GLB has only the plank). Rotates to read from the porch.
func hang_sign(text: String) -> void:
	if _sign_anchor == null:
		return
	var l := Label3D.new()
	l.name = "GatlingSign"
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.0042
	l.modulate = Color(0.93, 0.86, 0.66)
	l.outline_size = 10
	l.outline_modulate = Color(0.30, 0.10, 0.05)
	l.double_sided = false
	l.no_depth_test = false
	l.rotation = Vector3(0.0, PI * 0.5, 0.0)           # faces -x in the model frame, toward the porch
	_sign_anchor.add_child(l)


# --- the yard ------------------------------------------------------------------------------------------------------------

## Stand a swinging iron plate at `world_pos`, its face toward `face_toward`. Returns its index.
func add_plate(world_pos: Vector3, face_toward: Vector3) -> int:
	if _plate_tpl == null:
		return -1
	var n: Node3D = _plate_tpl.duplicate() as Node3D
	add_child(n)
	n.position = world_pos - position            # this node is unrotated, so its local frame is the world's shifted by `position`
	_face_z(n, face_toward)
	var sw: Node3D = n.find_child("Range_Swing", true, false) as Node3D
	targets.append({"kind": "plate", "node": n, "swing": sw, "ang": 0.0, "vel": 0.0, "hits": 0})
	return targets.size() - 1


## A hay bale with a paper target (it only takes the hits; dust flies).
func add_bale(world_pos: Vector3, face_toward: Vector3) -> int:
	if _bale_tpl == null:
		return -1
	var n: Node3D = _bale_tpl.duplicate() as Node3D
	add_child(n)
	n.position = world_pos - position
	_face_z(n, face_toward)
	targets.append({"kind": "bale", "node": n, "swing": null, "ang": 0.0, "vel": 0.0, "hits": 0})
	return targets.size() - 1


func _face_z(n: Node3D, toward: Vector3) -> void:
	var d: Vector3 = toward - (n.position + position)
	n.rotation.y = atan2(d.x, d.z)


func plate_count() -> int:
	var c: int = 0
	for t in targets:
		if str(t["kind"]) == "plate":
			c += 1
	return c


# --- aim -----------------------------------------------------------------------------------------------------------------

## Mouse look while mounted (the same feel as the chamber's look()): the bore follows inside its arc.
func aim_delta(relative: Vector2) -> void:
	aim_yaw = clampf(aim_yaw - relative.x * AIM_SENS, heading - ARC_YAW, heading + ARC_YAW)
	aim_pitch = clampf(aim_pitch - relative.y * AIM_SENS, PITCH_MIN, PITCH_MAX)
	_apply_aim()


func set_aim(look_yaw: float, pitch: float) -> void:
	aim_yaw = clampf(look_yaw, heading - ARC_YAW, heading + ARC_YAW)
	aim_pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	_apply_aim()


## Turn the bore toward a world point at `rate` rad/s (Utah laying the gun on the plates).
func aim_toward(world_point: Vector3, delta: float, rate: float = 1.6) -> void:
	var o: Vector3 = _muzzle.global_position if _muzzle != null else global_position
	var d: Vector3 = world_point - o
	var want_yaw: float = atan2(d.x, d.z)
	var want_pitch: float = atan2(d.y, Vector2(d.x, d.z).length())
	var dy: float = wrapf(want_yaw - aim_yaw, -PI, PI)
	var k: float = clampf(rate * delta, 0.0, 1.0)
	set_aim(aim_yaw + dy * k, aim_pitch + (want_pitch - aim_pitch) * k)


## How far (radians) the bore is from pointing at `world_point`.
func aim_error(world_point: Vector3) -> float:
	var o: Vector3 = _muzzle.global_position if _muzzle != null else global_position
	return bore_dir().angle_to((world_point - o).normalized())


func _apply_aim() -> void:
	if _yaw_n == null:
		return
	_yaw_n.rotation.y = aim_yaw - heading
	_pitch_n.rotation.z = aim_pitch


## World direction the bore points.
func bore_dir() -> Vector3:
	var cp: float = cos(aim_pitch)
	return Vector3(sin(aim_yaw) * cp, sin(aim_pitch), cos(aim_yaw) * cp)


func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else global_position


## Where the gunner's eye sits (above and behind the breech, looking down the barrels).
func eye_position() -> Vector3:
	return _eye.global_position if _eye != null else global_position + Vector3(0.0, 1.5, 0.0)


## Give the gun the mounted camera's actual crosshair ray. A round still leaves the muzzle, but converges on the first thing
## this ray meets instead of running parallel to it past the fixed eye/muzzle offset. Utah never sets this: he lays the bore itself.
func set_sight_ray(origin: Vector3, direction: Vector3) -> void:
	if direction.length_squared() < 1e-8:
		clear_sight_ray()
		return
	_sight_origin = origin
	_sight_dir = direction.normalized()
	_sight_ray_set = true


## Forget the mounted crosshair (on dismount, and before the first mounted camera update), restoring bore-laid fire.
func clear_sight_ray() -> void:
	_sight_ray_set = false


## Where he stands to work the crank: behind the breech on the post's axis, at the bore's heading.
func stand_position() -> Vector3:
	var back: Vector3 = Vector3(sin(heading), 0.0, cos(heading))
	return Vector3(position.x, 0.0, position.z) - back * 1.0


# --- firing --------------------------------------------------------------------------------------------------------------

## Turn the crank for `seconds`: the barrels spin up and one round leaves per `1 / SHOTS_PER_SEC`. False (and `emptied`) when the drum is empty.
func fire_burst(seconds: float) -> bool:
	if rounds <= 0:
		return false
	if _burst_t <= 0.0:
		_burst_rounds = 0
		burst_started.emit()
	_burst_t = minf(_burst_t + seconds, BURST_MAX)
	return true


func is_firing() -> bool:
	return _burst_t > 0.0 and rounds > 0 and spin > SPIN_MAX * 0.55


func is_cranking() -> bool:
	return _burst_t > 0.0 or spin > 0.5


func cease() -> void:
	_burst_t = 0.0
	_finish_burst()


## Advance `delta` seconds: crank and barrels, rounds, tracers, plates' swing, flash.
func step(delta: float) -> void:
	if _post == null:
		return
	if _burst_t > 0.0 and rounds > 0:
		_burst_t = maxf(0.0, _burst_t - delta)
		spin = minf(SPIN_MAX, spin + SPIN_MAX / SPIN_UP * delta)
		if spin > SPIN_MAX * 0.55:
			_acc += delta * SHOTS_PER_SEC
			while _acc >= 1.0 and rounds > 0:
				_acc -= 1.0
				_shoot_one()
		if _casings != null:
			_casings.emitting = spin > SPIN_MAX * 0.55 and rounds > 0
		if _burst_t <= 0.0:
			_finish_burst()
	else:
		spin = maxf(0.0, spin - SPIN_MAX / SPIN_DOWN * delta)
		_acc = 0.0
		if _casings != null:
			_casings.emitting = false
	_barrel_angle += spin * delta
	if _barrels != null:
		_barrels.rotation.x = _barrel_angle
	if _crank != null:
		_crank.rotation.z = -_barrel_angle * 0.5
	_step_targets(delta)
	_step_fx(delta)
	_step_audio()


func _shoot_one() -> void:
	rounds -= 1
	shots_fired += 1
	_burst_rounds += 1
	var o: Vector3 = muzzle_position()
	var d: Vector3 = _round_direction(o)
	d = (d + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * SPREAD).normalized()
	var hit: Dictionary = _trace(o, d)
	var end: Vector3 = hit["point"]
	if hit.has("index"):
		_hit_target(int(hit["index"]), hit["point"])
	elif hit.has("ground"):
		_puff(end)
	_tracer(o, end)
	_flash_t = FLASH_T
	_play_shot()
	round_fired.emit()
	if rounds <= 0:
		_burst_t = 0.0
		_finish_burst()
		emptied.emit()


## The bore's direction for Utah, or a muzzle-to-aim-point direction for the player. The sight trace deliberately uses the
## same target / ground query as the round: a plate, bale, ground, or the far point in open air can all be the aim point.
func _round_direction(o: Vector3) -> Vector3:
	var bore: Vector3 = bore_dir()
	if not _sight_ray_set:
		return bore
	var sight_hit: Dictionary = _trace(_sight_origin, _sight_dir)
	var aim_point: Vector3 = sight_hit["point"]
	var to_point: Vector3 = aim_point - o
	if to_point.length_squared() < 0.0025:
		return bore
	var d: Vector3 = to_point.normalized()
	return d if d.dot(bore) > 0.0 else bore


func _finish_burst() -> void:
	if _burst_rounds >= TAIL_MIN_ROUNDS:
		_play_tail()
	_burst_rounds = 0


## The first thing a round meets: a target's disc, else the ground at y = 0, else open air at RANGE_M.
func _trace(o: Vector3, d: Vector3) -> Dictionary:
	var best: float = RANGE_M
	var out: Dictionary = {"point": o + d * RANGE_M}
	for i in targets.size():
		var t: Dictionary = targets[i]
		var n: Node3D = t["node"]
		var centre: Vector3
		if str(t["kind"]) == "plate":
			var sw: Node3D = t["swing"]
			centre = sw.global_transform * PLATE_CENTRE if sw != null else n.global_position + Vector3(0, 1.2, 0)
		else:
			centre = n.global_transform * BALE_TARGET
		var normal: Vector3 = n.global_transform.basis.z.normalized()
		var denom: float = normal.dot(d)
		if absf(denom) < 1e-4:
			continue
		var tt: float = normal.dot(centre - o) / denom
		if tt <= 0.0 or tt >= best:
			continue
		var p: Vector3 = o + d * tt
		if p.distance_to(centre) <= PLATE_RADIUS:
			best = tt
			out = {"point": p, "index": i}
	if d.y < -1e-4:
		var tg: float = -o.y / d.y
		if tg > 0.0 and tg < best:
			out = {"point": o + d * tg, "ground": true}
	return out


func _hit_target(i: int, point: Vector3) -> void:
	var t: Dictionary = targets[i]
	t["hits"] = int(t["hits"]) + 1
	if str(t["kind"]) == "plate":
		t["vel"] = float(t["vel"]) + 4.2
		if int(t["hits"]) == 1:
			plates_rung += 1
		plate_rang.emit(i)
	else:
		bale_hits += 1
		_puff(point)


func _step_targets(delta: float) -> void:
	for t in targets:
		if str(t["kind"]) != "plate" or t["swing"] == null:
			continue
		var a: float = t["ang"]
		var v: float = t["vel"]
		v += (-38.0 * a - 2.6 * v) * delta           # a pendulum plate: kicked away, swings back, settles
		a += v * delta
		t["ang"] = a
		t["vel"] = v
		(t["swing"] as Node3D).rotation.x = a


# --- effects ------------------------------------------------------------------------------------------------------------

func _build_fx() -> void:
	for i in 14:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.018, 1.0)
		m.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.86, 0.45)
		m.material_override = mat
		m.top_level = true
		m.visible = false
		add_child(m)
		_tracers.append({"node": m, "t": 0.0})
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.75, 0.4)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_muzzle.add_child(_flash)
	_flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	_flash_mesh.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 0.8, 0.4, 0.9)
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mesh.material_override = fm
	_flash_mesh.visible = false
	_muzzle.add_child(_flash_mesh)
	_casings = CPUParticles3D.new()
	_casings.amount = 18
	_casings.lifetime = 0.9
	_casings.emitting = false
	_casings.direction = Vector3(0.0, 0.5, 1.0)
	_casings.spread = 22.0
	_casings.initial_velocity_min = 1.6
	_casings.initial_velocity_max = 2.8
	_casings.gravity = Vector3(0.0, -9.8, 0.0)
	_casings.angular_velocity_min = -540.0
	_casings.angular_velocity_max = 540.0
	var cm := BoxMesh.new()
	cm.size = Vector3(0.012, 0.012, 0.045)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.85, 0.65, 0.25)
	cmat.metallic = 0.9
	cmat.roughness = 0.35
	cm.material = cmat
	_casings.mesh = cm
	if _eject != null:
		_eject.add_child(_casings)
	_dust = CPUParticles3D.new()
	_dust.amount = 7
	_dust.lifetime = 0.55
	_dust.one_shot = true
	_dust.emitting = false
	_dust.explosiveness = 1.0
	_dust.direction = Vector3.UP
	_dust.spread = 55.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 2.4
	_dust.gravity = Vector3(0.0, -2.0, 0.0)
	var dm := SphereMesh.new()
	dm.radius = 0.07
	dm.height = 0.14
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.72, 0.60, 0.42, 0.65)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.material = dmat
	_dust.mesh = dm
	_dust.top_level = true
	add_child(_dust)
	_build_audio()


func _build_audio() -> void:
	var bus: String = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_shot_streams.clear()
	_shot_fallback.clear()
	for i in GATLING_SHOT_SOUNDS.size():
		var stream: AudioStream = null
		var path: String = GATLING_SOUND_DIR + str(GATLING_SHOT_SOUNDS[i])
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		_shot_fallback.append(stream == null)
		if stream == null:
			var fallback: String = SOUND_DIR + str(SHOT_SOUNDS[i])
			if ResourceLoader.exists(fallback):
				stream = load(fallback) as AudioStream
		_shot_streams.append(stream)
	for i in SHOT_POOL_SIZE:
		var p: AudioStreamPlayer3D = _audio_3d(_muzzle, bus, SHOT_VOLUME_DB)
		_players.append(p)
	_crank_audio = _audio_3d(_muzzle, bus, -60.0)
	var crank_path: String = GATLING_SOUND_DIR + CRANK_LOOP_SOUND
	if ResourceLoader.exists(crank_path):
		var crank_stream: AudioStream = load(crank_path) as AudioStream
		if crank_stream is AudioStreamOggVorbis:
			(crank_stream as AudioStreamOggVorbis).loop = true
		_crank_audio.stream = crank_stream
	_tail_audio = _audio_3d(_muzzle, bus, SHOT_VOLUME_DB)
	var tail_path: String = GATLING_SOUND_DIR + TAIL_SOUND
	if ResourceLoader.exists(tail_path):
		_tail_audio.stream = load(tail_path) as AudioStream


func _audio_3d(parent: Node3D, bus: String, volume_db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = bus
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = RANGE_M
	parent.add_child(p)
	return p


func _tracer(o: Vector3, end: Vector3) -> void:
	var t: Dictionary = _tracers[_tracer_i % _tracers.size()]
	_tracer_i += 1
	var n: MeshInstance3D = t["node"]
	var dist: float = maxf(o.distance_to(end), 0.1)
	n.visible = true
	n.global_transform = Transform3D(Basis.looking_at((end - o).normalized(), Vector3.UP).scaled(Vector3(1, 1, dist)), (o + end) * 0.5)
	t["t"] = 0.07


func _puff(p: Vector3) -> void:
	if _dust == null:
		return
	_dust.global_position = p
	_dust.restart()
	_dust.emitting = true


func _play_shot() -> void:
	if _players.is_empty() or _shot_streams.is_empty():
		return
	var p: AudioStreamPlayer3D = _players[_next_player % _players.size()]
	_next_player += 1
	var which: int = _rng.randi_range(0, _shot_streams.size() - 1)
	var stream: AudioStream = _shot_streams[which]
	p.stream = stream
	if stream != null:
		# The Colt's own recordings vary a little around true pitch; a stand-in revolver blast is pitched up to read as a Gatling.
		p.pitch_scale = _rng.randf_range(1.12, 1.28) if _shot_fallback[which] else _rng.randf_range(0.92, 1.06)
		p.play()


func _play_tail() -> void:
	if _tail_audio != null and _tail_audio.stream != null:
		_tail_audio.play()


func _step_audio() -> void:
	if _crank_audio == null:
		return
	if _crank_audio.stream != null and spin > 0.05:
		var k: float = clampf(spin / SPIN_MAX, 0.0, 1.0)
		_crank_audio.volume_db = -9.0 + linear_to_db(maxf(k, 0.001))
		if not _crank_audio.playing:
			_crank_audio.play()
	elif _crank_audio.playing:
		_crank_audio.stop()


func _step_fx(delta: float) -> void:
	for t in _tracers:
		if float(t["t"]) > 0.0:
			t["t"] = float(t["t"]) - delta
			if float(t["t"]) <= 0.0:
				(t["node"] as Node3D).visible = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
	if _flash != null:
		_flash.light_energy = 4.0 * _flash_t / FLASH_T
	if _flash_mesh != null:
		_flash_mesh.visible = _flash_t > 0.0
		_flash_mesh.scale = Vector3.ONE * _rng.randf_range(0.7, 1.3)
