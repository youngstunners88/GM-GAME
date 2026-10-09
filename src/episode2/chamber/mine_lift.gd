class_name MineLiftChamber
extends Ep2Interlude
## Interlude 1 - the MINE LIFT (founder 2026-10-09): after the hideout the scene changes dramatically. Inferno Bull and Lil
## Blunt step onto an old timber cage in a mine shaft that climbs TWO FLOORS to the surface. The lever that starts it is
## hidden: it is a stub of rock in the shaft wall, the same stone as the wall around it (Inferno is a master of disguise).
## While the cage rises, Inferno lays out the plan: sneak through the wood, ride his flame quad to a ridge, spy on the bears.
## The "Inferno Bull 2" song starts the moment they enter the shaft.
##
## Beats: ARRIVE (Inferno walks to the cage while he talks) -> BOARD (Lil Blunt steps on) -> LEVER (Inferno pulls the hidden
## lever; scripted) -> RISE (the plan, 20 s up two floors, free to look around) -> SURFACE (gate opens, daylight, walk out) -> DONE.
## Resolves with `next_chamber: woods_quad`. Skill: ep2-interlude-chain.

enum Beat { ARRIVE, BOARD, LEVER, RISE, SURFACE, DONE }

const MUSIC := "res://src/assets/music/ep2_inferno_bull2_lift.ogg"
const LOOP_SFX := "res://src/assets/sounds/ep2_lift_loop.mp3"
const NEXT_CHAMBER := "woods_quad"

# --- layout (metres) ---
const SHAFT_HALF := 4.5            # the shaft is 9 m square
const CAGE_HALF := 1.9             # the cage is 3.8 m square
const MID_Y := 7.5                 # first floor up
const TOP_Y := 15.0                # the surface (second floor up)
const ROOF_Y := 22.0
const RISE_SECONDS := 22.0
const START_POS := Vector3(0.0, 0.0, -11.0)
const CAGE_STAND_BULL := Vector3(-0.9, 0.0, 0.5)
const EXIT_Z := 8.0
## THE HIDDEN LEVER: a stub of rock in the west wall, beside the cage, at knee height and in the shadow of a boulder.
const LEVER_POS := Vector3(-4.28, 1.0, -1.35)
const LEVER_STAND := Vector3(-3.1, 0.0, -1.35)

var _rock: StandardMaterial3D = null
var _cage: Node3D = null
var _gate: Node3D = null
var _counter: Node3D = null
var _lever: Node3D = null
var _lever_t: float = -1.0
var _cage_y: float = 0.0
var _rise_t: float = -1.0
var _on_cage: bool = false
var _bull_on_cage: bool = false
var _gate_open: float = 0.0
var _loop: AudioStreamPlayer = null
var _plan_started: bool = false
var _arrived: bool = false


func _init() -> void:
	title_card = "THE MINE LIFT"
	music_path = MUSIC
	camera_min = Vector3(-4.1, 0.4, -4.1)
	camera_max = Vector3(4.1, 21.0, 4.1)


func _chamber_id() -> String:
	return "mine_lift"


func _beat_label(b: int) -> String:
	return Beat.keys()[clampi(b, 0, Beat.size() - 1)]


# --- the set ----------------------------------------------------------------------------------------------------------

func _build_room() -> void:
	_rock = _tex(ROCK_TEX, Color(0.50, 0.42, 0.35), 0.22)
	var rock_dark: StandardMaterial3D = _tex(ROCK_TEX, Color(0.28, 0.23, 0.19), 0.16)
	var gravel: StandardMaterial3D = _tex(GRAVEL_TEX, Color(0.50, 0.43, 0.36), 0.45)
	var timber: StandardMaterial3D = _tex(TIMBER_TEX, Color(0.72, 0.52, 0.34), 0.6)
	var iron: StandardMaterial3D = _plain(Color(0.15, 0.14, 0.13), 0.6, 0.3)      # dark worn steel (the palette iron is a white mirror without reflections)
	_apply_light()

	# ground floor: the tunnel from the hideout (-z) into the shaft base
	_box(Vector3(9.0, 0.4, 24.0), Vector3(0.0, -0.2, -5.0), gravel)
	_box(Vector3(2.0, 6.0, 14.0), Vector3(-3.5, 2.8, -12.0), _rock)      # tunnel walls (x = +-2.5 clear)
	_box(Vector3(2.0, 6.0, 14.0), Vector3(3.5, 2.8, -12.0), _rock)
	_box(Vector3(9.0, 1.2, 14.0), Vector3(0.0, 5.4, -12.0), rock_dark)  # tunnel roof
	for tz in [-14.0, -9.0]:                                              # timber frames in the tunnel
		_box(Vector3(0.4, 4.8, 0.4), Vector3(-2.4, 2.4, tz), timber)
		_box(Vector3(0.4, 4.8, 0.4), Vector3(2.4, 2.4, tz), timber)
		_box(Vector3(5.2, 0.4, 0.4), Vector3(0.0, 4.7, tz), timber)
	_lantern(Vector3(-2.1, 3.4, -11.5), 3.0, 10.0)
	_lantern(Vector3(2.1, 3.4, -6.0), 3.0, 10.0)
	# the shaft walls (rock), the tunnel mouth in the south wall, the surface mouth in the north wall
	var h: float = ROOF_Y
	for sx in [-1.0, 1.0]:
		_box(Vector3(2.0, h, 10.0), Vector3((SHAFT_HALF + 1.0) * sx, h * 0.5, 0.0), _rock)
	_box(Vector3(3.2, h, 1.6), Vector3(-3.1 * 1.0 - 0.1, h * 0.5, -SHAFT_HALF - 0.8), _rock)    # south wall, either side of the mouth
	_box(Vector3(3.2, h, 1.6), Vector3(3.2, h * 0.5, -SHAFT_HALF - 0.8), _rock)
	_box(Vector3(5.0, h - 5.0, 1.6), Vector3(0.0, 5.0 + (h - 5.0) * 0.5, -SHAFT_HALF - 0.8), rock_dark)  # over the mouth
	_box(Vector3(9.0, 1.6, 10.0), Vector3(0.0, ROOF_Y + 0.8, 0.0), rock_dark)                    # roof
	# north wall: solid below the surface floor, an opening above it
	_box(Vector3(9.0, TOP_Y, 1.4), Vector3(0.0, TOP_Y * 0.5, SHAFT_HALF + 0.7), _rock)
	_box(Vector3(2.9, 8.0, 1.4), Vector3(-3.05, TOP_Y + 4.0, SHAFT_HALF + 0.7), _rock)
	_box(Vector3(2.9, 8.0, 1.4), Vector3(3.05, TOP_Y + 4.0, SHAFT_HALF + 0.7), _rock)
	_box(Vector3(3.2, 3.0, 1.4), Vector3(0.0, TOP_Y + 6.5, SHAFT_HALF + 0.7), rock_dark)
	# boulders at the wall bases so no straight box edge reads
	var bz: float = -3.5
	while bz < 4.0:
		_boulder(Vector3(-SHAFT_HALF + 0.1, 0.0, bz), 1.5 + 0.5 * absf(sin(bz * 1.7)))
		_boulder(Vector3(SHAFT_HALF - 0.1, 0.0, bz + 0.6), 1.4 + 0.5 * absf(sin(bz * 2.1)))
		bz += 2.3
	# timber guide posts in the four corners + cross beams every 5 m, a lantern on each level
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_box(Vector3(0.5, ROOF_Y, 0.5), Vector3(4.1 * cx, ROOF_Y * 0.5, 4.1 * cz), timber)
	var by: float = 3.0
	while by < ROOF_Y:
		_box(Vector3(8.2, 0.35, 0.4), Vector3(0.0, by, -4.1), timber)
		_box(Vector3(8.2, 0.35, 0.4), Vector3(0.0, by, 4.1), timber)
		_box(Vector3(0.4, 0.35, 8.2), Vector3(-4.1, by, 0.0), timber)
		_box(Vector3(0.4, 0.35, 8.2), Vector3(4.1, by, 0.0), timber)
		by += 5.0
	for ly in [3.2, 10.5, 18.0]:
		_lantern(Vector3(-3.7, ly, 3.7), 3.4, 11.0)
		_lantern(Vector3(3.7, ly + 1.4, -3.7), 3.4, 11.0)
	# the first floor (MID_Y): a timber gallery on the east side with a plank door, so the climb has a landmark
	_box(Vector3(1.6, 0.3, 6.0), Vector3(3.5, MID_Y - 0.15, 0.0), timber)
	_box(Vector3(0.12, 1.0, 6.0), Vector3(2.75, MID_Y + 0.5, 0.0), timber)
	_box(Vector3(0.12, 2.6, 2.2), Vector3(4.44, MID_Y + 1.3, 0.0), timber)                       # a plank door in the east wall
	_box(Vector3(0.16, 0.12, 0.5), Vector3(4.36, MID_Y + 1.2, 0.7), iron)
	# the surface landing: floor slab, daylight beyond (the sky + the first trees)
	_box(Vector3(9.0, 0.5, 14.0), Vector3(0.0, TOP_Y - 0.25, 11.5), gravel)
	_surface_outside()
	# pulley wheel + the counterweight that sinks as the cage climbs
	var wheel := _cyl(1.1, 1.1, 0.5, Vector3(0.0, ROOF_Y - 1.6, 0.0), iron, null, 20)
	wheel.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_counter = Node3D.new()
	_counter.position = Vector3(-3.55, TOP_Y, 3.55)
	_visuals.add_child(_counter)
	_box(Vector3(0.9, 1.2, 0.9), Vector3(0.0, 0.0, 0.0), iron, _counter)
	_build_cage(timber, iron)
	_build_lever()


func _boulder(pos: Vector3, size: float) -> void:
	if not ResourceLoader.exists(RunnerView.BOULDER_ROCK_MODEL):
		return
	var b: Node3D = (load(RunnerView.BOULDER_ROCK_MODEL) as PackedScene).instantiate()
	b.scale = Vector3.ONE * size
	b.position = pos - Vector3(0.0, 0.1 * size, 0.0)
	b.rotation.y = pos.x * 1.3 + pos.z * 0.7
	RunnerView.self_light(b, 0.05, Color(1.0, 0.75, 0.5))
	for mesh in b.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _rock
	_visuals.add_child(b)


func _apply_light() -> void:
	var env: Environment = Ep2Palette.make_environment()
	env.ambient_light_color = Color(0.62, 0.60, 0.60)
	env.ambient_light_energy = 0.38
	env.fog_light_color = Color(0.30, 0.22, 0.15)
	env.fog_density = 0.010
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.06
	_env_node.environment = env
	# daylight from the surface mouth (+z) travelling into the shaft and down: it only reaches the top landing
	_sun.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	_sun.light_color = Color(1.0, 0.93, 0.80)
	_sun.light_energy = 1.1
	_sun.shadow_enabled = true


func _surface_outside() -> void:
	var grass: StandardMaterial3D = _tex(GRAVEL_TEX, Color(0.30, 0.42, 0.20), 0.30)
	_box(Vector3(80.0, 0.5, 60.0), Vector3(0.0, TOP_Y - 0.26, 48.0), grass)
	var bark: StandardMaterial3D = _plain(Color(0.28, 0.19, 0.12), 0.95)
	var leaf: StandardMaterial3D = _plain(Color(0.12, 0.30, 0.13), 0.9)
	var leaf2: StandardMaterial3D = _plain(Color(0.17, 0.38, 0.15), 0.9)
	var i: int = 0
	for z in [14.0, 18.0, 22.0, 27.0, 33.0, 40.0]:
		for x in [-9.0, -5.5, 5.5, 9.5, -14.0, 14.0]:
			var jitter: float = sin(z * 3.1 + x * 1.7)
			var px: float = x + jitter * 1.6
			var hh: float = 7.0 + 3.0 * absf(jitter)
			_cyl(0.32, 0.46, hh, Vector3(px, TOP_Y + hh * 0.5, z + cos(x) * 1.4), bark, null, 7)
			_cyl(0.0, 2.6 + absf(jitter), 5.5, Vector3(px, TOP_Y + hh + 1.2, z + cos(x) * 1.4), leaf if i % 2 == 0 else leaf2, null, 8)
			i += 1
	# a bright sky wall so the opening reads as daylight, not a black hole
	var sky := _glow(Color(0.62, 0.78, 0.92), 1.4)
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(Vector3(120.0, 50.0, 0.5), Vector3(0.0, TOP_Y + 18.0, 75.0), sky)


func _build_cage(timber: StandardMaterial3D, iron: StandardMaterial3D) -> void:
	_cage = Node3D.new()
	_cage.name = "Cage"
	_visuals.add_child(_cage)
	_box(Vector3(CAGE_HALF * 2.0, 0.25, CAGE_HALF * 2.0), Vector3(0.0, -0.125, 0.0), timber, _cage)
	for bx in [-1.2, 0.0, 1.2]:
		_box(Vector3(0.14, 0.05, CAGE_HALF * 2.0 + 0.02), Vector3(bx, 0.01, 0.0), iron, _cage)    # iron straps across the planks
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_box(Vector3(0.1, 2.7, 0.1), Vector3((CAGE_HALF - 0.07) * cx, 1.35, (CAGE_HALF - 0.07) * cz), iron, _cage)
	for tz in [-1.0, 1.0]:                                                                           # top frame: four thin bars (a solid roof hid Lil Blunt from the camera)
		_box(Vector3(CAGE_HALF * 2.0, 0.1, 0.1), Vector3(0.0, 2.75, (CAGE_HALF - 0.07) * tz), iron, _cage)
		_box(Vector3(0.1, 0.1, CAGE_HALF * 2.0), Vector3((CAGE_HALF - 0.07) * tz, 2.75, 0.0), iron, _cage)
	for sx in [-1.0, 1.0]:                                                                           # waist-high side rails
		_box(Vector3(0.08, 0.08, CAGE_HALF * 2.0), Vector3((CAGE_HALF - 0.07) * sx, 1.0, 0.0), iron, _cage)
	_box(Vector3(CAGE_HALF * 2.0, 0.08, 0.08), Vector3(0.0, 1.0, -(CAGE_HALF - 0.07)), iron, _cage)  # the tunnel side
	_gate = Node3D.new()
	_gate.position = Vector3(0.0, 0.0, CAGE_HALF - 0.07)                                             # the surface side: a sliding gate
	_cage.add_child(_gate)
	_box(Vector3(CAGE_HALF * 2.0 - 0.2, 0.08, 0.08), Vector3(0.0, 1.0, 0.0), iron, _gate)
	_box(Vector3(CAGE_HALF * 2.0 - 0.2, 0.08, 0.08), Vector3(0.0, 0.45, 0.0), iron, _gate)
	# four chains up to the pulley
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var ch := _cyl(0.04, 0.04, 14.0, Vector3(1.6 * cx, 2.75 + 7.0, 1.6 * cz), iron, _cage, 6)
			ch.name = "Chain"
	_cage.add_child(_cage_lantern())
	_cage.position = Vector3(0.0, 0.0, 0.0)


func _cage_lantern() -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 2.55, 0.0)
	if ResourceLoader.exists(LANTERN_MODEL):
		var l: Node3D = (load(LANTERN_MODEL) as PackedScene).instantiate() as Node3D
		if l:
			l.scale = Vector3.ONE * 0.5
			holder.add_child(l)
	var o := Ep2Palette.make_lantern_light()
	o.light_energy = 3.2
	o.omni_range = 9.0
	holder.add_child(o)
	return holder


## THE DISGUISE: a short stub of the wall's own rock material, bedded in a boulder at knee height, with a rough stone cap.
## Nothing about it is lit, coloured or shaped like a lever until Inferno's hand closes on it.
func _build_lever() -> void:
	_lever = Node3D.new()
	_lever.name = "HiddenLever"
	_lever.position = LEVER_POS
	_visuals.add_child(_lever)
	var arm := _cyl(0.06, 0.07, 0.55, Vector3(0.14, 0.0, 0.0), _rock, _lever, 7)
	arm.rotation = Vector3(0.0, 0.0, deg_to_rad(-72.0))
	var cap := _sphere(0.11, Vector3(0.38, 0.12, 0.0), _rock, _lever, 0.8)
	cap.name = "StoneCap"
	var nest := _sphere(0.5, Vector3(-0.1, -0.12, 0.05), _rock, _lever, 0.8)       # the boulder it hides in
	nest.name = "Nest"


func get_lever_position() -> Vector3:
	return LEVER_POS


func get_lever_node() -> Node3D:
	return _lever


func get_rock_material() -> StandardMaterial3D:
	return _rock


func get_cage_y() -> float:
	return _cage_y


func is_gate_open() -> bool:
	return _gate_open > 0.9


# --- the story --------------------------------------------------------------------------------------------------------

func _on_setup() -> void:
	_beat = Beat.ARRIVE
	_player_pos = START_POS
	_ground_y = 0.0
	_player_yaw = 0.0
	_look_yaw = 0.0
	_look_pitch = -0.22
	if _bull == null:
		_bull = _build_bull(START_POS + Vector3(-1.2, 0.0, 4.0), 0.0)
	_loop = _loop_player(LOOP_SFX, -8.0)
	if _camera:
		_camera.position = START_POS + Vector3(0.0, 2.6, -4.2)
	_on_beat_entered(Beat.ARRIVE)


func _on_beat_entered(b: int) -> void:
	match b:
		Beat.ARRIVE:
			_start_show([
				{"do": "walk", "to": Vector3(-1.0, 0.0, -3.0), "speed": 3.0},
				{"do": "face", "at": Vector3(0.0, 0.0, -9.0)},
				FacilityShow._say("vo_bull_lift1", 0.2),
				{"do": "walk", "to": CAGE_STAND_BULL, "speed": 3.0},
				{"do": "face", "at": Vector3(0.0, 0.0, -4.0)}])
		Beat.LEVER:
			_bull_on_cage = false
			_start_show([
				{"do": "call", "fn": func() -> void: set_camera_shot(Vector3(2.9, 2.1, -4.6), Vector3(-2.2, 1.0, -0.4), 60.0)},
				{"do": "call", "fn": func() -> void: _begin_carry_line("vo_bull_lift_lever")},
				{"do": "walk", "to": LEVER_STAND, "speed": 2.6},
				{"do": "face", "at": LEVER_POS},
				{"do": "reach", "at": LEVER_POS + Vector3(0.3, 0.1, 0.0), "ramp": 0.5, "hold": 0.35, "lean": 0.3},
				{"do": "call", "fn": _pull_lever},
				{"do": "wait", "t": 1.0},
				{"do": "release", "ramp": 0.5, "t": 0.45},
				{"do": "walk", "to": CAGE_STAND_BULL, "speed": 2.8},
				{"do": "face", "at": Vector3(0.0, 0.0, -4.0)}], true)
		Beat.RISE:
			release_camera()
			_rise_t = 0.0
			_bull_on_cage = true
			if _loop and not _loop.playing:
				_loop.play()
			_start_show([
				{"do": "face", "at": _player_pos},
				FacilityShow._say("vo_bull_plan1", 0.25),
				FacilityShow._say("vo_bull_plan2", 0.25),
				FacilityShow._say("vo_bull_plan3", 0.3),
				FacilityShow._say("vo_lb_plan_reply", 0.3)])
		Beat.SURFACE:
			_sfx("ep2_lift_arrive")
			if _loop:
				_loop.stop()
			camera_max = Vector3(4.1, 40.0, 16.0)
			_bull_on_cage = false
			_start_show([
				FacilityShow._say("vo_bull_lift_arrive", 0.2),
				{"do": "walk", "to": Vector3(0.0, TOP_Y, 9.5), "speed": 2.8},
				{"do": "face", "at": Vector3(0.0, TOP_Y, 0.0)}])


func _pull_lever() -> void:
	_lever_t = 0.0
	_sfx("ep2_lift_start")


func _show_finished() -> void:
	match _beat:
		Beat.ARRIVE:
			pass          # BOARD is entered by the player stepping onto the cage (see _tick)
		Beat.LEVER:
			_advance_to(Beat.RISE)
		Beat.RISE:
			pass          # SURFACE follows the cage reaching the top (see _tick)
		Beat.SURFACE:
			pass


func _tick(delta: float) -> void:
	# lever animation: the stone arm swings down 50 degrees
	if _lever_t >= 0.0 and _lever_t < 1.0 and _lever:
		_lever_t = minf(1.0, _lever_t + delta / 0.8)
		var arm: Node3D = _lever.get_child(0) as Node3D
		if arm:
			arm.rotation.z = deg_to_rad(-72.0 + 50.0 * _lever_t)
	_on_cage = _player_on_cage()
	match _beat:
		Beat.ARRIVE:
			if _on_cage and not _show_active:
				_advance_to(Beat.BOARD)
		Beat.BOARD:
			# a short breath, then the Bull pulls the hidden lever
			if _elapsed > 0.0 and _on_cage:
				_advance_to(Beat.LEVER)
		Beat.RISE:
			_rise_t += delta
			var k: float = clampf(_rise_t / RISE_SECONDS, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			_cage_y = TOP_Y * k
			if _loop:
				_loop.volume_db = -8.0 + 3.0 * sin(_anim_t * 3.0)
			if _rise_t >= RISE_SECONDS and not _show_active:
				_cage_y = TOP_Y
				_advance_to(Beat.SURFACE)
		Beat.SURFACE:
			_cage_y = TOP_Y
			_gate_open = minf(1.0, _gate_open + delta / 1.2)
			if _player_pos.z >= EXIT_Z and not _show_active:
				_advance_to(Beat.DONE)
				_resolve({"next_chamber": NEXT_CHAMBER, "next_mode": "stealth"})
	if _cage:
		_cage.position.y = _cage_y
		if _gate:
			_gate.position.x = 1.9 * _gate_open
	if _counter:
		_counter.position.y = TOP_Y - _cage_y + 0.6
	# the cage carries whoever stands on it
	if _beat >= Beat.RISE and _on_cage_xz(_player_pos):
		_set_ground(_cage_y)
	elif _beat >= Beat.SURFACE:
		_set_ground(TOP_Y)
	if _bull_on_cage and _bull != null:
		_bull.position.y = _cage_y


func _on_cage_xz(p: Vector3) -> bool:
	return absf(p.x) < CAGE_HALF - 0.15 and absf(p.z) < CAGE_HALF - 0.15


func _player_on_cage() -> bool:
	return _on_cage_xz(_player_pos) and absf(_player_pos.y - _cage_y) < 0.6


# --- walking limits ---------------------------------------------------------------------------------------------------

func _collide(p: Vector3) -> Vector3:
	var q := p
	if _beat >= Beat.LEVER and _beat < Beat.SURFACE:
		# on the rising cage: the railings (the surface side is the gate, shut until the top)
		q.x = clampf(q.x, -(CAGE_HALF - 0.3), CAGE_HALF - 0.3)
		q.z = clampf(q.z, -(CAGE_HALF - 0.3), CAGE_HALF - 0.3)
		return q
	if _beat >= Beat.SURFACE:
		if q.z > CAGE_HALF:
			q.x = clampf(q.x, -2.4, 2.4)       # through the surface mouth
		else:
			q.x = clampf(q.x, -(CAGE_HALF - 0.3), CAGE_HALF - 0.3)
		q.z = clampf(q.z, -(CAGE_HALF - 0.3), 14.0)
		return q
	# ground floor: the tunnel then the shaft base
	if q.z < -SHAFT_HALF:
		q.x = clampf(q.x, -2.3, 2.3)
		q.z = maxf(q.z, -17.0)
	else:
		q.x = clampf(q.x, -(SHAFT_HALF - 0.5), SHAFT_HALF - 0.5)
		q.z = clampf(q.z, -SHAFT_HALF - 5.0, SHAFT_HALF - 0.6)
	return q


func _can_jump() -> bool:
	return true
