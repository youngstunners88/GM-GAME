class_name Ep2Interlude
extends Node3D
## Shared base of the Episode 2 INTERLUDE chambers (founder 2026-10-09): the story that follows the hideout is no longer the
## cart runner. Lil Blunt and Inferno Bull ride a mine lift up to the surface (MineLiftChamber), sneak through the woods to
## Inferno's camouflaged flame quad, and ride it to a ridge where they spy on the bears (WoodsQuadChamber).
##
## This base owns what every walk-around story room needs, so each chamber is only its set, its beats and its script:
##   * the session-root contract (setup / step / chamber_cleared / chamber_failed + the free-roam verbs set_move_input,
##     look, jump, shoot ... that Ep2SessionRoot routes), so a chamber drops into the same loop as the facility;
##   * Lil Blunt (the rigged hero with walk / run clips) and Inferno Bull (Ep2Actor with walk / run / idle), a
##     third-person follow camera with a director override, jump + double jump, a ground height that a lift can move;
##   * the SHOW: the same data-driven step sequencer the hideout uses (FacilityShow) - say / walk / face / reach / hop /
##     until / call - driven by step(delta) so a headless test plays a whole chamber without a frame clock.
## Skill: ep2-interlude-chain.

## Emitted once, when the chamber resolves. Carries the story result the session root commits (gold 0 here) plus the
## chain keys `next_chamber` (load this chamber next) or `end_session` (the playable slice ends here).
signal chamber_cleared(result: Dictionary)
signal chamber_failed
signal line_spoken(line_id: String)
signal beat_changed(beat: int)

# --- free roam (the same feel as the hideout; skill ep2-free-roam-controls) ----------------------------------------
const RUN_SPEED := 5.6
const JUMP_VELOCITY := 5.4
const GRAVITY := 15.0
const MAX_AIR_JUMPS := 1
const LOOK_SENSITIVITY := 0.0032
const LOOK_PITCH_MIN := -0.85
const LOOK_PITCH_MAX := 0.45
const PLAYER_SCALE := 0.95
const BULL_HEIGHT := 2.9
const BULL_RIG_H := 2.4
const BULL_IDLE := "Idle_02"
const NO_FOCUS := Vector3(INF, INF, INF)

const ROCK_TEX := "res://src/episode2/assets/textures/tex_rock_wall.jpg"
const GRAVEL_TEX := "res://src/episode2/assets/textures/tex_gravel.jpg"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const LANTERN_MODEL := "res://src/episode2/assets/lantern.glb"

## Tunables a chamber sets before the room is built.
var walk_speed: float = 3.4
var cam_distance: float = 3.9              # follow-camera boom length (the quad ride pulls it back)
var cam_height: float = 1.45               # how far above his feet the camera looks
var title_card: String = ""
var music_path: String = ""
var camera_min: Vector3 = Vector3(-60.0, 0.4, -60.0)
var camera_max: Vector3 = Vector3(60.0, 40.0, 60.0)

# --- live state -----------------------------------------------------------------------------------------------------
var _beat: int = 0
var _elapsed: float = 0.0
var _running: bool = false
var _resolved: bool = false
var _room_built: bool = false
var _hold: float = 0.0                       # seconds the current spoken line still has to run (FacilityShow reads it)
var _hop_v: float = 0.0
var _hop_y: float = 0.0
var _vo_lens: Dictionary = {}
var _show: FacilityShow = null
var _show_active: bool = false
var _show_blocks_control: bool = false

var _visuals: Node3D = null
var _camera: Camera3D = null
var _env_node: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _player_node: Node3D = null
var _player_skel: Skeleton3D = null
var _player_pose: RunnerArmRest = null
var _hero_anim: AnimationPlayer = null
var _hero_clip: String = ""
var _bull: Ep2Actor = null

var _player_pos: Vector3 = Vector3.ZERO      # feet, absolute world height
var _ground_y: float = 0.0                   # what he stands on right now (a rising lift moves this)
var _player_yaw: float = 0.0
var _look_yaw: float = 0.0
var _look_pitch: float = -0.22
var _vel_y: float = 0.0
var _air_jumps: int = 0
var _move_input: Vector2 = Vector2.ZERO
var _run_input: bool = false
var _moving: bool = false
var _anim_t: float = 0.0
var _walk_phase: float = 0.0

## Director override: when `_cam_goal_active` the camera goes to this exact pose instead of following Lil Blunt.
var _cam_goal_active: bool = false
var _cam_goal_pos: Vector3 = Vector3.ZERO
var _cam_goal_look: Vector3 = Vector3.ZERO
var _cam_goal_fov: float = 62.0
var _cam_fov_follow: float = 68.0
var _cam_snap: bool = false
var _soft_tex: GradientTexture2D = null


# --- lifecycle ------------------------------------------------------------------------------------------------------

func _ready() -> void:
	_ready_fallback.call_deferred()


## Instantiated without setup() (a capture rig, a scene preview): still show the room.
func _ready_fallback() -> void:
	if not _running and not _room_built:
		_ensure_room()


func _ensure_room() -> void:
	if _room_built:
		return
	_room_built = true
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		_camera.fov = 68.0
		add_child(_camera)
	_camera.current = true
	_env_node = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _env_node == null:
		_env_node = WorldEnvironment.new()
		_env_node.name = "WorldEnvironment"
		add_child(_env_node)
	_sun = get_node_or_null("Sun") as DirectionalLight3D
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		add_child(_sun)
	_build_room()
	_player_node = _build_player()
	_sync_visuals()


## The session root calls this right after add_child (the same signature every chamber has). Never overridden:
## a chamber hooks `_on_setup()` instead.
func setup(_gold_principal: int = 0, _bears: Array = [], _diamonds_paid: int = 0) -> void:
	_running = true
	_resolved = false
	_elapsed = 0.0
	_hold = 0.0
	_show_active = false
	_show_blocks_control = false
	_move_input = Vector2.ZERO
	_run_input = false
	_vel_y = 0.0
	_air_jumps = 0
	_ensure_room()
	_on_setup()
	_apply_music()
	_sync_visuals()
	beat_changed.emit(_beat)


func _physics_process(delta: float) -> void:
	if _running:
		step(delta)


## Deterministic advance - the headless-test entry point (mirrors the facility).
func step(delta: float) -> void:
	if not _running or _resolved:
		return
	_elapsed += delta
	_anim_t += delta
	if _hold > 0.0:
		_hold = maxf(0.0, _hold - delta)
	if has_player_control():
		_move_player(delta)
	else:
		_moving = false
	_update_vertical(delta)
	if _show_active and _show != null:
		_show.step(delta)
	_tick(delta)
	if _bull != null and is_instance_valid(_bull):
		_bull.step(delta)
	_update_camera(delta)
	_animate(delta)
	_sync_visuals()


# --- hooks a chamber overrides ----------------------------------------------------------------------------------------

func _build_room() -> void:
	pass


func _on_setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


## A scripted show finished (the dialogue / choreography of the current beat).
func _show_finished() -> void:
	pass


## Keep the player inside the set. `p` is the wished-for position; return where he may stand.
func _collide(p: Vector3) -> Vector3:
	return p


func _beat_label(b: int) -> String:
	return str(b)


# --- the show -------------------------------------------------------------------------------------------------------

func _start_show(steps: Array, blocks_control: bool = false) -> void:
	if steps.is_empty():
		_show_finished()
		return
	if _show == null:
		_show = FacilityShow.new()
		_show.f = self
	_show_blocks_control = blocks_control
	_show_active = true
	_show.start(steps)


## FacilityShow calls this when its last step ends.
func _on_show_done() -> void:
	_show_active = false
	_show_blocks_control = false
	_show_finished()


func _advance_to(beat: int) -> void:
	_beat = beat
	_on_beat_entered(beat)
	beat_changed.emit(_beat)


func _on_beat_entered(_beat_id: int) -> void:
	pass


## Length in seconds of a committed voice clip (a hold always matches the real audio).
func _vo_len(id: String) -> float:
	if _vo_lens.has(id):
		return float(_vo_lens[id])
	var path: String = "res://src/assets/sounds/voice/%s.mp3" % id
	var l: float = 3.0
	if ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		if st:
			l = st.get_length()
	_vo_lens[id] = l
	return l


func _speak(line_id: String) -> void:
	line_spoken.emit(line_id)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_voice"):
		am.play_voice(line_id)


## He talks while he walks / stands (FacilityShow's `until` nudge uses this).
func _begin_carry_line(id: String) -> void:
	_hold = _vo_len(id)
	_speak(id)


func _bull_play(clip: String, speed: float = 1.0) -> void:
	if _bull:
		_bull.play(clip, speed)


func _sfx(name: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)


## A looping effect owned by this chamber (an engine, a rising cage). `bus` is the SFX bus.
func _loop_player(path: String, volume_db: float = -6.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.volume_db = volume_db
	if ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		p.stream = st
	add_child(p)
	return p


func _apply_music() -> void:
	if music_path == "":
		return
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_room_music"):
		am.play_room_music(music_path, 2.5)


# --- the session-root contract ------------------------------------------------------------------------------------

func has_player_control() -> bool:
	return _running and not _resolved and not _show_blocks_control


func wants_mouse_capture() -> bool:
	return has_player_control()


func set_move_input(v: Vector2, run: bool = false) -> void:
	_move_input = v.limit_length(1.0)
	_run_input = run


func walk(direction: float) -> void:
	set_move_input(Vector2(0.0, clampf(direction, -1.0, 1.0)))


func walk_stop() -> void:
	set_move_input(Vector2.ZERO)


func look(relative: Vector2) -> void:
	if not has_player_control():
		return
	_look_yaw -= relative.x * LOOK_SENSITIVITY
	_look_pitch = clampf(_look_pitch - relative.y * LOOK_SENSITIVITY, LOOK_PITCH_MIN, LOOK_PITCH_MAX)


func jump() -> bool:
	if not has_player_control() or not _can_jump():
		return false
	if _player_pos.y <= _ground_y + 0.001:
		_vel_y = JUMP_VELOCITY
		_air_jumps = 0
		return true
	if _air_jumps < MAX_AIR_JUMPS:
		_air_jumps += 1
		_vel_y = JUMP_VELOCITY * 0.85
		return true
	return false


func _can_jump() -> bool:
	return true


## The interlude has no weapon verbs (the rifle is slung): the root's click / E / cover verbs are accepted and ignored.
func shoot() -> bool: return false
func start_rig(_payment: String = "") -> bool: return false
func early_claim() -> bool: return false
func take_cover() -> void: pass
func leave_cover() -> void: pass
func set_aim(_on: bool) -> void: pass
func reload() -> bool: return false

# State the entry host / HUD read (the facility's vocabulary, so the host treats an interlude like any story room).
func get_beat() -> int: return _beat
func get_beat_name() -> String: return _beat_label(_beat)
func get_title_card() -> String: return title_card
func has_winchester() -> bool: return true
func get_molds_left() -> int: return 0
func get_btc_paid() -> int: return 1
func get_health() -> int: return 3
func get_ammo() -> int: return 0
func get_live_bear_count() -> int: return 0
func get_vest() -> float: return 0.0
func is_rig_started() -> bool: return false
func is_in_cover() -> bool: return false
func is_fps() -> bool: return false
func get_episode_mode() -> int: return Episode2Mode.Mode.HIDEOUT
func get_player_position() -> Vector3: return _player_pos
func get_look_yaw() -> float: return _look_yaw
func get_bull() -> Ep2Actor: return _bull
func is_resolved() -> bool: return _resolved
func is_running() -> bool: return _running
func is_show_active() -> bool: return _show_active
func get_line_hold() -> float: return _hold
func get_elapsed() -> float: return _elapsed
func get_camera() -> Camera3D: return _camera
func is_moving() -> bool: return _moving


## Resolve the chamber: a story result (gold 0, nothing to commit) with the chain keys the session root reads.
func _resolve(extra: Dictionary = {}) -> void:
	if _resolved:
		return
	_resolved = true
	_running = false
	var res: Dictionary = {
		"story": true,
		"chamber": _chamber_id(),
		"gold_awarded": 0,
		"gold_forfeited": 0,
		"btc_paid": 0,
		"companion": "inferno_bull",
		"seconds": _elapsed,
	}
	res.merge(extra, true)
	chamber_cleared.emit(res)


func _chamber_id() -> String:
	return "interlude"


# --- movement ---------------------------------------------------------------------------------------------------------

func _move_player(delta: float) -> void:
	var fwd := Vector3(sin(_look_yaw), 0.0, cos(_look_yaw))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var wish: Vector3 = fwd * _move_input.y + right * _move_input.x
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	_moving = wish.length_squared() > 0.0025
	if not _moving:
		return
	var speed: float = _current_speed()
	var next: Vector3 = _collide(_player_pos + wish * speed * delta)
	_player_pos.x = next.x
	_player_pos.z = next.z
	_player_yaw = lerp_angle(_player_yaw, atan2(wish.x, wish.z), clampf(12.0 * delta, 0.0, 1.0))
	_walk_phase += delta * (13.0 if _run_input else 9.5)


func _current_speed() -> float:
	return RUN_SPEED if _run_input else walk_speed


func _update_vertical(delta: float) -> void:
	if _player_pos.y <= _ground_y and _vel_y <= 0.0:
		_player_pos.y = _ground_y
		_vel_y = 0.0
		return
	_vel_y -= GRAVITY * delta
	_player_pos.y += _vel_y * delta
	if _player_pos.y <= _ground_y:
		_player_pos.y = _ground_y
		_vel_y = 0.0
		_air_jumps = 0


## Move the ground the player stands on (a lift): he rides it unless he is airborne.
func _set_ground(y: float) -> void:
	var grounded: bool = _player_pos.y <= _ground_y + 0.02 and _vel_y <= 0.0
	_ground_y = y
	if grounded or _player_pos.y < y:
		_player_pos.y = y
		_vel_y = 0.0


# --- camera -----------------------------------------------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if _cam_goal_active:
		var t: float = 1.0 if _cam_snap else clampf(2.4 * delta, 0.0, 1.0)
		_camera.position = _camera.position.lerp(_cam_goal_pos, t)
		_camera.fov = lerpf(_camera.fov, _cam_goal_fov, clampf(4.0 * delta, 0.0, 1.0) if not _cam_snap else 1.0)
		if _camera.position.distance_squared_to(_cam_goal_look) > 1e-4:
			_camera.look_at(_cam_goal_look, Vector3.UP)
		_cam_snap = false
		return
	_follow_camera(delta)


func _follow_camera(delta: float) -> void:
	var target: Vector3 = Vector3(_player_pos.x, _player_pos.y + cam_height, _player_pos.z)
	var cp: float = cos(_look_pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)
	var want: Vector3 = target - dir * cam_distance + Vector3(0.0, 0.25, 0.0)
	want = want.clamp(camera_min, camera_max)
	want.y = maxf(want.y, _ground_y + 0.5)
	_camera.position = _camera.position.lerp(want, clampf(10.0 * delta, 0.0, 1.0))
	_camera.fov = lerpf(_camera.fov, _cam_fov_follow, clampf(6.0 * delta, 0.0, 1.0))
	var look_at_p: Vector3 = target + dir * 2.0
	if _camera.position.distance_squared_to(look_at_p) > 1e-4:
		_camera.look_at(look_at_p, Vector3.UP)


## Cut the camera to a director shot (smoothly unless `snap`). Pass `release_camera()` to return to following Lil Blunt.
func set_camera_shot(pos: Vector3, look_at_point: Vector3, fov: float = 62.0, snap: bool = false) -> void:
	_cam_goal_active = true
	_cam_goal_pos = pos
	_cam_goal_look = look_at_point
	_cam_goal_fov = fov
	_cam_snap = snap


func release_camera() -> void:
	_cam_goal_active = false


# --- actors -----------------------------------------------------------------------------------------------------------

func _animate(delta: float) -> void:
	if _player_node == null or not is_instance_valid(_player_node):
		return
	if _show_active and not _moving and _bull != null:
		var to_bull: float = atan2(_bull.position.x - _player_pos.x, _bull.position.z - _player_pos.z)
		_player_yaw = lerp_angle(_player_yaw, to_bull, clampf(5.0 * delta, 0.0, 1.0))
	if _hop_v != 0.0 or _hop_y > 0.0:
		_hop_v -= 15.0 * delta
		_hop_y = maxf(0.0, _hop_y + _hop_v * delta)
		if _hop_y <= 0.0:
			_hop_v = 0.0
	var breath: float = 0.010 * sin(_anim_t * 2.1)
	var sway: float = 0.0 if _hero_anim else (sin(_walk_phase) * 0.07 if _moving else 0.02 * sin(_anim_t * 0.9))
	_player_node.basis = Basis.from_euler(Vector3(0.0, _player_yaw, sway)).scaled(Vector3(1.0, 1.0 + breath, 1.0))
	_player_node.position = Vector3(_player_pos.x, _player_pos.y + _hop_y, _player_pos.z)
	if _hero_anim:
		var clip: String = ""
		if _moving and _player_pos.y <= _ground_y + 0.001:
			clip = "run" if _run_input else "walk"
		if clip != _hero_clip:
			_hero_clip = clip
			if clip == "":
				_hero_anim.pause()
			else:
				_hero_anim.play(clip, 0.15)
				_hero_anim.speed_scale = 1.25 if clip == "run" else 1.7
		if _player_pose:
			_player_pose.legs_free = clip != ""


func _sync_visuals() -> void:
	if _player_node and is_instance_valid(_player_node):
		_player_node.position = Vector3(_player_pos.x, _player_pos.y, _player_pos.z)


## Lil Blunt: the rigged hero with the walk / run clips, a key light, and the Winchester slung on his back.
func _build_player() -> Node3D:
	var root := Node3D.new()
	root.name = "Player"
	root.position = _player_pos
	_visuals.add_child(root)
	var hero: Node3D = null
	if ResourceLoader.exists(RunnerView.HERO_MODEL):
		hero = (load(RunnerView.HERO_MODEL) as PackedScene).instantiate() as Node3D
	if hero == null:
		var pm := BoxMesh.new()
		pm.size = Vector3(0.7, 1.7, 0.7)
		var box := MeshInstance3D.new()
		box.mesh = pm
		box.material_override = Ep2Palette.make("leaf_green")
		box.position = Vector3(0.0, 0.85, 0.0)
		root.add_child(box)
		return root
	hero.scale = Vector3(-PLAYER_SCALE, PLAYER_SCALE, PLAYER_SCALE)
	root.add_child(hero)
	for ap in hero.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
		if _hero_anim == null:
			_hero_anim = ap
	if _hero_anim:
		_add_hero_clip("walk", SmeltingFacilityChamber.HERO_WALK_CLIP)
		_add_hero_clip("run", SmeltingFacilityChamber.HERO_RUN_CLIP)
		if not _hero_anim.has_animation("walk"):
			_hero_anim = null
	var sks: Array = hero.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_player_skel = sks[0]
		_player_pose = RunnerArmRest.new()
		_player_pose.body_frame = true
		_player_pose.standing = true
		_player_pose.head_back = 0.25
		_player_pose.spine_back = 0.04
		_player_pose.gun_upper = Vector3(0.25, -0.95, 0.25)
		_player_pose.gun_fore = Vector3(0.75, -0.35, 0.2)
		_player_pose.gun_barrel = Vector3(0.85, -0.45, 0.1)
		_player_pose.pick_upper = Vector3(0.3, -0.9, 0.3)
		_player_pose.pick_fore = Vector3(0.55, 0.8, 0.1)
		_player_pose.pick_handle = Vector3(-0.45, 0.85, 0.3)
		_player_skel.add_child(_player_pose)
	RunnerView.self_light(hero, 0.08, Color(1.0, 0.86, 0.66))
	RunnerView.brighten_hero(hero)
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.84, 0.62)
	key.light_energy = 1.0
	key.omni_range = 4.5
	key.position = Vector3(0.8, 2.2, -1.2)
	root.add_child(key)
	_sling_rifle(root)
	return root


## The founder's Winchester across his back (Lil Blunt keeps it slung: this part of the story is sneaking, not shooting).
func _sling_rifle(root: Node3D) -> void:
	var path: String = "res://src/episode2/assets/weapons/winchester_1886_founder.glb"
	if not ResourceLoader.exists(path):
		return
	var rifle: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	if rifle == null:
		return
	rifle.name = "SlungRifle"
	rifle.scale = Vector3.ONE * 0.8
	rifle.position = Vector3(-0.2, 1.05, -0.28)
	rifle.rotation = Vector3(0.0, 0.0, deg_to_rad(-62.0))      # muzzle up over the shoulder, stock low on the hip
	root.add_child(rifle)


func _add_hero_clip(clip_name: String, path: String) -> void:
	if _hero_anim == null or not ResourceLoader.exists(path):
		return
	var src: Node = (load(path) as PackedScene).instantiate()
	var aps: Array = src.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var sp: AnimationPlayer = aps[0]
		var list: PackedStringArray = sp.get_animation_list()
		if not list.is_empty():
			var anim: Animation = sp.get_animation(list[0]).duplicate(true)
			anim.loop_mode = Animation.LOOP_LINEAR
			var lib: AnimationLibrary = _hero_anim.get_animation_library("")
			if lib and not lib.has_animation(clip_name):
				lib.add_animation(clip_name, anim)
	src.free()


## Inferno Bull: rigged, with the walk / run clips, matte PBR and a visible, solid body (skills ep2-solid-models, ep2-bull-rest-pose).
func _build_bull(pos: Vector3, facing: float = 0.0) -> Ep2Actor:
	var b := Ep2Actor.new()
	b.name = "InfernoBull"
	b.position = pos
	_visuals.add_child(b)
	var ok: bool = b.setup(SmeltingFacilityChamber.BULL_RIG_MODEL, BULL_RIG_H, BULL_HEIGHT,
		{"walk": SmeltingFacilityChamber.BULL_WALK_CLIP, "run": SmeltingFacilityChamber.BULL_RUN_CLIP}, [BULL_IDLE])
	if not ok:
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 2.4, 1.0)
		var fb := MeshInstance3D.new()
		fb.mesh = bm
		fb.material_override = Ep2Palette.make("bandit")
		fb.position = Vector3(0, 1.2, 0)
		b.add_child(fb)
		return b
	b.idle_clip = BULL_IDLE
	b.facing = facing
	b.rotation.y = facing
	b.play(BULL_IDLE, 1.0, 0.0)
	_fix_bull_materials(b.model)
	return b


static func _fix_bull_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var d: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				d.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				d.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
				d.resource_name = "InfernoBullRestoredPBR"
				d.albedo_texture = preload("res://src/episode2/assets/textures/bull_albedo.jpg")
				d.metallic_texture = preload("res://src/episode2/assets/textures/bull_metal_rough.png")
				d.roughness_texture = d.metallic_texture
				d.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
				d.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				d.metallic = 0.65
				d.metallic_specular = 0.25
				d.roughness = 1.0
				d.normal_enabled = true
				d.normal_texture = preload("res://src/episode2/assets/textures/bull_normal.png")
				d.normal_scale = 0.65
				d.rim_enabled = true
				d.rim = 0.12
				d.rim_tint = 0.5
				d.emission_enabled = true
				d.emission = Color(1.0, 0.78, 0.55)
				d.emission_texture = d.albedo_texture
				d.emission_energy_multiplier = 0.1
				d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				m.set_surface_override_material(i, d)


# --- set-building helpers -----------------------------------------------------------------------------------------------

func _tex(path: String, tint: Color, uv_scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.9
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
	return m


func _plain(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else _visuals).add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, parent: Node3D = null, sides: int = 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else _visuals).add_child(mi)
	return mi


func _sphere(r: float, pos: Vector3, mat: Material, parent: Node3D = null, squash: float = 1.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 10
	sm.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else _visuals).add_child(mi)
	return mi


func _lantern(pos: Vector3, energy: float = 3.2, rng: float = 12.0, parent: Node3D = null) -> void:
	var holder := Node3D.new()
	holder.position = pos
	(parent if parent != null else _visuals).add_child(holder)
	if ResourceLoader.exists(LANTERN_MODEL):
		var l: Node3D = (load(LANTERN_MODEL) as PackedScene).instantiate() as Node3D
		if l:
			l.scale = Vector3.ONE * 0.55
			holder.add_child(l)
	var o := Ep2Palette.make_lantern_light()
	o.light_energy = energy
	o.omni_range = rng
	holder.add_child(o)


func _soft_blob() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


func _particles(amount: int, lifetime: float, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_blob()
	q.material = m
	p.mesh = q
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.emitting = true
	return p
