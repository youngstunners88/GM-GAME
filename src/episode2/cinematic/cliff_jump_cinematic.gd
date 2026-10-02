class_name CliffJumpCinematic
extends Node3D
## THE CLIFF JUMP - the film between the end of The Descent and the Smelting Facility.
## Founder 2026-09-30: "the end of it must lead to a cliff that has a gap to the other side where Inferno
## Bull is situated, but the clip will cut and we will see the film of Lil Blunt in the cart flying over the
## cliff as he jumps out the cart in the nick of time. He lands on the other side by rolling and tumbling and
## hitting his head on a rock. He passes out ... action packed with a slow mo section as he flies over the gap."
##
## Built per skill ep2-cinematic-cutscene:
##  * TWO CLOCKS. `_real` drives the cameras, shake, frame dressing and audio; `_act` drives the cart, the hero
##    and the action particles at `_speed()` of real time. That is what makes it bullet time: the orbit camera
##    keeps moving at full speed while Lil Blunt hangs over the gorge. Engine.time_scale is never touched.
##  * Motion is closed-form (ballistic arcs, a decelerating roll), so `scrub()` can show any moment and the
##    test can prove he clears the far lip while the cart does not.
##  * Web-safe: CPUParticles3D only (GPUParticles fail on some AMD/ANGLE web targets, godot#95797) and no audio
##    bus effects (a runtime bus-graph call once silenced the whole web build) - slow-mo audio is pitch + duck.
##  * Hand-back contract: `finished` exactly once; `release()` fades the frame back in and frees everything.

signal finished
## Story events, for tests and the owner: launch, slowmo, cart_crash, land, head_hit, blackout.
signal event(name: String)

## The rigged Bull (origin at his feet, 2.4 m native); its rest pose is the founder's statue pose.
const BULL_MODEL := "res://src/episode2/assets/inferno_bull_rigged.glb"
const CRUCIBLE_MODEL := "res://src/episode2/assets/crucible.glb"
const ROCK_TEX := "res://src/episode2/assets/textures/tex_rock_wall.jpg"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const SND := "res://src/assets/sounds/"
const POST_SHADER := "res://src/episode2/cinematic/film_post.gdshader"

# --- The set (metres, film-local). Track along +Z; rail top y = 0; the near cliff face / tunnel mouth at z = 0.
const LIP_Z := 3.0              # the broken trestle ends here
const FAR_LIP_Z := 19.0         # the far ledge starts here
const FAR_Y := -1.0             # far ledge surface (a little lower: the leap arcs DOWN into the landing)
const CHASM_Y := -34.0
## The film picks the cart up where the runner leaves it: RunnerGraybox.CLIFF_HANDOFF m short of the mouth, at
## cruising speed - a match-cut, with no replay of the approach.
const CART_START_Z := -14.0
const CART_SPEED := 28.0
const CART_FLY_V := Vector3(0.0, -1.0, 12.0)   # the front wheels catch the snapped rail: the cart pitches and loses speed
const CART_SPIN := 2.3                          # rad / action-second, nose down
const HERO_LEAP_V := Vector3(0.0, 6.5, 17.0)   # ...and its rider keeps his: he is thrown/leaps out forward
const GRAVITY := 9.8
const HIP_H := RunnerView.HERO_HIP_H * RunnerView.HERO_SCALE    # pivot = hips
const TUCK_H := 0.62            # hip height while rolling in a tuck
const TUMBLE_LEN := 7.0
const ROLL_TURNS := 1.25        # one full roll + a quarter: he meets the rock HEAD first
const SLOW := 0.3               # bullet-time speed (action seconds per real second)
const SLOW_RAMP := 0.12         # action seconds to ease into slow-mo
const BLACKOUT_LEN := 4.4       # real seconds from the head hit's aftermath to black
const SKIP_HOLD := 0.6

# --- derived timeline (action seconds), filled in _init
var a_launch: float
var a_crash: float
var a_land: float
var a_rest: float
var land_z: float
var rock_z: float
var _hero_p0: Vector3
var _cart_hit_z: float

# --- state
var _real: float = 0.0
var _act: float = 0.0
var _shot: String = ""
var _shot_real0: float = 0.0
var _fired: Dictionary = {}
var _done: bool = false
var _started: bool = false
var _blackout_real0: float = -1.0
var _trauma: float = 0.0
var _flash: float = 0.0
var _fov_kick: float = 0.0
var _skip_t: float = 0.0
var _skip_armed: bool = false
var _releasing: float = -1.0
var _prev_cam: Camera3D = null

var _set: Node3D
var _cam: Camera3D
var _cart: Node3D
var _cart_sparks: CPUParticles3D
var _hero_pivot: Node3D
var _hero: Node3D
var _arm_rest: RunnerArmRest = null
var _bull: Node3D
var _post: ShaderMaterial
var _overlay: CanvasLayer
var _noise := FastNoiseLite.new()
var _action_fx: Array[CPUParticles3D] = []
var _players: Array[AudioStreamPlayer] = []
var _rumble: AudioStreamPlayer = null
var _rim_y: float = 1.0


func _init() -> void:
	a_launch = (LIP_Z - CART_START_Z) / CART_SPEED
	_cart_hit_z = FAR_LIP_Z - 0.95
	a_crash = a_launch + (_cart_hit_z - LIP_Z) / CART_FLY_V.z
	_noise.seed = 1886
	_noise.frequency = 1.0


func _ready() -> void:
	_build_set()
	_build_overlay()
	# Everything that depends on the rim height of the fitted cart.
	_hero_p0 = Vector3(0.0, _rim_y + 0.35, LIP_Z)
	# Landing: hips come down to tuck height on the far ledge.
	var y0: float = _hero_p0.y - (FAR_Y + TUCK_H)
	var t_land: float = (HERO_LEAP_V.y + sqrt(HERO_LEAP_V.y * HERO_LEAP_V.y + 2.0 * GRAVITY * y0)) / GRAVITY
	a_land = a_launch + t_land
	land_z = LIP_Z + HERO_LEAP_V.z * t_land
	rock_z = land_z + TUMBLE_LEN + 0.55
	a_rest = a_land + 2.0 * TUMBLE_LEN / HERO_LEAP_V.z
	_place_far_side()
	_pose(0.0)


# --- public API -----------------------------------------------------------------------------------------

## Take the screen. Call once; `finished` follows ~11 s later (or on skip).
func start() -> void:
	if _started:
		return
	_started = true
	_prev_cam = get_viewport().get_camera_3d()
	_cam.make_current()
	_overlay.visible = true
	_play_sfx("ep2_film_cart_rumble", -4.0)
	_rumble = _players[-1] if not _players.is_empty() else null
	_play_vo("vo_lb_cliff_yell", 1.12)
	_set_shot("emerge")


## Deterministic advance on the REAL clock (the owner calls this every frame).
func step(delta: float) -> void:
	if not _started or _done:
		if _releasing >= 0.0:
			_step_release(delta)
		return
	_real += delta
	_act += delta * _speed(_act)
	_trauma = maxf(0.0, _trauma - delta * 1.1)
	_flash = maxf(0.0, _flash - delta * 7.0)
	_fov_kick = maxf(0.0, _fov_kick - delta * 12.0)
	_step_skip(delta)
	if _done:
		return
	_fire_events()
	_pick_shot()
	_pose(_act)
	for p in _action_fx:
		if is_instance_valid(p):
			p.speed_scale = _speed(_act)
	for sp in _players:
		if is_instance_valid(sp) and sp.has_meta("action"):
			sp.pitch_scale = 0.62 if _speed(_act) < 0.99 else 1.0
	_update_camera(delta)
	_update_post()
	if _blackout_real0 >= 0.0 and _real - _blackout_real0 >= BLACKOUT_LEN:
		_finish()


## Show action time `a` (tests + capture boards). Does not fire events.
func scrub(a: float) -> void:
	_act = a
	_pose(a)
	_pick_shot()
	_update_camera(0.0)


## End now, as if the film had played out (hold jump / enter).
func skip() -> void:
	if _done:
		return
	_act = a_rest + 1.0
	_pose(_act)
	_finish()


## After `finished`: fade the frame back in over `seconds` and free the film.
func release(seconds: float = 1.6) -> void:
	_releasing = maxf(seconds, 0.01)
	_post.set_shader_parameter("fade", 1.0)
	_set.visible = false


func is_finished() -> bool: return _done
func get_shot() -> String: return _shot
func get_action_time() -> float: return _act
func get_real_time() -> float: return _real
func hero_position() -> Vector3: return _hero_pivot.position
func cart_position() -> Vector3: return _cart.position
func fired(name: String) -> bool: return _fired.has(name)


# --- clocks + events --------------------------------------------------------------------------------------

## Bullet time: full speed to the leap, ease down into slow-mo, hold across the gap, SNAP back when the
## cart hits the far wall (the impact is what the snap sells).
func _speed(a: float) -> float:
	if a < a_launch or a >= a_crash:
		return 1.0
	var t: float = clampf((a - a_launch) / SLOW_RAMP, 0.0, 1.0)
	return lerpf(1.0, SLOW, t * t * (3.0 - 2.0 * t))


func _fire_events() -> void:
	if _act >= a_launch and _once("launch"):
		_trauma = maxf(_trauma, 0.55)
		_fov_kick = 9.0
		if _rumble and is_instance_valid(_rumble):
			_rumble.stop()
		_cart_sparks.emitting = false
		_play_sfx("ep2_film_trestle_snap", 6.0, true)
		_play_sfx("ep2_cart_smash", -2.0, true)
		_burst(Vector3(0.0, 0.2, LIP_Z), 40, Color(1.0, 0.62, 0.22), 0.05, 7.0, 1.0, true)
		_debris(Vector3(0.0, 0.1, LIP_Z), 26)
	if _act >= a_launch + SLOW_RAMP * 0.5 and _once("slowmo"):
		_play_sfx("ep2_film_whoosh_slowmo", -2.0)
		_play_sfx("ep2_film_heartbeat", 0.0)
		_play_vo("vo_lb_airborne", 0.78)
	if _act >= a_crash and _once("cart_crash"):
		_trauma = maxf(_trauma, 0.6)
		_play_sfx("ep2_film_impact_boom", -1.0)
		_play_sfx("ep2_film_cart_crash_far", 4.0)
		_burst(_cart.position, 60, Color(1.0, 0.55, 0.2), 0.06, 9.0, 1.2, true)
		_dust(_cart.position, 30, Color(0.55, 0.48, 0.42))
	if _act >= a_land and _once("land"):
		_trauma = maxf(_trauma, 0.75)
		_play_sfx("ep2_film_land_thud", 8.0)
		_play_sfx("ep2_film_tumble", 8.0)
		_dust(Vector3(0.0, FAR_Y + 0.1, land_z), 46, Color(0.62, 0.52, 0.40))
	if _act >= a_rest and _once("head_hit"):
		_trauma = 1.0
		_flash = 1.0
		_play_sfx("ep2_film_head_clonk", 8.0)
		_play_sfx("ep2_film_tinnitus", 0.0)
		_debris(Vector3(0.0, FAR_Y + 0.6, rock_z - 0.4), 10)
	if _act >= a_rest + 0.55 and _once("blackout"):
		_blackout_real0 = _real
		_play_vo("vo_lb_head_ow", 0.92)
		_play_sfx("ep2_film_heartbeat", -4.0)


func _once(name: String) -> bool:
	if _fired.has(name):
		return false
	_fired[name] = true
	event.emit(name)
	return true


func _step_skip(delta: float) -> void:
	var held: bool = Input.is_action_pressed("jump") or Input.is_action_pressed("ui_accept")
	if not held:
		_skip_armed = true           # a key still held from the runner never counts
		_skip_t = 0.0
		return
	if _skip_armed:
		_skip_t += delta
		if _skip_t >= SKIP_HOLD:
			skip()


func _finish() -> void:
	if _done:
		return
	_done = true
	for sp in _players:
		if is_instance_valid(sp):
			sp.stop()
	_post.set_shader_parameter("fade", 1.0)
	_post.set_shader_parameter("flash", 0.0)
	finished.emit()


func _step_release(delta: float) -> void:
	_releasing -= delta
	var k: float = clampf(_releasing / 1.6, 0.0, 1.0)
	_post.set_shader_parameter("fade", k)
	_post.set_shader_parameter("bars", k)
	if _releasing <= 0.0:
		_releasing = -1.0
		if _prev_cam and is_instance_valid(_prev_cam) and get_viewport().get_camera_3d() == _cam:
			_prev_cam.make_current()
		queue_free()


# --- motion (closed form in action time) ------------------------------------------------------------------

func _pose(a: float) -> void:
	# The cart: rails, then ballistic + nose-down spin, a slam into the far wall, then the long fall.
	if a < a_launch:
		_cart.position = Vector3(0.0, 0.0, CART_START_Z + CART_SPEED * a)
		_cart.rotation = Vector3.ZERO
	else:
		var t: float = a - a_launch
		var tc: float = a_crash - a_launch
		if a < a_crash:
			_cart.position = Vector3(0.0, CART_FLY_V.y * t - 0.5 * GRAVITY * t * t, LIP_Z + CART_FLY_V.z * t)
		else:
			var hit := Vector3(0.0, CART_FLY_V.y * tc - 0.5 * GRAVITY * tc * tc, _cart_hit_z)
			var t2: float = a - a_crash
			var vy0: float = CART_FLY_V.y - GRAVITY * tc
			_cart.position = hit + Vector3(0.6 * t2, vy0 * t2 - 0.5 * GRAVITY * t2 * t2, -1.8 * t2)
		_cart.rotation = Vector3(CART_SPIN * t, 0.0, 0.35 * t)
	_cart.visible = _cart.position.y > CHASM_Y + 2.0

	# The hero: seated -> thrown/leaping (bind pose = arms up, legs splayed) -> tuck and roll -> head first
	# into the rock -> flops onto his back.
	var infl: float = 1.0
	if a < a_launch:
		_hero_pivot.position = _cart.position + Vector3(0.0, _rim_y + RunnerView.HERO_HIP_OVER_RIM, 0.0)
		_hero_pivot.basis = Basis(Vector3.UP, -0.1)
	elif a < a_land:
		var t: float = a - a_launch
		_hero_pivot.position = _hero_p0 + HERO_LEAP_V * t + Vector3(0.0, -0.5 * GRAVITY * t * t, 0.0)
		var f: float = t / (a_land - a_launch)
		# arms fly up for the leap, tuck back in for the landing
		infl = 1.0 - clampf(t / 0.18, 0.0, 1.0) * (1.0 - smoothstep(0.72, 1.0, f))
		_hero_pivot.basis = Basis(Vector3.RIGHT, lerpf(0.0, 0.9, f)) * Basis(Vector3.UP, lerpf(-0.1, 0.35, f))
	elif a < a_rest:
		var tau: float = a - a_land
		var T: float = a_rest - a_land
		var v: float = HERO_LEAP_V.z
		var dec: float = v / T
		var s: float = v * tau - 0.5 * dec * tau * tau
		var f2: float = tau / T
		var bounce: float = absf(sin(f2 * PI * 2.0)) * 0.55 * (1.0 - f2)
		_hero_pivot.position = Vector3(0.0, FAR_Y + TUCK_H + bounce, land_z + s)
		var theta: float = 0.9 + (ROLL_TURNS * TAU - 0.9 + PI * 0.5) * (s / TUMBLE_LEN)
		_hero_pivot.basis = Basis(Vector3.RIGHT, theta) * Basis(Vector3.UP, 0.35 * (1.0 - f2))
	else:
		# Flop from "head in the rock, face down" onto his back, head against the rock.
		var k: float = clampf((a - a_rest) / 0.45, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		var hit_basis := Basis(Vector3.RIGHT, ROLL_TURNS * TAU + PI * 0.5)
		var lying := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
		_hero_pivot.basis = Basis(hit_basis.get_rotation_quaternion().slerp(lying.get_rotation_quaternion(), k))
		var rest_z: float = land_z + TUMBLE_LEN
		_hero_pivot.position = Vector3(0.0, lerpf(FAR_Y + TUCK_H, FAR_Y + 0.32, k), lerpf(rest_z, rock_z - 1.75, k))
		infl = lerpf(1.0, 0.3, k)
	if _arm_rest:
		_arm_rest.influence = infl


# --- cameras ----------------------------------------------------------------------------------------------

func _pick_shot() -> void:
	var want: String
	if _act < a_launch - 0.16:
		want = "emerge"
	elif _act < a_launch + 0.2:
		want = "lip"
	elif _act < a_land - 0.12:
		# Bullet time carries across the whole gap; the cart's crash below is heard (boom + the snap back
		# to full speed), not cut to - a profile/drop shot put the hero at speck size (see the skill).
		want = "orbit"
	elif _act < a_rest - 0.35:
		want = "landing"
	elif _act < a_rest + 0.55:
		want = "rock"
	else:
		want = "blackout"
	if want != _shot:
		_set_shot(want)


func _set_shot(name: String) -> void:
	_shot = name
	_shot_real0 = _real


func _update_camera(_delta: float) -> void:
	var u: float = _real - _shot_real0
	var h: Vector3 = _hero_pivot.position
	var pos: Vector3
	var look: Vector3
	var fov: float = 55.0
	match _shot:
		"emerge":
			# Wide from the far ledge: the dark tunnel mouth in the cliff, sparks coming out of the black.
			pos = Vector3(4.2, 2.3, 14.5).lerp(Vector3(2.9, 1.5, 11.0), clampf(u / 0.6, 0.0, 1.0))
			look = Vector3(0.0, 1.8, -4.0).lerp(_cart.position + Vector3(0.0, 1.2, 0.0), 0.5)
			fov = 56.0
			_trauma = maxf(_trauma, 0.12 + 0.2 * clampf(u / 2.0, 0.0, 1.0))
		"lip":
			# Low and close beside the snapped trestle, looking up as he is thrown over the lens.
			# Out over the gorge, low, looking back up at the tunnel mouth as he is thrown at the lens.
			pos = Vector3(3.6, -2.3, LIP_Z + 5.2)
			look = h + Vector3(0.0, 0.3, 0.0)
			fov = 70.0
		"orbit":
			# Bullet time: the camera circles him at REAL speed while he hangs over the gorge.
			var ang: float = deg_to_rad(lerpf(205.0, 335.0, clampf(u / 3.0, 0.0, 1.0)))
			var r: float = lerpf(4.6, 3.5, clampf(u / 3.0, 0.0, 1.0))
			pos = h + Vector3(sin(ang) * r, 0.75 + 0.25 * sin(u * 1.3), cos(ang) * r)
			look = h + Vector3(0.0, 0.35, 0.0)
			fov = 50.0
		"landing":
			# Ground level on the far ledge: he slams down and rolls at the lens.
			pos = Vector3(1.9, FAR_Y + 0.35, land_z + 4.6)
			look = h.lerp(Vector3(0.0, FAR_Y + 0.6, land_z), 0.35)
			fov = 64.0
		"rock":
			pos = Vector3(-1.9, FAR_Y + 0.55, rock_z - 1.6)
			look = Vector3(0.0, FAR_Y + 0.5, rock_z - 0.7).lerp(h, 0.4)
			fov = 44.0
		_:
			# Blackout: over his face, then up to the Bull looming in the furnace light, fading out.
			var k: float = clampf(u / (BLACKOUT_LEN * 0.8), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var head: Vector3 = _head_pos()
			var bull_head: Vector3 = _bull.position + Vector3(0.0, 2.7, 0.0) if _bull else head + Vector3(0, 2, 2)
			# Over his face first; then down at his eye line, looking UP at the Bull standing over him.
			pos = (head + Vector3(0.9, 1.5, -0.9)).lerp(head + Vector3(-0.5, 0.25, -0.6), k)
			look = head.lerp(bull_head, k)
			fov = lerpf(46.0, 58.0, k)
	if _bull:
		_bull.visible = _shot == "blackout"
	_cam.fov = fov + _fov_kick
	_cam.global_position = _set.to_global(pos)
	_cam.look_at(_set.to_global(look), Vector3.UP)
	# Trauma shake: rotational, trauma^3, smooth noise on the REAL clock (skill: Eiserloh GDC 2016).
	var s: float = _trauma * _trauma * _trauma
	if s > 0.0001:
		var t: float = _real * 14.0
		_cam.rotate_object_local(Vector3.UP, deg_to_rad(5.0) * s * _noise.get_noise_2d(t, 11.0))
		_cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(5.0) * s * _noise.get_noise_2d(t, 37.0))
		_cam.rotate_object_local(Vector3.BACK, deg_to_rad(4.0) * s * _noise.get_noise_2d(t, 73.0))


func _update_post() -> void:
	var slow: bool = _speed(_act) < 0.99
	_post.set_shader_parameter("bars", clampf(_real / 0.3, 0.0, 1.0))
	_post.set_shader_parameter("sat", 0.72 if slow else 1.0)
	_post.set_shader_parameter("vignette", 0.62 if slow else 0.3)
	_post.set_shader_parameter("flash", _flash)
	if _blackout_real0 >= 0.0:
		var b: float = clampf((_real - _blackout_real0) / BLACKOUT_LEN, 0.0, 1.0)
		_post.set_shader_parameter("double_px", 14.0 * sin(b * PI * 3.0) * (0.4 + b))
		_post.set_shader_parameter("blur_px", 3.5 * b)
		_post.set_shader_parameter("vignette", lerpf(0.5, 1.4, b))
		_post.set_shader_parameter("sat", lerpf(0.9, 0.35, b))
		_post.set_shader_parameter("fade", smoothstep(0.55, 1.0, b))


## Where his head actually is (the skeleton, not a guess), in film-set space.
func _head_pos() -> Vector3:
	if _hero:
		for sk in _hero.find_children("*", "Skeleton3D", true, false):
			var skel := sk as Skeleton3D
			var hb: int = skel.find_bone("Head")
			if hb >= 0:
				return _set.to_local(skel.global_transform * skel.get_bone_global_pose(hb).origin)
	return _hero_pivot.position + Vector3(0.0, 0.3, 1.2)


# --- the set --------------------------------------------------------------------------------------------

func _build_set() -> void:
	_set = Node3D.new()
	_set.name = "FilmSet"
	add_child(_set)
	_cam = Camera3D.new()
	_cam.name = "FilmCamera"
	_cam.near = 0.05
	_cam.far = 400.0
	_cam.environment = _make_env()
	add_child(_cam)
	var rock: StandardMaterial3D = _tex_mat(ROCK_TEX, Color(0.62, 0.52, 0.44), 0.18)
	var rock_dark: StandardMaterial3D = _tex_mat(ROCK_TEX, Color(0.36, 0.30, 0.26), 0.12)
	var timber: StandardMaterial3D = _tex_mat(TIMBER_TEX, Color(0.75, 0.55, 0.38), 0.5)

	# Near cliff face with the tunnel mouth (11.5 m wide, 7.5 m tall).
	_box(Vector3(34.0, 90.0, 8.0), Vector3(-5.75 - 17.0, -15.0, -4.0), rock)
	_box(Vector3(34.0, 90.0, 8.0), Vector3(5.75 + 17.0, -15.0, -4.0), rock)
	_box(Vector3(11.5, 30.0, 8.0), Vector3(0.0, 7.5 + 15.0, -4.0), rock)
	_box(Vector3(11.5, 58.0, 5.5), Vector3(0.0, -0.35 - 29.0, -2.9), rock_dark)
	# The tunnel behind the mouth: the same Meshy shell the player just rode through.
	var shell_y: float = -0.1 - RunnerView.SHELL_NATIVE_FLOOR * RunnerView.SHELL_SCALE.y
	for k in 5:
		var sh: Node3D = _inst(RunnerView.TUNNEL_SHELL_MODEL)
		if sh:
			sh.scale = RunnerView.SHELL_SCALE
			sh.rotation.y = PI if k % 2 == 1 else 0.0
			sh.position = Vector3(0.0, shell_y, -8.2 - float(k) * RunnerView.SHELL_STEP)
			RunnerView.self_light(sh, 0.05, Color(1.0, 0.72, 0.42))
			_set.add_child(sh)
	_box(Vector3(12.0, 0.3, 80.0), Vector3(0.0, -0.45, -40.0), rock_dark)
	# Rails for the three lanes, running out onto a snapped trestle past the lip.
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.72, 0.42, 0.22)
	copper.metallic = 0.3
	copper.roughness = 0.35
	copper.emission_enabled = true
	copper.emission = Color(0.9, 0.5, 0.25)
	copper.emission_energy_multiplier = 0.12
	for lx in [2.5, 0.0, -2.5]:
		var end_z: float = LIP_Z if lx == 0.0 else LIP_Z - 1.2 - absf(lx) * 0.3
		for side in [-0.55, 0.55]:
			var len: float = end_z + 80.0
			_box(Vector3(0.09, 0.12, len), Vector3(lx + side, -0.06, end_z - len * 0.5), copper)
		var zz: float = -78.0
		while zz < end_z:
			_box(Vector3(1.6, 0.14, 0.26), Vector3(lx, -0.2, zz), timber)
			zz += 0.9
	# Trestle legs under the part that hangs out over the gorge, one of them snapped.
	for tz in [0.8, 2.2]:
		for tx in [-3.2, -0.6, 0.6, 3.2]:
			var h: float = 7.0 if not (tz == 2.2 and tx == 0.6) else 2.2
			_box(Vector3(0.28, h, 0.28), Vector3(tx, -0.3 - h * 0.5, tz), timber)
		_box(Vector3(7.2, 0.3, 0.3), Vector3(0.0, -2.2, tz), timber)
	for n in 5:
		var splinter := _box(Vector3(0.12, 0.12, 0.9), Vector3(-0.4 + 0.2 * float(n), -0.2, LIP_Z + 0.25), timber)
		splinter.rotation = Vector3(0.5 - 0.25 * float(n), 0.3 * float(n - 2), 0.0)

	# The gorge: molten gold far below, glowing up the walls; embers rising.
	var lava := StandardMaterial3D.new()
	lava.albedo_color = Color(1.0, 0.42, 0.08)
	lava.emission_enabled = true
	lava.emission = Color(1.0, 0.45, 0.1)
	lava.emission_energy_multiplier = 4.5
	lava.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(Vector3(90.0, 0.5, 40.0), Vector3(0.0, CHASM_Y, FAR_LIP_Z * 0.5), lava)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.18)
	glow.light_energy = 9.0
	glow.omni_range = 46.0
	glow.omni_attenuation = 0.8
	glow.position = Vector3(0.0, -18.0, FAR_LIP_Z * 0.5)
	_set.add_child(glow)
	var embers := _particles(160, 7.0, Color(1.0, 0.55, 0.15), 0.07, false)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(22.0, 14.0, 8.0)
	embers.position = Vector3(0.0, -12.0, FAR_LIP_Z * 0.5)
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.gravity = Vector3(0.0, 0.8, 0.0)
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 2.2
	embers.preprocess = 7.0
	embers.emitting = true
	_set.add_child(embers)

	# The cavern roof far above, split by a crack of cold daylight falling across the gap (the MW grade:
	# warm molten light from below, teal daylight from above).
	_box(Vector3(120.0, 4.0, 160.0), Vector3(0.0, 40.0, 20.0), rock_dark)
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(0.58, 0.74, 1.0)
	shaft.light_energy = 5.5
	shaft.spot_range = 70.0
	shaft.spot_angle = 16.0
	shaft.position = Vector3(-10.5, 37.0, 12.0)
	shaft.rotation = Vector3(deg_to_rad(-84.0), 0.0, deg_to_rad(-6.0))
	_set.add_child(shaft)

	# A cold fill from the roof crack so rock has shape everywhere (no shadows: web budget).
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.72, 0.9)
	fill.light_energy = 0.55
	fill.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-35.0), 0.0)
	_set.add_child(fill)
	# Break the cliff silhouettes: boulders around the tunnel mouth, along both lips and down the faces.
	for spec in [[-7.5, 0.0, -0.5, 4.5], [7.8, 0.0, -0.4, 5.2], [-6.4, 8.2, -0.6, 3.6], [6.0, 8.6, -0.6, 4.2],
			[0.8, 9.6, -0.8, 3.0], [-12.0, 3.0, -0.3, 6.0], [12.5, 2.0, -0.3, 6.5], [-9.0, -9.0, -0.2, 5.5],
			[9.5, -12.0, -0.2, 6.0], [-4.0, -18.0, -0.4, 5.0], [4.5, -24.0, -0.4, 5.5],
			[-3.0, -6.0, 0.6, 4.0], [3.2, -8.5, 0.4, 4.5], [-15.0, -20.0, 0.2, 7.0], [15.0, -4.0, 0.2, 6.0],
			[-18.0, 10.0, 0.0, 8.0], [18.0, 12.0, 0.0, 8.0]]:
		_boulder(Vector3(float(spec[0]), float(spec[1]), float(spec[2])), float(spec[3]))
	# Rock spires rising out of the gorge: parallax for the orbit shot.
	for sp in [[-9.0, 8.0, 14.0], [10.0, 12.0, 18.0], [-15.0, 14.0, 22.0], [16.0, 5.0, 20.0], [-4.0, 16.0, 12.0]]:
		var spire_mesh := CylinderMesh.new()
		spire_mesh.top_radius = 0.4
		spire_mesh.bottom_radius = float(sp[2]) * 0.18
		spire_mesh.height = float(sp[2])
		var spire := MeshInstance3D.new()
		spire.mesh = spire_mesh
		spire.material_override = rock_dark
		spire.position = Vector3(float(sp[0]), CHASM_Y + float(sp[2]) * 0.5, float(sp[1]))
		_set.add_child(spire)

	# Tunnel lanterns so the cart has light to burst out of.
	for lz in [-9.0, -24.0, -39.0]:
		var ll := OmniLight3D.new()
		ll.light_color = Color(1.0, 0.7, 0.36)
		ll.light_energy = 2.2
		ll.omni_range = 9.0
		ll.position = Vector3(-4.2 if int(lz) % 2 == 0 else 4.2, 3.2, lz)
		_set.add_child(ll)

	# The cart + its rider.
	_cart = Node3D.new()
	_cart.name = "Cart"
	_set.add_child(_cart)
	var leaf: Node3D = _inst(RunnerView.LEAF_CART_MODEL)
	if leaf:
		var bb: AABB = _measure(leaf)
		var s: float = RunnerView.LEAF_CART_LEN / bb.size.z if bb.size.z > 0.01 else 1.0
		leaf.scale = Vector3.ONE * s
		leaf.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * s, -bb.position.y * s,
			-(bb.position.z + bb.size.z * 0.5) * s)
		_cart.add_child(leaf)
		_rim_y = bb.size.y * s
	else:
		_box(Vector3(1.6, 1.0, 2.2), Vector3(0.0, 0.5, 0.0), timber, _cart)
	var cart_lamp := OmniLight3D.new()
	cart_lamp.light_color = Color(1.0, 0.76, 0.45)
	cart_lamp.light_energy = 2.6
	cart_lamp.omni_range = 6.0
	cart_lamp.position = Vector3(0.0, 2.6, -1.2)
	_cart.add_child(cart_lamp)
	_cart_sparks = _particles(70, 0.45, Color(1.0, 0.62, 0.2), 0.05, false)
	_cart_sparks.position = Vector3(0.0, 0.05, 0.6)
	_cart_sparks.direction = Vector3(0.0, 0.4, -1.0)
	_cart_sparks.spread = 30.0
	_cart_sparks.initial_velocity_min = 3.0
	_cart_sparks.initial_velocity_max = 7.0
	_cart_sparks.gravity = Vector3(0.0, -9.8, 0.0)
	_cart_sparks.local_coords = false
	_cart_sparks.emitting = true
	_cart.add_child(_cart_sparks)
	_action_fx.append(_cart_sparks)

	_hero_pivot = Node3D.new()
	_hero_pivot.name = "HeroPivot"
	_set.add_child(_hero_pivot)
	_hero = _inst(RunnerView.HERO_MODEL)
	if _hero:
		_hero.scale = Vector3(-RunnerView.HERO_SCALE, RunnerView.HERO_SCALE, RunnerView.HERO_SCALE)
		_hero.position = Vector3(0.0, -HIP_H, 0.0)
		_hero_pivot.add_child(_hero)
		for ap in _hero.find_children("*", "AnimationPlayer", true, false):
			(ap as AnimationPlayer).stop()
		var sks: Array = _hero.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			_arm_rest = RunnerArmRest.new()
			_arm_rest.body_frame = true          # he rolls and lies down: limbs follow the body, not the world
			(sks[0] as Skeleton3D).add_child(_arm_rest)
		RunnerView.self_light(_hero, 0.08, Color(1.0, 0.86, 0.66))
		RunnerView.brighten_hero(_hero)
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.84, 0.62)
	key.light_energy = 2.4
	key.omni_range = 6.0
	key.position = Vector3(1.6, 2.2, -1.4)
	_hero_pivot.add_child(key)


## The far side depends on where the landing and the rock are, so it is placed after the timeline is known.
func _place_far_side() -> void:
	var rock: StandardMaterial3D = _tex_mat(ROCK_TEX, Color(0.66, 0.55, 0.46), 0.18)
	var timber: StandardMaterial3D = _tex_mat(TIMBER_TEX, Color(0.75, 0.55, 0.38), 0.5)
	# The ledge (top at FAR_Y) and its face down into the gorge.
	_box(Vector3(90.0, 60.0, 80.0), Vector3(0.0, FAR_Y - 30.0, FAR_LIP_Z + 40.0), rock)
	# Rubble along the lip and the landing strip, big boulders framing the path.
	for spec in [[-6.5, FAR_LIP_Z + 1.2, 2.6], [6.8, FAR_LIP_Z + 2.0, 3.2], [-9.0, land_z + 3.0, 4.2],
			[8.5, land_z + 6.0, 3.6], [-4.8, rock_z + 4.0, 2.4], [5.2, rock_z + 2.0, 2.0]]:
		_boulder(Vector3(float(spec[0]), FAR_Y, float(spec[1])), float(spec[2]))
	for bx in [-14.0, -8.5, -3.5, 2.0, 7.5, 12.0, 17.0]:
		_boulder(Vector3(bx, FAR_Y - 2.5 - absf(bx) * 0.25, FAR_LIP_Z - 1.2), 4.5 + absf(bx) * 0.12)
		_boulder(Vector3(bx + 2.5, FAR_Y - 10.0, FAR_LIP_Z - 1.6), 6.5)
		_boulder(Vector3(bx - 1.5, FAR_Y - 19.0, FAR_LIP_Z - 2.0), 8.0)
	# A rocky silhouette along the whole far lip (a straight box edge read as a table top).
	var lx: float = -24.0
	while lx <= 24.0:
		if absf(lx) > 2.4:
			_boulder(Vector3(lx, FAR_Y - 0.6, FAR_LIP_Z + 0.6 + fmod(absf(lx) * 1.7, 1.4)), 1.6 + fmod(absf(lx) * 0.9, 1.6))
		lx += 3.1
	# THE rock he meets head first.
	_boulder(Vector3(0.25, FAR_Y, rock_z + 0.35), 1.3)
	# The Smelting Facility's mouth in the back wall: timber frame, furnace light pouring out.
	_box(Vector3(90.0, 50.0, 6.0), Vector3(0.0, FAR_Y + 25.0, rock_z + 24.0), rock)
	var door_z: float = rock_z + 20.9
	for sx in [-4.4, 4.4]:
		_box(Vector3(0.6, 7.0, 0.6), Vector3(sx, FAR_Y + 3.5, door_z), timber)
	_box(Vector3(9.6, 0.7, 0.7), Vector3(0.0, FAR_Y + 7.0, door_z), timber)
	var furnace := StandardMaterial3D.new()
	furnace.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	furnace.albedo_color = Color(1.0, 0.55, 0.16)
	_box(Vector3(8.2, 6.6, 0.2), Vector3(0.0, FAR_Y + 3.3, door_z + 0.9), furnace)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.52, 0.2)
	fl.light_energy = 6.0
	fl.omni_range = 26.0
	fl.position = Vector3(0.0, FAR_Y + 3.0, door_z - 2.0)
	_set.add_child(fl)
	for cx in [-6.5, 6.5]:
		var cr: Node3D = _inst(CRUCIBLE_MODEL)
		if cr:
			cr.position = Vector3(cx, FAR_Y, door_z - 3.0)
			_set.add_child(cr)
	for i in 4:
		var lz: float = land_z + 2.0 + float(i) * 5.5
		var post := _box(Vector3(0.2, 2.6, 0.2), Vector3(-3.6 if i % 2 == 0 else 3.6, FAR_Y + 1.3, lz), timber)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.4)
		lamp.light_energy = 1.6
		lamp.omni_range = 7.0
		lamp.position = post.position + Vector3(0.0, 1.5, 0.0)
		_set.add_child(lamp)
		var lp: Node3D = _inst(RunnerView.LANTERN_MODEL)
		if lp:
			lp.position = post.position + Vector3(0.0, 1.2, 0.0)
			lp.scale = Vector3.ONE * 1.1
			RunnerView.self_light(lp, 1.1, Color(1.0, 0.72, 0.38))
			_set.add_child(lp)
	# INFERNO BULL, the founder's "Bull Mine Gunslinger", waiting in the furnace light.
	_bull = _inst(BULL_MODEL)
	if _bull:
		var s: float = 2.9 / 2.4
		_bull.scale = Vector3.ONE * s
		_bull.position = Vector3(1.7, FAR_Y, rock_z - 0.4)
		_bull.rotation.y = PI + 0.9      # turned toward the boy at his boots
		RunnerView.self_light(_bull, 0.12, Color(1.0, 0.8, 0.6))
		_set.add_child(_bull)
		var rim := OmniLight3D.new()
		rim.light_color = Color(1.0, 0.6, 0.28)
		rim.light_energy = 3.0
		rim.omni_range = 7.0
		rim.position = _bull.position + Vector3(-1.2, 3.65, 2.0)
		_set.add_child(rim)


func _make_env() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.016, 0.014)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.34, 0.24, 0.18)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.08
	e.fog_enabled = true
	e.fog_light_color = Color(0.36, 0.22, 0.13)
	e.fog_density = 0.007
	return e


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	_overlay.visible = false
	add_child(_overlay)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = load(POST_SHADER)
	rect.material = _post
	_overlay.add_child(rect)
	var hint := Label.new()
	hint.name = "SkipHint"
	hint.text = "hold SPACE to skip"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 0.55))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-190.0, -40.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(hint)


# --- helpers ----------------------------------------------------------------------------------------------

func _inst(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path)
	return ps.instantiate() as Node3D if ps else null


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(parent if parent else _set).add_child(mi)
	return mi


func _boulder(pos: Vector3, size: float) -> void:
	var b: Node3D = _inst(RunnerView.BOULDER_ROCK_MODEL)
	if b == null:
		return
	var bb: AABB = _measure(b)
	var s: float = size / maxf(bb.size.y, 0.01)
	b.scale = Vector3.ONE * s
	b.position = pos - Vector3(0.0, bb.position.y * s + 0.1 * size, 0.0)
	b.rotation.y = pos.x * 1.7 + pos.z
	RunnerView.self_light(b, 0.06, Color(1.0, 0.75, 0.5))
	_set.add_child(b)


func _tex_mat(path: String, tint: Color, uv_scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.9
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
	return m


func _measure(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != root and cur is Node3D:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var bb: AABB = xf * mi.mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


func _particles(amount: int, lifetime: float, color: Color, size: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


## Sparks: bright, fast, falling.
func _burst(pos: Vector3, n: int, color: Color, size: float, speed: float, life: float, action: bool) -> void:
	var p := _particles(n, life, color, size, true)
	p.position = pos
	p.direction = Vector3(0.0, 0.6, 1.0)
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.emitting = true
	_set.add_child(p)
	if action:
		_action_fx.append(p)


## Dust: big, soft, slow.
func _dust(pos: Vector3, n: int, color: Color) -> void:
	var c := color
	c.a = 0.5
	var p := _particles(n, 1.8, c, 0.9, true)
	p.position = pos
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 80.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0.0, -0.6, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	p.emitting = true
	_set.add_child(p)
	_action_fx.append(p)


## Wood / rock chunks.
func _debris(pos: Vector3, n: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.9
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.08, 0.3)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.28, 0.16)
	bm.material = m
	p.mesh = bm
	p.position = pos
	p.direction = Vector3(0.0, 0.8, 0.6)
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.emitting = true
	_set.add_child(p)
	_action_fx.append(p)


func _bus(name: String) -> String:
	return name if AudioServer.get_bus_index(name) != -1 else "Master"


## Action sounds: they slow down (pitch) in bullet time.
func _play_sfx(id: String, db: float, action: bool = false) -> void:
	var path: String = SND + id + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.bus = _bus("SFX")
	if action:
		p.set_meta("action", true)
		p.pitch_scale = 0.62 if _speed(_act) < 0.99 else 1.0
	add_child(p)
	p.play()
	_players.append(p)


func _play_vo(id: String, pitch: float) -> void:
	var path: String = SND + "voice/" + id + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = 4.0
	p.pitch_scale = pitch
	p.bus = _bus("SFX")
	add_child(p)
	p.play()
	_players.append(p)
