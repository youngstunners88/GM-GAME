class_name Ep2Viewmodel
extends Node
## Lil Blunt's first-person WINCHESTER as a drop-in component for any walk-around story room (founder 2026-10-09:
## "What dont you understand about this being a 1st player shooter game!!! Why would Lil Blunt Not have the fucking rifle
## that Inferno Bull gave him"). The mine lift and the bear woods had the rifle slung on his back in a third-person view;
## this puts it where the hideout range has it: in his hands, on screen, every moment he has control.
##
## It is the hideout's viewmodel (smelting_facility.gd: VM_* poses, _animate_fps, muzzle flash, Winchester audio) lifted
## into one reusable piece with the SAME numbers, so the rifle feels identical in every room: hip carry low and right,
## ADS with the sight line on the screen centre, low ready, sprint carry, breathing + walk bob, mouse-lag sway, recoil,
## the lever dip after each shot and the shell-by-shell reload tilt. The rifle is the forge Winchester with Lil Blunt's
## leafy hands and the founder's GM rifle model on it (Ep2ViewHands), a child of the CAMERA, so it inherits every view move.
##
## The host (an Ep2Interlude) owns the camera and the HUD; it calls `step()` once per physics step, `fire()` / `set_aim()`
## / `reload()` from the player's verbs, and reads `cam_kick` (radians to lift the view after a shot). Pure logic
## (ammo, ADS blend, lever cycle) is Ep2Winchester, so a headless test drives it without a frame clock.
## Skills: ep2-fps-shooter-feel, ep2-interlude-chain.

## A round left the barrel (the host decides what a shot means: noise in the woods, nothing in the shaft).
signal fired
signal dry_fired
signal blocked(reason: String)
signal reload_finished

## The forge rifle: its meshes are hidden and replaced by the founder's rifle (Ep2ViewHands.attach), but the forge frame
## (muzzle +Z, +Y up) is what every viewmodel pose below is measured in.
const RIFLE_BASE := "res://src/episode2/assets/winchester_1886.glb"
const VM_SCALE := 0.8
const VM_HIP_POS := Vector3(0.17, -0.16, -0.5)
const VM_HIP_ROT := Vector3(0.03, PI + 0.07, 0.0)
const VM_LOW_POS := Vector3(0.2, -0.3, -0.46)
const VM_LOW_ROT := Vector3(-0.42, PI + 0.62, -0.28)
const VM_SPRINT_POS := Vector3(0.1, -0.3, -0.42)
const VM_SPRINT_ROT := Vector3(-0.35, PI + 0.5, 0.45)
const VM_ADS_DEPTH := -0.46
const VM_ADS_SIGHT_DROP := 0.012

## The Winchester report (skill ep2-winchester-sound): three layered rifle samples round-robin on their own pool so a
## quick follow-up never cuts the previous echo, then the lever racks after each shot.
const SHOTS := ["ep2_winchester_shot_1.mp3", "ep2_winchester_shot_2.mp3", "ep2_winchester_shot_3.mp3"]
const LEVER := "ep2_winchester_lever.mp3"
const SHOT_DB := 4.0
const LEVER_DB := 0.0
const LEVER_DELAY := 0.38
const SOUND_DIR := "res://src/assets/sounds/"

## The rifle logic: ammo, tube magazine, lever cycle, ADS blend, spread. Starts loaded and unlocked (Lil Blunt was taught
## in the hideout; nobody locks his trigger in the story rooms).
var gun: Ep2Winchester = Ep2Winchester.new()
var rifle: Node3D = null
var camera: Camera3D = null
## Radians the host adds to the view pitch for the shot's kick; decays by itself.
var cam_kick: float = 0.0
## Low ready: the rifle drops down and away (the spyglass is up, a cutscene line is spoken...).
var lowered: bool = false
var shots_played: int = 0
var levers_played: int = 0

var _recoil: float = 0.0
var _flash_t: float = 0.0
var _vm_low: float = 0.0
var _vm_lag: Vector2 = Vector2.ZERO
var _look_delta: Vector2 = Vector2.ZERO
var _sight_h: float = 0.0
var _anim_t: float = 0.0
var _muzzle_flash: MeshInstance3D = null
var _flash_light: OmniLight3D = null
var _soft_tex: GradientTexture2D = null
var _players: Array[AudioStreamPlayer] = []
var _lever_player: AudioStreamPlayer = null
var _next_player: int = 0
var _lever_due: float = -1.0
var _exposure: float = 1.0
var _exp_mats: Array = []                       # [StandardMaterial3D copy, its original albedo]


## Build the rifle on `cam` (it must already be in the scene tree). Safe to call once; a second call is a no-op.
func attach(cam: Camera3D) -> void:
	if rifle != null or cam == null:
		return
	camera = cam
	gun.locked = false
	gun.reload_locked = false
	gun.rounds = Ep2Winchester.MAG
	gun.reserve = Ep2Winchester.RESERVE_START
	gun.fired.connect(_on_fired)
	gun.dry_fired.connect(_on_dry_fired)
	gun.shell_loaded.connect(_on_shell_loaded)
	gun.reload_finished.connect(func() -> void: reload_finished.emit())
	gun.blocked.connect(func(reason: String) -> void: blocked.emit(reason))
	var packed: PackedScene = load(RIFLE_BASE) as PackedScene if ResourceLoader.exists(RIFLE_BASE) else null
	if packed != null:
		rifle = packed.instantiate() as Node3D
	if rifle == null:
		rifle = Node3D.new()                       # no model in the build: an empty frame still carries the flash + hands
		var stub := MeshInstance3D.new()           # ...and a thin stand-in so the hands can measure the sight line
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.1, 1.2)
		stub.mesh = bm
		stub.visible = false
		rifle.add_child(stub)
	rifle.name = "Viewmodel"
	cam.add_child(rifle)
	rifle.position = VM_HIP_POS
	rifle.rotation = VM_HIP_ROT
	rifle.scale = Vector3.ONE * VM_SCALE
	_build_muzzle_flash()
	_rifle_sight_height()                           # measure the sights BEFORE the hands are added (they must not count)
	Ep2ViewHands.attach(rifle)                      # Lil Blunt's hands + bracers + the founder's rifle on the forge frame
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.5)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 7.0
	cam.add_child(_flash_light)
	_flash_light.position = Vector3(0.2, -0.15, -1.0)
	_build_audio()
	_apply_exposure()


## Scale the rifle's albedo (and with it its metal reflections) for a very bright scene. In the hideout's lamplight the receiver
## plate is gunmetal; under the woods' low sun and bright sky the same metal read cream, so a daylight chamber sets ~0.7.
## Emission (the glowing GM badge) is untouched.
func set_exposure(k: float) -> void:
	_exposure = clampf(k, 0.2, 1.0)
	_apply_exposure()


func _apply_exposure() -> void:
	var model: Node = rifle.get_node_or_null("Hands/HandsModel") if rifle != null else null
	if model == null:
		return
	if _exp_mats.is_empty():
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			for i in m.mesh.get_surface_count():
				var src: Material = m.get_surface_override_material(i)
				if src == null:
					src = m.mesh.surface_get_material(i)
				if src is StandardMaterial3D:
					var d: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
					m.set_surface_override_material(i, d)
					_exp_mats.append([d, d.albedo_color])
	for pair in _exp_mats:
		var mat: StandardMaterial3D = pair[0]
		var base: Color = pair[1]
		mat.albedo_color = Color(base.r * _exposure, base.g * _exposure, base.b * _exposure, base.a)


## Show or hide the rifle (the host hides it while a director camera is on, when the body is seen instead).
func set_shown(on: bool) -> void:
	if rifle != null and is_instance_valid(rifle):
		rifle.visible = on


## The mouse delta in pixels: the rifle LAGS the mouse a little (sway).
func add_look(relative: Vector2) -> void:
	_look_delta += relative


func set_aim(on: bool) -> void:
	gun.set_aim(on)


## Pull the trigger. True when a round went out.
func fire() -> bool:
	return gun.trigger() == Ep2Winchester.Shot.OK


## R: load shells one at a time. True when a reload started.
func reload() -> bool:
	return gun.start_reload()


func is_ads() -> bool:
	return gun.ads > 0.5


## Advance everything one physics step. `moving` / `sprinting` / `walk_phase` come from the host's movement.
func step(delta: float, moving: bool, sprinting: bool, walk_phase: float) -> void:
	_anim_t += delta
	gun.sprinting = sprinting
	gun.step(delta)
	_tick_lever(delta)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	cam_kick = lerpf(cam_kick, 0.0, 1.0 - exp(-delta / 0.14))
	_flash_t = maxf(0.0, _flash_t - delta)
	if _muzzle_flash != null and is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = _flash_t > 0.0
		_muzzle_flash.scale = Vector3.ONE * (0.7 + 0.8 * (_flash_t / 0.06))
	if _flash_light != null:
		_flash_light.light_energy = maxf(0.0, _flash_light.light_energy - delta * 30.0)
	if rifle == null or not is_instance_valid(rifle) or rifle.get_parent() != camera:
		return
	var ads: float = gun.ads
	var ads_k: float = ads * ads * (3.0 - 2.0 * ads)
	_vm_low = move_toward(_vm_low, 1.0 if lowered else 0.0, delta * 2.6)
	var sprint: float = 1.0 if (sprinting and moving and ads < 0.1) else 0.0
	var pos: Vector3 = VM_HIP_POS.lerp(VM_LOW_POS, _vm_low).lerp(VM_SPRINT_POS, sprint * (1.0 - _vm_low))
	var rot: Vector3 = VM_HIP_ROT.lerp(VM_LOW_ROT, _vm_low).lerp(VM_SPRINT_ROT, sprint * (1.0 - _vm_low))
	# aimed: centred with the sight line on the screen centre
	var ads_pos := Vector3(0.0, -(VM_ADS_SIGHT_DROP + _rifle_sight_height() * VM_SCALE), float(rifle.get_meta("ads_depth", VM_ADS_DEPTH)))
	if rifle.has_meta("ads_cam"):
		# the eye in the rifle's own frame (founder rifle): the node sits so that point lands on the camera; the rifle is yawed
		# PI toward the player, so its +Z points forward and its +Y up: node = (-cam.y * s, +cam.z * s) in camera space.
		var ec: Vector3 = rifle.get_meta("ads_cam")
		ads_pos = Vector3(0.0, -ec.y * VM_SCALE - VM_ADS_SIGHT_DROP, ec.z * VM_SCALE)
	pos = pos.lerp(ads_pos, ads_k)
	rot = rot.lerp(Vector3(0.0, PI, 0.0), ads_k)
	# breathing + walk bob (both nearly vanish aimed)
	var calm: float = lerpf(1.0, 0.18, ads_k)
	pos += Vector3(sin(_anim_t * 1.3) * 0.0035, sin(_anim_t * 1.9) * 0.004, 0.0) * calm
	if moving:
		pos += Vector3(sin(walk_phase) * 0.011, -absf(sin(walk_phase)) * 0.013, 0.0) * calm
	var lag_target := Vector2(clampf(-_look_delta.x * 0.00045, -0.05, 0.05), clampf(_look_delta.y * 0.00045, -0.05, 0.05))
	_look_delta = Vector2.ZERO
	_vm_lag = _vm_lag.lerp(lag_target, 1.0 - exp(-delta * 12.0))
	pos += Vector3(_vm_lag.x, _vm_lag.y, 0.0) * calm
	rot.y += _vm_lag.x * 1.6
	# recoil: the rifle jumps back and its muzzle lifts, then settles
	pos += Vector3(0.0, 0.016, 0.085) * _recoil * lerpf(1.0, 0.55, ads_k)
	rot.x += 0.12 * _recoil * lerpf(1.0, 0.6, ads_k)
	# the lever cycle: after each shot the rifle dips and rolls as the lever is racked
	var cp: float = gun.cycle_progress()
	if cp < 1.0:
		var k: float = sin(cp * PI)
		rot.z += 0.34 * k
		rot.x -= 0.2 * k
		pos.y -= 0.025 * k
	# the shell-by-shell reload: the rifle tilts to show the loading gate and taps once per shell
	if gun.reloading:
		var tap: float = absf(sin(_anim_t * PI / Ep2Winchester.RELOAD_PER_SHELL))
		rot.z += -0.55
		rot.x += 0.28
		pos += Vector3(-0.05, -0.05 - 0.02 * tap, 0.04)
	rifle.position = pos
	rifle.rotation = rot


# --- shot reactions ---------------------------------------------------------------------------------------------------

func _on_fired() -> void:
	_recoil = 1.0
	_flash_t = 0.06
	cam_kick += gun.kick_rad()
	if _flash_light != null:
		_flash_light.light_energy = 4.0
	_play_shot()
	fired.emit()


func _on_dry_fired() -> void:
	_sfx("ep2_winchester_dry")
	dry_fired.emit()


func _on_shell_loaded(_n: int) -> void:
	_sfx("ep2_winchester_shell_load")


func _sfx(sound_name: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound_name)


func _build_audio() -> void:
	if not _players.is_empty():
		return
	var bus: String = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in SHOTS.size():
		var p := AudioStreamPlayer.new()
		p.name = "ShotPlayer%d" % i
		p.bus = bus
		p.volume_db = SHOT_DB
		var path: String = SOUND_DIR + str(SHOTS[i])
		if ResourceLoader.exists(path):
			p.stream = load(path) as AudioStream
		add_child(p)
		_players.append(p)
	_lever_player = AudioStreamPlayer.new()
	_lever_player.name = "LeverPlayer"
	_lever_player.bus = bus
	_lever_player.volume_db = LEVER_DB
	if ResourceLoader.exists(SOUND_DIR + LEVER):
		_lever_player.stream = load(SOUND_DIR + LEVER) as AudioStream
	add_child(_lever_player)


func _play_shot() -> void:
	_build_audio()
	var p: AudioStreamPlayer = _players[_next_player % _players.size()]
	_next_player += 1
	if p.stream != null:
		p.pitch_scale = randf_range(0.96, 1.03)
		p.play()
		shots_played += 1
	_lever_due = LEVER_DELAY


## Racks the lever LEVER_DELAY after the shot (driven by step(), so a headless test sees it too).
func _tick_lever(delta: float) -> void:
	if _lever_due < 0.0:
		return
	_lever_due -= delta
	if _lever_due <= 0.0:
		_lever_due = -1.0
		if _lever_player != null and _lever_player.stream != null:
			_lever_player.play()
			levers_played += 1


# --- the muzzle flash + the sight height ------------------------------------------------------------------------------------

func _blob() -> GradientTexture2D:
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


func _build_muzzle_flash() -> void:
	if _muzzle_flash != null and is_instance_valid(_muzzle_flash):
		return
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.75, 0.35, 1.0)
	m.albedo_texture = _blob()
	m.no_depth_test = true
	q.material = m
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"             # Ep2ViewHands.attach keeps meshes named Muzzle* visible-capable
	_muzzle_flash.mesh = q
	_muzzle_flash.position = Vector3(0.0, 0.03, 0.66)
	_muzzle_flash.visible = false
	rifle.add_child(_muzzle_flash)


## Height of the rifle's highest point (the sights) in its own frame, measured from its meshes once.
func _rifle_sight_height() -> float:
	if _sight_h > 0.0:
		return _sight_h
	var top: float = 0.0
	if rifle != null and is_instance_valid(rifle) and rifle.is_inside_tree():
		var inv: Transform3D = rifle.global_transform.affine_inverse()
		var hands: Node = rifle.get_node_or_null("Hands")
		for mi in rifle.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m == _muzzle_flash or m.mesh == null or (hands != null and hands.is_ancestor_of(m)):
				continue
			var bb: AABB = (inv * m.global_transform) * m.get_aabb()
			top = maxf(top, bb.end.y)
	_sight_h = clampf(top, 0.03, 0.2) if top > 0.0 else 0.06
	return _sight_h
