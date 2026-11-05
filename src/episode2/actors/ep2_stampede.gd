class_name Ep2Stampede
extends Node3D
## THE BUFFALO STAMPEDE (founder 2026-11-01 evening, "Guns Buff" §5): "a situation that takes place one time where a stampede of buffalos
## run towards Lil Blunt and he has the option of shooting them or getting out the way."
##
## On the lake trail, once per save (GameManager.ep2_stampede_done). A herd breaks out of the open desert beside the trail, a long rumble
## and a dust wall first (the telegraph), then it charges at the point where Lil Blunt is riding. Both answers work:
##   * SHOOT - a bison falls to one buffalo-gun round (two from anything else) and stays down; a thinned herd is a smaller wall,
##   * GET OUT OF THE WAY - ride on or rein back (W / S) out of the herd's band; it thunders across the trail behind or ahead of him.
## Caught in the herd: one heart and a wound to the horse (the room's own hurt / unhorse rules, so it is fair and retryable), never an
## instant death. When the last bison has crossed or fallen the event is over and the flag is written.
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
const BODY_R := 0.95                      # hit capsule radius
const BODY_HALF := 1.15                   # half its length along the heading
const TRAMPLE_R := 2.3                    # a bison this close to him (flat) tramples him
const HP_SHARPS := 1
const HP_OTHER := 2
const STAGGER_S := 0.42

signal trampled
signal finished(killed: int)
signal bison_down(at: Vector3)
signal bison_hit(at: Vector3, killed: bool)

var active: bool = false
var done: bool = false
var killed: int = 0
var trample_count: int = 0
var herd: Array = []                      # [{node, anim, pos, hp, dead, t_dead, lane, delay}]
var heading: Vector3 = Vector3.FORWARD
var _t: float = 0.0
var _rumble: AudioStreamPlayer3D = null
var _hooves: AudioStreamPlayer3D = null
var _pass: AudioStreamPlayer3D = null
var _hit_voice: AudioStreamPlayer3D = null
var _pass_played: bool = false
var _dust: Array = []
var _target: Vector3 = Vector3.ZERO


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
	var rng := RandomNumberGenerator.new()
	rng.seed = 1874
	for i in COUNT:
		var row: int = int(float(i) / 4.0)
		var col: float = float(i % 4) - 1.5
		var lane: float = col * 3.2 + rng.randf_range(-0.7, 0.7)
		var p: Vector3 = origin - heading * (float(row) * 4.2 + rng.randf_range(0.0, 1.6)) + side_v * lane
		var node: Node3D = packed.instantiate() as Node3D if packed != null else _stand_in()
		node.name = "Bison%d" % i
		add_child(node)
		node.scale = Vector3.ONE * rng.randf_range(0.95, 1.12)
		var anim: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false).front() if not node.find_children("*", "AnimationPlayer", true, false).is_empty() else null
		herd.append({"node": node, "anim": anim, "pos": p, "hp": 2, "dead": false, "t_dead": 0.0, "lane": lane,
			"bob": rng.randf_range(0.0, TAU), "speed": SPEED * rng.randf_range(0.94, 1.06),
			"stagger": 0.0, "wounded": false, "was_near": false, "fallen_puffed": false})
		_place(herd[i], 0.0)
		if anim != null:
			anim.get_animation("run").loop_mode = Animation.LOOP_LINEAR
			anim.play("run")
			anim.speed_scale = 0.0
	_build_dust(origin)
	_rumble = _voice("Rumble", _stream(RUMBLE, RUMBLE_FALLBACK), 42.0, 6.0)
	if _rumble != null:
		_rumble.pitch_scale = 0.62 if ResourceLoader.exists(RUMBLE) else 0.55
		_rumble.volume_db = -6.0
		_rumble.global_position = origin
		_rumble.play()
	_hooves = _voice("Hooves", _stream(HOOVES, RUMBLE_FALLBACK), 36.0, 4.0)
	if _hooves != null:
		_hooves.volume_db = -12.0
		_hooves.global_position = origin
		_hooves.play()
	_pass = _voice("PassBy", _stream(PASS_BY, ""), 30.0, 3.0)
	_hit_voice = _voice("BisonHit", _stream(HIT_SOUND, HIT_FALLBACK), 70.0, 2.0)
	active = true
	_t = 0.0
	_pass_played = false


func _stream(path: String, fallback: String) -> AudioStream:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as AudioStream
	if fallback != "" and ResourceLoader.exists(fallback):
		return load(fallback) as AudioStream
	return null


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


func step(delta: float, player: Vector3) -> void:
	if not active:
		return
	_t += delta
	var charging: bool = _t >= TELEGRAPH
	var alive: int = 0
	var centre := Vector3.ZERO
	for b in herd:
		if bool(b["dead"]):
			b["t_dead"] = float(b["t_dead"]) + delta
			_fall(b)
			continue
		alive += 1
		if charging:
			var stagger: float = maxf(0.0, float(b["stagger"]) - delta)
			b["stagger"] = stagger
			var move: float = float(b["speed"])
			if stagger > 0.0:
				move *= 0.58                     # a hit buffalo breaks stride and drops back into the wall
			b["pos"] = (b["pos"] as Vector3) + heading * move * delta
			var anim: AnimationPlayer = b["anim"]
			if anim != null:
				anim.speed_scale = 0.58 if stagger > 0.0 else 1.0
			# caught in the herd: one trample per pass of each bison (the room's own invulnerability spaces the hurts)
			var flat: Vector3 = (b["pos"] as Vector3) - player
			flat.y = 0.0
			var near: bool = flat.length() < TRAMPLE_R
			if near and not bool(b["was_near"]):
				trample_count += 1
				trampled.emit()
			b["was_near"] = near
		_place(b, _t)
		centre += b["pos"]
	if alive > 0:
		centre /= float(alive)
		var approach: float = clampf((_t - TELEGRAPH) / 9.0, 0.0, 1.0)
		if _rumble != null:
			_rumble.global_position = centre
			_rumble.volume_db = lerpf(-10.0, 2.0, approach)
			_rumble.pitch_scale = lerpf(0.58, 0.78, approach)
		if _hooves != null:
			_hooves.global_position = centre
			_hooves.volume_db = lerpf(-15.0, -1.5, approach)
			_hooves.pitch_scale = lerpf(0.80, 1.06, approach)
		# A close pass is its own layer: the air and the ground move at once, just before the herd reaches him.
		if not _pass_played and _pass != null and _t >= TELEGRAPH:
			var flat_to: Vector3 = player - centre
			flat_to.y = 0.0
			if flat_to.length() < 17.0 or ((centre - player).dot(heading) < 12.0 and (centre - player).dot(heading) > -12.0):
				_pass_played = true
				_pass.global_position = player + Vector3(0.0, 0.8, 0.0)
				_pass.play()
	for i in _dust.size():
		var d: CPUParticles3D = _dust[i]
		d.global_position = centre - heading * (2.0 + float(i) * 5.0) if alive > 0 else d.global_position
		d.emitting = alive > 0
	# over when every living bison is well past him (across the trail and away) or down
	var past: bool = true
	for b in herd:
		if not bool(b["dead"]) and ((b["pos"] as Vector3) - _target).dot(heading) < 40.0:
			past = false
	if charging and (alive == 0 or past):
		_finish()


func _finish() -> void:
	active = false
	done = true
	for p in [_rumble, _hooves]:
		if p != null:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, 1.6)
			tw.tween_callback(p.stop)
	for d in _dust:
		(d as CPUParticles3D).emitting = false
	finished.emit(killed)


func _place(b: Dictionary, t: float) -> void:
	var node: Node3D = b["node"]
	var p: Vector3 = b["pos"]
	if not bool(b["dead"]):
		var gallop: float = absf(sin(t * 8.5 + float(b["bob"])))
		p.y = gallop * (0.14 if t >= TELEGRAPH else 0.02)
		var sway: float = sin(t * 4.3 + float(b["bob"])) * 0.055
		node.position = p + Vector3(0.0, 0.0, 0.0)
		# the rig's head is +X: turn +X onto the heading
		node.rotation.y = atan2(-heading.z, heading.x)
		node.rotation.x = -0.025 * gallop
		node.rotation.z = sway + (0.10 * sin(t * 17.0) if float(b["stagger"]) > 0.0 else 0.0)
	else:
		node.position = p


func _fall(b: Dictionary) -> void:
	var node: Node3D = b["node"]
	var k: float = clampf(float(b["t_dead"]) / 0.55, 0.0, 1.0)
	node.rotation.x = lerpf(0.0, PI * 0.5, k * k)        # rolls onto its side, stays down
	node.rotation.z = lerpf(float(node.rotation.z), 0.0, clampf(float(b["t_dead"]) * 3.0, 0.0, 1.0))
	node.position.y = lerpf(0.0, 0.42, k * k)            # it rolls about its feet: lifted by half its width, so it lies ON the ground
	var anim: AnimationPlayer = b["anim"]
	if anim != null:
		anim.speed_scale = 0.0
	if not bool(b["fallen_puffed"]) and float(b["t_dead"]) > 0.18:
		b["fallen_puffed"] = true
		_burst(b["pos"] as Vector3, 16, 0.5)


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
	b["hp"] = int(b["hp"]) - (2 if sharps else 1)
	var at: Vector3 = b["pos"] as Vector3
	var dead_now: bool = int(b["hp"]) <= 0
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


func _play_hit(at: Vector3, _killed_by_hit: bool) -> void:
	if _hit_voice == null or _hit_voice.stream == null:
		return
	_hit_voice.global_position = at + Vector3(0.0, 1.1, 0.0)
	_hit_voice.pitch_scale = 0.92 if str(_hit_voice.stream.resource_path).contains("bison_hit") else 0.72
	_hit_voice.volume_db = 0.0
	_hit_voice.play()


## True when a living bison is under this ray (the HUD sight turns red).
func under_sight(eye: Vector3, dir: Vector3) -> bool:
	for b in herd:
		if _ray_body(b, eye, dir) >= 0.0:
			return true
	return false


func _ray_body(b: Dictionary, eye: Vector3, dir: Vector3) -> float:
	if bool(b["dead"]):
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


func _burst(at: Vector3, amount: int, strength: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
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
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = mat
	p.mesh = quad
	add_child(p)
	p.global_position = at + Vector3(0.0, 0.8, 0.0)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(p.queue_free)


func _build_dust(at: Vector3) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true          # without it every puff is drawn 1 m wide, whatever its scale
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
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
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		quad.material = mat
		p.mesh = quad
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
