class_name Ep2Stampede
extends Node3D
## THE BUFFALO STAMPEDE (founder 2026-11-01 evening, "Guns Buff" §5): "a situation that takes place one time where a stampede of buffalos
## run towards Lil Blunt and he has the option of shooting them or getting out the way."
##
## On the lake trail, once per save (GameManager.ep2_stampede_done). A herd breaks out of the open desert beside the trail. Nothing on the
## screen announces it (founder 2026-11-05: a surprise): the only warning is the rumble in the ground and the dust wall, then it charges
## at the point where Lil Blunt is riding. Both answers work:
##   * SHOOT - a bison falls to one buffalo-gun round (two from anything else) and stays down; a thinned herd is a smaller wall,
##   * GET OUT OF THE WAY - ride on or rein back (W / S) out of the herd's band; it thunders across the trail behind or ahead of him.
## Doing nothing is an answer too: the herd crosses and runs on, so the ride can never stall on it. Caught in the herd: one heart and a
## wound to the horse (the room's own hurt / unhorse rules, so it is fair and retryable), never an instant death. When the last bison
## has crossed or fallen the event is over and the flag is written; the survivors run on out of sight and the fallen settle.
##
## The room owns the player, the camera and the shot; this node owns the herd. `step()` is driven by LakeTrailChamber._tick.

const MODEL := "res://src/episode2/extras/trail/bison.glb"        # Meshy mesh on the horse bone names, clips run + stand: tools/ep2_blender/build_bison_meshy.py
const AUDIO_DIR := "res://src/episode2/extras/audio/trail/"
const RUMBLE := AUDIO_DIR + "stampede_rumble.ogg"
const HOOVES := AUDIO_DIR + "stampede_hooves.ogg"
const PASS_BY := AUDIO_DIR + "stampede_pass.ogg"
const HIT_SOUND := AUDIO_DIR + "bison_hit.ogg"
const RUMBLE_FALLBACK := "res://src/episode2/extras/audio/town/horse_hooves_loop.ogg"
const HIT_FALLBACK := "res://src/episode2/extras/audio/town/body_thud.ogg"
const COUNT := 12
const SPEED := 10.5                       # m/s at the charge
const START_DIST := 115.0                 # how far out in the desert the herd forms
const TELEGRAPH := 3.2                    # rumble + dust before the charge
const CHARGE_RAMP := 1.2                  # seconds from the first lunge to full speed: this much weight does not start at once
const BODY_R := 0.95                      # hit capsule radius
const BODY_HALF := 1.15                   # half its length along the heading
const TRAMPLE_R := 2.3                    # a bison this close to him (flat) tramples him
const HP := 2                             # a buffalo-gun round is worth both
const STAGGER_S := 0.42
const WOUNDED_PACE := 0.86                # a wounded animal keeps running, a step behind the rest
const FALL_S := 0.65
const STRIDE_BOUNCE := 0.15               # the body lifts this far out of the suspended phase and lands hard
const STRIDE_PITCH := 0.075               # shoulders and rump rock over each stride
const STRIDE_S := 0.56                    # the `run` clip's stride, for a stand-in with no clip
const PASS_NEAR := 18.0                   # the air moves before the wall arrives; the sound peaks about 1.5 s in
const SHAKE_FROM := 45.0
const FINISH_PAST := 40.0                 # the event is over once every living bison is this far past the target
const RUN_OUT_PAST := 135.0               # ... and the survivors stop drawing here, over the rise of the dust

signal trampled
signal finished(killed: int)
signal bison_down(at: Vector3)
signal bison_hit(at: Vector3, killed: bool)

var active: bool = false
var done: bool = false
var killed: int = 0
var trample_count: int = 0
var herd: Array = []                      # [{node, anim, health, pos, dead, t_dead, lane, bob, speed, delay, running, stagger, wounded, was_near, fallen_puffed}]
var heading: Vector3 = Vector3.FORWARD
var _t: float = 0.0
var _rumble: AudioStreamPlayer3D = null
var _hooves: AudioStreamPlayer3D = null
var _pass: AudioStreamPlayer3D = null
var _hit_voice: AudioStreamPlayer3D = null
var _hit_pitch: float = 0.92
var _pass_played: bool = false
var _dust: Array = []
var _puff: StandardMaterial3D = null
var _target: Vector3 = Vector3.ZERO
var _nearest: float = 999.0
var _rng := RandomNumberGenerator.new()


## Form the herd `side` (+1 / -1) of the trail, aimed at `target` (where he will be), then charge after the telegraph.
func begin(target: Vector3, trail_dir: Vector3, side: float) -> void:
	_target = target
	var across: Vector3 = Vector3(trail_dir.z, 0.0, -trail_dir.x).normalized() * side
	# from out in the desert, slightly ahead of him, toward him: they come AT him, not just across
	var origin: Vector3 = target + across * START_DIST + trail_dir.normalized() * 18.0
	heading = (target - origin)
	heading.y = 0.0
	heading = heading.normalized()
	var side_v: Vector3 = Vector3(heading.z, 0.0, -heading.x)
	var packed: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	_rng.seed = 1874
	for i in COUNT:
		var row: int = int(float(i) / 4.0)
		var col: float = float(i % 4) - 1.5
		var lane: float = col * 3.2 + _rng.randf_range(-0.7, 0.7)
		var p: Vector3 = origin - heading * (float(row) * 4.2 + _rng.randf_range(0.0, 1.6)) + side_v * lane
		var node: Node3D = packed.instantiate() as Node3D if packed != null else _stand_in()
		node.name = "Bison%d" % i
		add_child(node)
		node.scale = Vector3.ONE * _rng.randf_range(0.95, 1.12)
		var players: Array = node.find_children("*", "AnimationPlayer", true, false)
		var anim: AnimationPlayer = players[0] as AnimationPlayer if not players.is_empty() else null
		herd.append({"node": node, "anim": anim, "health": Ep2CreatureHealth.attach(node, HP), "pos": p, "dead": false, "t_dead": 0.0, "lane": lane,
			"bob": _rng.randf_range(0.0, TAU), "speed": SPEED * _rng.randf_range(0.94, 1.06),
			"delay": 0.0 if row == 0 else float(row) * 0.12 + _rng.randf_range(0.0, 0.1), "running": false,
			"stagger": 0.0, "wounded": false, "was_near": false, "fallen_puffed": false})
		if anim != null:
			_set_clips_looping(anim)
			_play_from_anywhere(anim, "stand" if anim.has_animation("stand") else "run", 0.7)
		_place(herd[i])
	_build_dust(origin)
	_build_audio(origin)
	active = true
	_t = 0.0
	_pass_played = false


func _set_clips_looping(anim: AnimationPlayer) -> void:
	for clip in anim.get_animation_list():
		anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


## Start a clip at a random place in its cycle: twelve animals on the same frame read as one animal copied twelve times.
func _play_from_anywhere(anim: AnimationPlayer, clip: String, rate: float, blend: float = -1.0) -> void:
	anim.play(clip, blend)
	anim.seek(_rng.randf() * anim.get_animation(clip).length, true)
	anim.speed_scale = rate


func _build_audio(origin: Vector3) -> void:
	_rumble = _voice("Rumble", _stream(RUMBLE, RUMBLE_FALLBACK, true), 42.0, 6.0)
	if _rumble != null:
		_rumble.pitch_scale = 0.62 if ResourceLoader.exists(RUMBLE) else 0.55
		_rumble.volume_db = -10.0
		_rumble.global_position = origin
		_rumble.play()
	_hooves = _voice("Hooves", _stream(HOOVES, RUMBLE_FALLBACK, true), 36.0, 4.0)
	if _hooves != null:
		_hooves.volume_db = -15.0
		_hooves.global_position = origin
		_hooves.play()
	_pass = _voice("PassBy", _stream(PASS_BY, "", false), 30.0, 3.0)
	_hit_voice = _voice("BisonHit", _stream(HIT_SOUND, HIT_FALLBACK, false), 70.0, 2.0)
	if _hit_voice != null:
		_hit_voice.max_polyphony = 3         # two hits close together must not cut each other off
		_hit_pitch = 0.92 if ResourceLoader.exists(HIT_SOUND) else 0.72


func _stream(path: String, fallback: String, loop: bool) -> AudioStream:
	var chosen: String = path if path != "" and ResourceLoader.exists(path) else fallback
	if chosen == "" or not ResourceLoader.exists(chosen):
		return null
	var stream: AudioStream = load(chosen) as AudioStream
	if loop and stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func _voice(label: String, stream: AudioStream, unit: float, max_db: float) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = label
	p.stream = stream
	p.unit_size = unit
	p.max_db = max_db
	p.bus = "SFX"
	add_child(p)
	return p


## True while the herd is still forming (rumble and dust, no charge yet).
func telegraphing() -> bool:
	return active and _t < TELEGRAPH


## How hard the ground is shaking at him, 0..1. The room turns it into a small camera tremble.
func ground_shake() -> float:
	return clampf(1.0 - _nearest / SHAKE_FROM, 0.0, 1.0) if active else 0.0


## The whole event, from the first rumble to the herd's far side: how long the music should stay under it.
static func expected_seconds() -> float:
	return TELEGRAPH + (START_DIST + FINISH_PAST) / SPEED


func step(delta: float, player: Vector3) -> void:
	_t += delta
	if not active:
		_aftermath(delta)
		return
	var charging: bool = _t >= TELEGRAPH
	var alive: int = 0
	var centre := Vector3.ZERO
	var closest: Dictionary = {}
	_nearest = 999.0
	for b in herd:
		if bool(b["dead"]):
			_fall(b, delta)
			continue
		alive += 1
		if charging:
			_advance(b, delta)
			var flat: Vector3 = (b["pos"] as Vector3) - player
			flat.y = 0.0
			var gap: float = flat.length()
			if gap < _nearest:
				_nearest = gap
				closest = b
			# caught in the herd: one trample per pass of each bison (the room's own invulnerability spaces the hurts)
			var near: bool = gap < TRAMPLE_R
			if near and not bool(b["was_near"]):
				trample_count += 1
				trampled.emit()
			b["was_near"] = near
		_place(b)
		centre += b["pos"]
	if alive > 0:
		centre /= float(alive)
		_tick_audio(centre, closest)
	for i in _dust.size():
		var d: CPUParticles3D = _dust[i]
		if alive > 0:
			d.global_position = centre - heading * (2.0 + float(i) * 5.0)
		d.emitting = alive > 0
	# over when every living bison is well past him (across the trail and away) or down
	var past: bool = true
	for b in herd:
		if not bool(b["dead"]) and ((b["pos"] as Vector3) - _target).dot(heading) < FINISH_PAST:
			past = false
	if charging and (alive == 0 or past):
		_finish()


## The charge is over but the world is not: the fallen finish falling and the survivors run on until the distance has them.
func _aftermath(delta: float) -> void:
	for b in herd:
		if bool(b["dead"]):
			_fall(b, delta)
		elif (b["node"] as Node3D).visible:
			_advance(b, delta)
			_place(b)
			if ((b["pos"] as Vector3) - _target).dot(heading) > RUN_OUT_PAST:
				(b["node"] as Node3D).visible = false
				var anim: AnimationPlayer = b["anim"]
				if anim != null:
					anim.pause()


func _advance(b: Dictionary, delta: float) -> void:
	var since: float = _t - TELEGRAPH - float(b["delay"])
	if since < 0.0:
		return
	var anim: AnimationPlayer = b["anim"]
	if not bool(b["running"]):
		b["running"] = true
		if anim != null:
			_play_from_anywhere(anim, "run", 0.7, 0.3)
	var stagger: float = maxf(0.0, float(b["stagger"]) - delta)
	b["stagger"] = stagger
	var pace: float = lerpf(0.7, 1.0, clampf(since / CHARGE_RAMP, 0.0, 1.0))
	if bool(b["wounded"]):
		pace *= WOUNDED_PACE
	if stagger > 0.0:
		pace *= 0.58                         # a hit buffalo breaks stride and drops back into the wall
	b["pos"] = (b["pos"] as Vector3) + heading * float(b["speed"]) * pace * delta
	if anim != null:
		anim.speed_scale = pace              # the hooves stay on the ground: the clip's stride is authored for SPEED


func _tick_audio(centre: Vector3, closest: Dictionary) -> void:
	var approach: float = clampf((_t - TELEGRAPH) / (START_DIST / SPEED), 0.0, 1.0)
	if _rumble != null:
		_rumble.global_position = centre
		_rumble.volume_db = lerpf(-10.0, 2.0, approach)
		_rumble.pitch_scale = lerpf(0.58, 0.78, approach)
	if _hooves != null:
		_hooves.global_position = centre
		_hooves.volume_db = lerpf(-15.0, -1.5, approach)
		_hooves.pitch_scale = lerpf(0.80, 1.06, approach)
	# A close pass is its own layer: the air and the ground move at once, just before the herd reaches him. Only if it really comes
	# close: a rider who cleared the band hears the herd go by behind him instead.
	if not _pass_played and _pass != null and not closest.is_empty() and _nearest < PASS_NEAR:
		_pass_played = true
		_pass.global_position = (closest["pos"] as Vector3) + Vector3(0.0, 1.0, 0.0)
		_pass.play()


func _finish() -> void:
	if done:
		return
	active = false
	done = true
	_nearest = 999.0
	for p in [_rumble, _hooves]:
		if p != null:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, 1.6)
			tw.tween_callback(p.stop)
	for d in _dust:
		(d as CPUParticles3D).emitting = false
	finished.emit(killed)


## Where the living animal is this frame. Everything heavy in its motion hangs off the stride of the clip it is playing: the body
## leaves the ground on the suspended phase, lands hard, and rocks from shoulders to rump over each stride.
func _place(b: Dictionary) -> void:
	var node: Node3D = b["node"]
	var p: Vector3 = b["pos"]
	var bob: float = float(b["bob"])
	var run: float = 1.0 if bool(b["running"]) else 0.0
	var stride: float = _stride_phase(b) * TAU
	var lift: float = 0.5 + 0.5 * sin(stride)
	p.y = lift * lift * STRIDE_BOUNCE * run
	p += Vector3(heading.z, 0.0, -heading.x) * sin(_t * 0.55 + bob) * 0.38 * run    # nobody holds a ruler-straight lane
	node.position = p
	var stagger: float = clampf(float(b["stagger"]) / STAGGER_S, 0.0, 1.0)
	var limp: float = 0.035 if bool(b["wounded"]) else 0.0
	# the rig's head is +X: turn +X onto the heading. So Z is its nose up/down and X is its roll.
	node.rotation.y = atan2(-heading.z, heading.x) + sin(stride * 0.5 + bob) * 0.022 * run
	node.rotation.z = (STRIDE_PITCH * sin(stride + 1.1) * run) - 0.21 * stagger
	node.rotation.x = (0.02 * sin(stride * 0.5 + bob) + limp * sin(stride)) * run + 0.11 * sin(_t * 17.0) * stagger


## 0..1 through the current stride.
func _stride_phase(b: Dictionary) -> float:
	var anim: AnimationPlayer = b["anim"]
	if anim != null and anim.is_playing() and anim.current_animation_length > 0.0:
		return anim.current_animation_position / anim.current_animation_length
	return fposmod(_t / STRIDE_S + float(b["bob"]), 1.0)


## A bison that dies at the gallop ploughs on, goes over its shoulder and stays down.
func _fall(b: Dictionary, delta: float) -> void:
	var node: Node3D = b["node"]
	var was: float = float(b["t_dead"])
	var t: float = was + delta
	b["t_dead"] = t
	if was >= FALL_S:
		return
	var k: float = clampf(t / FALL_S, 0.0, 1.0)
	if bool(b["running"]):
		b["pos"] = (b["pos"] as Vector3) + heading * float(b["speed"]) * 0.55 * (1.0 - k) * delta
	node.rotation.x = lerpf(0.0, PI * 0.5, k * k)        # rolls onto its side, stays down
	node.rotation.z = lerpf(node.rotation.z, 0.0, clampf(t * 3.0, 0.0, 1.0))
	var p: Vector3 = b["pos"]
	p.y = lerpf(0.0, 0.42, k * k)                        # it rolls about its feet: lifted by half its width, so it lies ON the ground
	node.position = p
	var anim: AnimationPlayer = b["anim"]
	if anim != null:
		anim.pause()
	if not bool(b["fallen_puffed"]) and t > 0.18:
		b["fallen_puffed"] = true
		_burst(b["pos"] as Vector3, 16, 0.5)


## Distance along the ray to the nearest living bison, or -1. Hits nothing.
func ray_distance(eye: Vector3, dir: Vector3) -> float:
	var best_t: float = -1.0
	for b in herd:
		var t: float = _ray_body(b, eye, dir)
		if t >= 0.0 and (best_t < 0.0 or t < best_t):
			best_t = t
	return best_t


## A shot along a ray: the nearest living bison it passes through takes the hit. Returns the hit distance, or -1.
func shoot(eye: Vector3, dir: Vector3, sharps: bool) -> float:
	var best: int = -1
	var best_t: float = 300.0
	for i in herd.size():
		var t: float = _ray_body(herd[i], eye, dir)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
	if best < 0:
		return -1.0
	var b: Dictionary = herd[best]
	var at: Vector3 = b["pos"] as Vector3
	var dead_now: bool = (b["health"] as Ep2CreatureHealth).take_hit(HP if sharps else 1, at)
	if dead_now:
		b["dead"] = true
		killed += 1
		bison_down.emit(at)
	else:
		# Wounded but still on its feet: it breaks stride, ducks its head and loses ground for a moment.
		b["stagger"] = STAGGER_S
		b["wounded"] = true
		_burst(at, 9, 0.32)
	bison_hit.emit(at, dead_now)
	_play_hit(at, dead_now)
	return best_t


func _play_hit(at: Vector3, kill: bool) -> void:
	if _hit_voice == null:
		return
	_hit_voice.global_position = at + Vector3(0.0, 1.1, 0.0)
	_hit_voice.pitch_scale = _hit_pitch * (0.86 if kill else 1.0) * _rng.randf_range(0.96, 1.04)
	_hit_voice.play()


## True when a living bison is under this ray (the HUD sight turns red).
func under_sight(eye: Vector3, dir: Vector3) -> bool:
	return ray_distance(eye, dir) >= 0.0


func _ray_body(b: Dictionary, eye: Vector3, dir: Vector3) -> float:
	if bool(b["dead"]) or not (b["node"] as Node3D).visible:
		return -1.0
	var c: Vector3 = (b["pos"] as Vector3) + Vector3(0.0, 1.15, 0.0)
	var a: Vector3 = c - heading * BODY_HALF
	var z: Vector3 = c + heading * BODY_HALF
	# closest approach between the ray and the body's segment
	var u: Vector3 = z - a
	var w0: Vector3 = eye - a
	var bb: float = dir.dot(u)
	var cc: float = u.dot(u)
	var dd: float = dir.dot(w0)
	var ee: float = u.dot(w0)
	var den: float = cc - bb * bb
	var sc: float = 0.0 if den < 1e-6 else maxf(0.0, (bb * ee - cc * dd) / den)
	var tc: float = clampf((ee + sc * bb) / cc, 0.0, 1.0)
	var gap: float = (eye + dir * sc).distance_to(a + u * tc)
	return sc if gap < BODY_R and sc > 0.5 else -1.0


## The soft round dust sprite, shared by the wall and the hit puffs.
func _puff_material() -> StandardMaterial3D:
	if _puff != null:
		return _puff
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	_puff = StandardMaterial3D.new()
	_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_puff.billboard_keep_scale = true          # without it every puff is drawn 1 m wide, whatever its scale
	_puff.albedo_texture = tex
	_puff.vertex_color_use_as_albedo = true
	_puff.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _puff


func _puff_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = _puff_material()
	return quad


func _burst(at: Vector3, amount: int, strength: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "HitDust"
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 1.35
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.75
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.8 * strength
	p.initial_velocity_max = 3.1 * strength
	p.gravity = Vector3(0, -1.2, 0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 3.8
	p.color = Color(0.78, 0.64, 0.47, 0.55)
	p.mesh = _puff_mesh()
	add_child(p)
	p.global_position = at + Vector3(0.0, 0.8, 0.0)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(p.queue_free)


func _build_dust(at: Vector3) -> void:
	for i in 3:
		var p := CPUParticles3D.new()
		p.name = "Dust%d" % i
		p.amount = 110
		p.lifetime = 4.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(9.0, 0.6, 9.0)
		p.direction = Vector3(0, 1, 0)
		p.spread = 70.0
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 2.2
		p.gravity = Vector3(0, 0.25, 0)
		p.scale_amount_min = 7.0
		p.scale_amount_max = 15.0
		p.color = Color(0.80, 0.66, 0.48, 0.5)
		p.mesh = _puff_mesh()
		add_child(p)
		p.global_position = at
		p.emitting = true
		_dust.append(p)


## No bison model (the streamed pack failed): a dark, shaggy block so the event still plays and reads.
func _stand_in() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 1.5, 1.1)
	body.mesh = box
	body.position = Vector3(0, 1.2, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.1, 0.06)
	body.material_override = m
	root.add_child(body)
	return root
