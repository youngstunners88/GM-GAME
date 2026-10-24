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
## The founder-target set (skill ep2-set-piece-forge): modular walkway kit, the Tripo cage + skull, Muapi textures and banner.
const KIT_MODEL := "res://src/episode2/assets/mine_lift/mine_lift_kit.glb"
const CAGE_MODEL := "res://src/episode2/assets/mine_lift/mine_lift_cage.glb"
const SKULL_MODEL := "res://src/episode2/assets/mine_lift/bull_skull.glb"
const PLANK_TEX := "res://src/episode2/assets/mine_lift/tex_lift_planks.jpg"
const IRON_TEX := "res://src/episode2/assets/mine_lift/tex_lift_rust_iron.jpg"
const BANNER_TEX := "res://src/episode2/assets/mine_lift/tex_lift_banner.png"
const BARREL_MODEL := "res://src/episode2/assets/mine_lift/mine_barrel.glb"
const CRATE_MODEL := "res://src/episode2/assets/mine_lift/mine_crate.glb"
const NEXT_CHAMBER := "woods_quad"

# --- layout (metres) ---
const SHAFT_HALF := 4.5            # the shaft is 9 m square
const CAGE_HALF := 1.9             # the cage is 3.8 m square
const MID_Y := 7.5                 # first floor up
const TOP_Y := 15.0                # the surface (second floor up)
const ROOF_Y := 26.0              # tall enough for the Tripo cage's roof gears at the surface
const PIT_Y := -7.0                # the floor of the pit under the walkway bridge
const CAVE_H := 9.5                # the cavern roof
const CAVE_HALF_X := 7.4           # the cavern is ~15 m wide (the bridge + the right-hand gallery)
const CAVE_Z0 := -14.0             # the cavern's back wall (the hideout tunnel mouth): an 8 m approach
const CAGE_TOP := 3.75             # the cage roof (its gears stand ~1.8 m above it)
const RISE_SECONDS := 22.0
const START_POS := Vector3(0.0, 0.0, -11.0)
const CAGE_STAND_BULL := Vector3(-0.95, 0.0, 0.95)    # inside the cage, in the back-left corner beside the lever (not between Lil Blunt and it)
const CAGE_DOOR_HALF := 1.05        # the doorways' half width (cut out of the Tripo cage by tools/ep2_blender/cage_open_doorways.py)
const BODY_R := 0.3                  # Lil Blunt's body radius against the cage bars
const EXIT_Z := 8.0
## Lift mouth z=6 matches woods mouth z=4.
const SURFACE_OFFSET := Vector3(0.0, TOP_Y, 2.0)
var _surface_environment: Environment = null
var _surface_sun: DirectionalLight3D = null
var _mine_environment: Environment = null
var _surface_daylight := false
## THE LEVER IS INSIDE THE CAGE (founder 2026-10-13: "why is the lever not inside the elevator"): an iron handle on the cage's
## left wall, rusted the same as the cage's own struts so it reads as part of the frame - hidden in plain sight. Cage-local
## (it rides up with the cage). Inferno pulls it from where he stands; nobody walks out through the bars any more.
const LEVER_POS := Vector3(-1.62, 1.15, 0.35)

## THE OPEN DOOR (founder 2026-10-24: "i dont want a transition at that point. he needs to literally just walk through into the section
## that [has] the elevator ... we should be able to see the elevator from within the smelting facility"). While the hideout is played,
## this room - already built behind it - is the view through the hideout's open doorway: the session root mirrors the player's camera
## into this room's camera every frame (portal_view) and the doorway shows that image. The black tunnel plug and the back wall stand
## between that camera and the cavern, so they are hidden while the doorway looks through them, and come back once Lil Blunt has walked
## in past them. The hand-over then carries his real position and Inferno's (lift_player / lift_bull), not START_POS.
## Where the hideout's doorway plane lands in this room (the tunnel plug's front face is CAVE_Z0 + 0.4).
const PORTAL_Z := CAVE_Z0 + 0.4
## Lil Blunt may stand right at the mouth after the hand-over (the old floor stopped him 0.6 m in, past where the doorway put him).
const MOUTH_MIN_Z := CAVE_Z0 + 0.35
var _mouth_plug: MeshInstance3D = null
var _mouth_wall: MeshInstance3D = null
var _mouth_open: bool = false


## The hideout's doorway is about to look into this room: open the mouth, keep Inferno hidden until the hideout's Inferno walks through.
func portal_begin() -> void:
	_set_mouth_open(true)
	if _bull != null:
		_bull.visible = false


## One frame of the view through the hideout's doorway. `d` = {"xf": the camera in this room's frame, "fov": degrees,
## "bull": Inferno's position here once the hideout's Inferno has passed the doorway (absent before), "bull_facing": radians}.
func portal_view(d: Dictionary) -> void:
	if _camera == null:
		return
	_camera.current = true
	_camera.global_transform = d.get("xf", _camera.global_transform)
	_camera.fov = float(d.get("fov", _camera.fov))
	if _bull != null:
		_bull.visible = d.has("bull")
		if d.has("bull"):
			_bull.position = d["bull"]
			_bull.facing = float(d.get("bull_facing", _bull.facing))


func _set_mouth_open(open: bool) -> void:
	_mouth_open = open
	for n in [_mouth_plug, _mouth_wall]:
		if n != null:
			n.visible = not open

var _rock: StandardMaterial3D = null
var _kit_root: Node3D = null
var _kit_mats: Dictionary = {}
var _halo_tex: GradientTexture2D = null
var _cage: Node3D = null
var _gate: Node3D = null
var _exit_crossbeam: Node3D = null
var _gate_in: Node3D = null          # the walkway-side gate: up (open) until both are aboard, then it drops shut
var _gate_in_k: float = 1.0          # 1 = raised / open, 0 = down / shut
var _gate_in_goal: float = 1.0
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
	camera_max = Vector3(4.1, 25.0, 4.1)


func _chamber_id() -> String:
	return "mine_lift"


func _beat_label(b: int) -> String:
	return Beat.keys()[clampi(b, 0, Beat.size() - 1)]


# --- the set ----------------------------------------------------------------------------------------------------------

var _rock_dark: StandardMaterial3D = null
var _gravel: StandardMaterial3D = null
var _iron: StandardMaterial3D = null
var _timber: StandardMaterial3D = null


func _build_room() -> void:
	for step in _build_steps():
		(step as Callable).call()


## The room in slices (each a few ms), so the session root can build it behind the hideout while Lil Blunt is still crossing the lava.
func _build_steps() -> Array:
	return [_build_materials, _step_cavern, _step_shaft, _step_top, _step_pulley, _build_cage_step, _build_lever, _step_bull]


func _build_materials() -> void:
	# FOUNDER TARGET (2026-10-10, artifacts/episode2-gold-mine/references/founder_2026-10-10/lift_walkway_target.jpg; skill ep2-set-piece-forge):
	# a plank walkway with timber rails and sagging chains over a dark pit, the rusted riveted iron cage with gears on its roof hanging on
	# chains, oil lanterns, bull skulls and tattered bull banners on timber walls, warm smoky haze. Rebuilt from a modular kit
	# (mine_lift_kit.glb: Deck2m / Post / Rail2m / Chain2m / Beam4m) + the Tripo cage and skull + Muapi textures and banner.
	_rock = _tex(ROCK_TEX, Color(0.42, 0.36, 0.31), 0.22)
	_rock_dark = _tex(ROCK_TEX, Color(0.22, 0.19, 0.16), 0.16)
	_gravel = _tex(GRAVEL_TEX, Color(0.30, 0.26, 0.22), 0.45)
	_kit_mats = {
		"Planks": _tex_mat(PLANK_TEX, Color(0.92, 0.86, 0.80), 0.77, 0.88),
		"Timber": _tex_mat(PLANK_TEX, Color(0.62, 0.50, 0.40), 1.4, 0.85),
		"RustIron": _tex_mat(IRON_TEX, Color(0.95, 0.85, 0.80), 2.2, 0.62, 0.35),
	}
	_iron = _kit_mats["RustIron"]
	_timber = _kit_mats["Timber"]
	_apply_light()


## The first views of the lift (the tunnel mouth, both sides, the cage from the walkway, the shaft above) for the GPU warm-up.
func _warm_views() -> Array:
	var eye: Vector3 = START_POS + Vector3(0.0, 1.55, 0.0)
	return [{"eye": eye, "yaw": 0.0, "pitch": -0.04}, {"eye": eye, "yaw": 0.7, "pitch": -0.1}, {"eye": eye, "yaw": -0.7, "pitch": -0.1},
		{"eye": Vector3(0.0, 1.55, -2.0), "yaw": 0.0, "pitch": 0.5}, {"eye": Vector3(0.0, 1.55, 2.0), "yaw": 0.4, "pitch": 0.0}]


func _step_bull() -> void:
	if _bull == null:      # Inferno is built (and his shaders warmed) in the background too, not at the cut
		_bull = _build_bull(START_POS + Vector3(-1.2, 0.0, 4.0), 0.0)


func _step_cavern() -> void:
	_build_cavern(_rock_dark, _gravel, _iron)


func _step_shaft() -> void:
	_build_shaft(_rock_dark, _gravel, _timber, _iron)


func _step_top() -> void:
	_build_top(_gravel)


func _step_pulley() -> void:
	# pulley wheel + the counterweight that sinks as the cage climbs
	var wheel := _cyl(1.1, 1.1, 0.5, Vector3(0.0, ROOF_Y - 1.6, 0.0), _iron, null, 20)
	wheel.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_counter = Node3D.new()
	_counter.position = Vector3(-3.55, TOP_Y, 3.55)
	_visuals.add_child(_counter)
	_box(Vector3(0.9, 1.2, 0.9), Vector3(0.0, 0.0, 0.0), _iron, _counter)


func _build_cage_step() -> void:
	_build_cage(_timber, _iron)


## THE CAVERN (z CAVE_Z0 .. -5.5): the walkway bridge from the hideout tunnel to the shaft, over a pit, with a second gallery on the right.
## 8 m long, not 13 (Jev 0.99 / microsoft-decision-1 0.96 on the measured layout): from the tunnel mouth the cage fills a quarter of the
## view like the founder's target, instead of a distant 10 %.
func _build_cavern(rock_dark: StandardMaterial3D, gravel: StandardMaterial3D, iron: StandardMaterial3D) -> void:
	var zc: float = (CAVE_Z0 + -5.0) * 0.5
	var zl: float = -5.0 - CAVE_Z0
	_box(Vector3(16.0, 1.0, zl + 1.0), Vector3(0.0, PIT_Y - 0.5, zc), gravel)                              # pit floor, far below
	for sx in [-1.0, 1.0]:
		_box(Vector3(2.0, CAVE_H - PIT_Y, zl + 1.0), Vector3((CAVE_HALF_X + 1.0) * sx, (CAVE_H + PIT_Y) * 0.5, zc), _rock)
		var w: float = CAVE_HALF_X - SHAFT_HALF + 1.0                                                      # the cavern meets the shaft's south wall
		_box(Vector3(w, CAVE_H - PIT_Y, 1.6), Vector3((SHAFT_HALF + w * 0.5) * sx, (CAVE_H + PIT_Y) * 0.5, -SHAFT_HALF - 0.8), _rock)
	_mouth_wall = _box(Vector3(18.0, CAVE_H - PIT_Y, 2.0), Vector3(0.0, (CAVE_H + PIT_Y) * 0.5, CAVE_Z0 - 1.0), _rock)  # back wall (the hideout side)
	_box(Vector3(18.0, 1.6, zl + 1.0), Vector3(0.0, CAVE_H + 0.8, zc), rock_dark)                          # cavern roof
	# the hideout tunnel mouth in the back wall, framed in timber
	_mouth_plug = _box(Vector3(3.6, 4.2, 0.6), Vector3(0.0, 2.1, CAVE_Z0 + 0.1), _plain(Color(0.02, 0.015, 0.01), 1.0))
	for sx in [-1.0, 1.0]:
		_kit("Beam4m", Vector3(1.9 * sx, 2.0, CAVE_Z0 + 0.6), Vector3(0.0, 0.0, PI * 0.5), Vector3(1.05, 1.0, 1.0))
	_kit("Beam4m", Vector3(0.0, 4.3, CAVE_Z0 + 0.6), Vector3.ZERO, Vector3(1.15, 1.0, 1.0))
	_skull(Vector3(0.0, 5.0, CAVE_Z0 + 0.8), 0.0)
	# the bridge: 3 m wide, deck top at y = 0, rails + chains both sides
	_walkway(Vector3(0.0, 0.0, CAVE_Z0 + 0.5), 4, true, true)
	# timber bents carrying the bridge: posts from the pit floor to the roof, a cap beam, a bearer under the deck and a brace
	for bz in [CAVE_Z0 + 2.0, CAVE_Z0 + 6.0]:
		for sx in [-1.0, 1.0]:
			_kit("Beam4m", Vector3(1.75 * sx, (PIT_Y + CAVE_H) * 0.5, bz), Vector3(0.0, 0.0, PI * 0.5), Vector3((CAVE_H - PIT_Y) / 4.0, 0.8, 0.8))
		_kit("Beam4m", Vector3(0.0, CAVE_H - 1.6, bz), Vector3.ZERO, Vector3(0.95, 0.9, 0.9))
		_kit("Beam4m", Vector3(0.0, -0.45, bz), Vector3.ZERO, Vector3(0.95, 0.7, 0.7))
		_kit("Beam4m", Vector3(0.0, PIT_Y * 0.5 - 0.6, bz), Vector3(0.0, 0.0, 0.62), Vector3(1.4, 0.6, 0.6))
		_haze_lantern(Vector3(-1.75, 2.6, bz), 3.6, 15.0)
		_haze_lantern(Vector3(1.75, 2.9, bz + 2.0), 3.6, 15.0)
	# the right-hand gallery (the target's second walkway, with the emblem wall). Looking down +z, screen-right is -x.
	_walkway(Vector3(-5.0, 0.0, CAVE_Z0 + 1.0), 3, false, true)
	for gz in [CAVE_Z0 + 2.0, CAVE_Z0 + 6.0]:
		_kit("Beam4m", Vector3(-5.0, -0.45, gz), Vector3.ZERO, Vector3(0.95, 0.7, 0.7))
		_kit("Beam4m", Vector3(-6.3, (PIT_Y - 0.4) * 0.5, gz), Vector3(0.0, 0.0, PI * 0.5), Vector3(-PIT_Y / 4.0, 0.7, 0.7))
	_emblem_wall(Vector3(-CAVE_HALF_X + 0.2, 0.0, CAVE_Z0 + 4.0))
	_brazier(Vector3(-5.9, 0.0, CAVE_Z0 + 1.4))
	_brazier(Vector3(-5.9, 0.0, CAVE_Z0 + 6.6))
	# the walls: rock behind a timber frame - posts every 4 m, two rails, a diagonal brace in every second bay
	for sx in [-1.0, 1.0]:
		var x: float = (CAVE_HALF_X - 0.25) * sx
		for fz in [CAVE_Z0 + 0.5, CAVE_Z0 + 4.5, CAVE_Z0 + 8.5]:
			_kit("Beam4m", Vector3(x, CAVE_H * 0.5 - 1.0, fz), Vector3(0.0, 0.0, PI * 0.5), Vector3((CAVE_H + 2.0) / 4.0, 0.8, 0.8))
		_kit("Beam4m", Vector3(x, 5.2, CAVE_Z0 + 4.5), Vector3(0.0, PI * 0.5, 0.0), Vector3(2.1, 0.7, 0.7))
		_kit("Beam4m", Vector3(x, 1.6, CAVE_Z0 + 4.5), Vector3(0.0, PI * 0.5, 0.0), Vector3(2.1, 0.6, 0.6))
		_kit("Beam4m", Vector3(x, 3.4, CAVE_Z0 + 6.5), Vector3(0.0, PI * 0.5, 0.78 * sx), Vector3(1.3, 0.55, 0.55))
	_skull(Vector3(CAVE_HALF_X - 0.3, 6.0, CAVE_Z0 + 4.5), -PI * 0.5)
	_banner(Vector3(CAVE_HALF_X - 0.3, 3.3, CAVE_Z0 + 2.5), -PI * 0.5, 1.0)
	_banner(Vector3(CAVE_HALF_X - 0.3, 3.1, CAVE_Z0 + 6.6), -PI * 0.5, 0.9)
	_banner(Vector3(-CAVE_HALF_X + 0.3, 5.6, CAVE_Z0 + 1.6), PI * 0.5, 0.85)
	_haze_lantern(Vector3(CAVE_HALF_X - 0.5, 3.0, CAVE_Z0 + 4.6), 3.2, 13.0)
	_haze_lantern(Vector3(CAVE_HALF_X - 0.5, 3.4, CAVE_Z0 + 8.2), 3.2, 13.0)
	_haze_lantern(Vector3(-CAVE_HALF_X + 0.5, 4.6, CAVE_Z0 + 8.2), 3.2, 13.0)
	_haze_lantern(Vector3(-SHAFT_HALF + 0.6, 3.2, -SHAFT_HALF + 0.4), 3.2, 12.0)
	_haze_lantern(Vector3(SHAFT_HALF - 0.6, 3.6, -SHAFT_HALF + 0.4), 3.2, 12.0)
	_lantern(Vector3(-2.0, PIT_Y + 1.2, CAVE_Z0 + 4.0), 2.0, 8.0)                                            # far down in the pit
	var ember := OmniLight3D.new()                                                                           # a brazier glowing in the pit
	ember.light_color = Color(1.0, 0.45, 0.15)
	ember.light_energy = 2.5
	ember.omni_range = 11.0
	ember.position = Vector3(3.0, PIT_Y + 1.0, CAVE_Z0 + 2.0)
	_visuals.add_child(ember)
	_box(Vector3(0.8, 0.5, 0.8), Vector3(3.0, PIT_Y + 0.25, CAVE_Z0 + 2.0), _glow(Color(1.0, 0.42, 0.1), 3.0))
	# a neutral fill high in the cavern so beams and the lift machinery read (art review: less amber wash, more structure)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.78, 0.80, 0.84)
	fill.light_energy = 0.9
	fill.omni_range = 18.0
	fill.position = Vector3(0.0, CAVE_H - 1.0, -4.0)
	_visuals.add_child(fill)
	# barrels, crates and a coil of chain on the gallery and the landing (the target's clutter), never in the walking lane
	_prop(BARREL_MODEL, Vector3(-5.7, 0.0, CAVE_Z0 + 2.6), 0.4)
	_prop(BARREL_MODEL, Vector3(-6.4, 0.0, CAVE_Z0 + 3.1), 1.9)
	_prop(BARREL_MODEL, Vector3(-4.3, 0.0, CAVE_Z0 + 7.2), 0.8, Vector3(PI * 0.5, 0.0, 0.0), 0.36)        # one on its side
	_prop(CRATE_MODEL, Vector3(-6.3, 0.0, CAVE_Z0 + 5.6), 0.3)
	_prop(CRATE_MODEL, Vector3(-6.3, 0.62, CAVE_Z0 + 5.5), 1.1, Vector3.ZERO, 0.0, 0.8)
	_prop(BARREL_MODEL, Vector3(0.0, PIT_Y, CAVE_Z0 + 3.0), 2.0)
	_prop(CRATE_MODEL, Vector3(-1.5, PIT_Y, CAVE_Z0 + 5.0), 0.6)
	_prop(BARREL_MODEL, Vector3(3.6, 0.0, -3.6), 0.2)
	_prop(CRATE_MODEL, Vector3(3.5, 0.0, -2.6), 0.9)
	for k in 6:                                                                                             # a coil of chain beside the cage landing
		_kit("Chain2m", Vector3(-3.4 + 0.12 * k, 0.02 + 0.04 * k, -3.4 + 0.1 * k), Vector3(PI * 0.5, 0.9 * k, 0.0), Vector3(0.6, 0.6, 0.6))
	# hanging chains with pulley blocks in the air over the bridge
	for hc in [Vector3(-1.0, 0.0, CAVE_Z0 + 3.0), Vector3(0.8, 0.0, CAVE_Z0 + 5.5), Vector3(2.6, 0.0, CAVE_Z0 + 1.5)]:
		var ln: float = 3.2 + 1.6 * absf(sin(hc.z))
		_cyl(0.025, 0.025, ln, Vector3(hc.x, CAVE_H - ln * 0.5, hc.z), iron, null, 5)
		var dark := _plain(Color(0.10, 0.08, 0.07), 0.55, 0.6)                  # a pulley block: iron cheeks round a sheave, a hook below
		_box(Vector3(0.08, 0.32, 0.22), Vector3(hc.x, CAVE_H - ln - 0.12, hc.z), dark)
		var pw := _cyl(0.11, 0.11, 0.05, Vector3(hc.x, CAVE_H - ln - 0.1, hc.z), iron, null, 12)
		pw.rotation = Vector3(0.0, 0.0, PI * 0.5)
		_cyl(0.015, 0.015, 0.28, Vector3(hc.x, CAVE_H - ln - 0.4, hc.z), dark, null, 5)


## The target's secondary focal point: a timber board on the right gallery wall with emblems in iron rings.
func _emblem_wall(base: Vector3) -> void:
	var timber: StandardMaterial3D = _kit_mats["Timber"]
	var iron: StandardMaterial3D = _kit_mats["RustIron"]
	_box(Vector3(0.12, 2.6, 4.4), base + Vector3(0.0, 2.3, 0.0), timber)
	# THREE emblems, not the target's five: the founder's locked Fort Knox arc keeps that protocol out of this chapter
	# (tests/ep2_fort_knox_arc_test.tscn fails on its name anywhere in the interlude code).
	var logos: Array = ["logo_titanx.png", "logo_gold_mine.png", "logo_bear.png"]
	for i in logos.size():
		var path: String = "res://src/episode2/assets/textures/logos/" + String(logos[i])
		if not ResourceLoader.exists(path):
			continue
		var p: Vector3 = base + Vector3(0.1, 2.5 + (0.45 if i == 1 else 0.0), -1.4 + 1.4 * float(i))
		var ring := _cyl(0.4, 0.4, 0.06, p, iron, null, 20)
		ring.rotation = Vector3(0.0, 0.0, PI * 0.5)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.66, 0.66)
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(path)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.roughness = 0.5
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 0.25
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.material_override = m
		mi.position = p + Vector3(0.04, 0.0, 0.0)
		mi.rotation = Vector3(0.0, PI * 0.5, 0.0)
		_visuals.add_child(mi)


## THE SHAFT (9 m square around the cage): rock walls, a plank landing, timber guides, the first-floor gallery.
func _build_shaft(rock_dark: StandardMaterial3D, gravel: StandardMaterial3D, timber: StandardMaterial3D, iron: StandardMaterial3D) -> void:
	var h: float = ROOF_Y
	for sx in [-1.0, 1.0]:
		_box(Vector3(2.0, h - PIT_Y, 10.0), Vector3((SHAFT_HALF + 1.0) * sx, (h + PIT_Y) * 0.5, 0.0), _rock)
	_box(Vector3(9.0, h - 5.0, 1.6), Vector3(0.0, 5.0 + (h - 5.0) * 0.5, -SHAFT_HALF - 0.8), rock_dark)      # over the cavern mouth
	_box(Vector3(9.0, 1.6, 10.0), Vector3(0.0, ROOF_Y + 0.8, 0.0), rock_dark)
	_box(Vector3(9.0, TOP_Y, 1.4), Vector3(0.0, TOP_Y * 0.5, SHAFT_HALF + 0.7), _rock)
	for sx in [-1.0, 1.0]:
		_box(Vector3(2.9, 8.0, 1.4), Vector3(3.05 * sx, TOP_Y + 4.0, SHAFT_HALF + 0.7), _rock)
	_box(Vector3(3.2, h - TOP_Y - 5.0, 1.4), Vector3(0.0, TOP_Y + 5.0 + (h - TOP_Y - 5.0) * 0.5, SHAFT_HALF + 0.7), rock_dark)
	_box(Vector3(9.0, 0.6, 9.0), Vector3(0.0, -0.33, 0.0), gravel)                                          # under the landing
	var bz: float = -3.5
	while bz < 4.0:
		_boulder(Vector3(-SHAFT_HALF + 0.1, 0.0, bz), 1.3 + 0.4 * absf(sin(bz * 1.7)))
		bz += 2.6
	for lx in [-3.0, 0.0, 3.0]:                                                                                # planks over the whole base
		for lz in [-3.0, -1.0, 1.0, 3.0]:
			_kit("Deck2m", Vector3(lx, 0.0, lz), Vector3.ZERO, Vector3(1.25, 1.0, 1.0))
	for cx in [-1.0, 1.0]:                                                                                     # guide timbers in the corners
		for cz in [-1.0, 1.0]:
			_kit("Beam4m", Vector3(4.05 * cx, ROOF_Y * 0.5, 4.05 * cz), Vector3(0.0, 0.0, PI * 0.5), Vector3(ROOF_Y / 4.0, 1.1, 1.1))
	var by: float = 6.0                                                                                        # above the cage's roof gears (art review: a beam sliced its silhouette)
	while by < ROOF_Y:                                                                                         # cross beams every 5 m
		_kit("Beam4m", Vector3(0.0, by, -4.05), Vector3.ZERO, Vector3(2.0, 0.9, 0.9))
		var front_beam: Node3D = _kit("Beam4m", Vector3(0.0, by, 4.05), Vector3.ZERO, Vector3(2.0, 0.9, 0.9))
		if front_beam != null and absf(by - (TOP_Y + 1.0)) < 0.1:
			_exit_crossbeam = front_beam
			_exit_crossbeam.name = "SurfaceExitCrossbeam"
		_kit("Beam4m", Vector3(-4.05, by, 0.0), Vector3(0.0, PI * 0.5, 0.0), Vector3(2.0, 0.9, 0.9))
		_kit("Beam4m", Vector3(4.05, by, 0.0), Vector3(0.0, PI * 0.5, 0.0), Vector3(2.0, 0.9, 0.9))
		by += 5.0
	for ly in [3.0, 10.5, 18.0]:
		_lantern(Vector3(-3.7, ly, 3.7), 3.0, 10.0)
		_lantern(Vector3(3.7, ly + 1.4, -3.7), 3.0, 10.0)
	_skull(Vector3(0.0, 4.6, -SHAFT_HALF + 0.1), 0.0)
	_banner(Vector3(SHAFT_HALF - 0.1, 3.2, -1.5), -PI * 0.5, 1.0)
	# the first floor (MID_Y): a plank gallery on the east side with a door, so the climb has a landmark
	for gz in [-1.0, 1.0]:
		_kit("Deck2m", Vector3(3.4, MID_Y, gz), Vector3.ZERO, Vector3(0.75, 1.0, 1.0))
	for gz in [-2.0, 0.0, 2.0]:
		_kit("Post", Vector3(2.55, MID_Y, gz))
	for gz in [-2.0, 0.0]:
		_kit("Rail2m", Vector3(2.55, MID_Y, gz))
		_kit("Chain2m", Vector3(2.55, MID_Y, gz))
	_box(Vector3(0.12, 2.6, 2.2), Vector3(4.44, MID_Y + 1.3, 0.0), timber)
	_box(Vector3(0.16, 0.12, 0.5), Vector3(4.36, MID_Y + 1.2, 0.7), iron)
	_lantern(Vector3(4.2, MID_Y + 2.2, -1.6), 2.6, 8.0)
	_skull(Vector3(4.4, MID_Y + 3.2, 0.0), -PI * 0.5)


## THE TOP: a plank walkway out of the shaft through a timbered mine mouth into the daylight.
func _build_top(gravel: StandardMaterial3D) -> void:
	_walkway(Vector3(0.0, TOP_Y, 2.0), 2, true, true)
	_box(Vector3(3.0, 0.1, 0.5), Vector3(0.0, TOP_Y - 0.05, 2.0), _kit_mats["Planks"])                      # threshold: no gap to the shaft at the cage door
	_box(Vector3(9.0, 0.5, 14.0), Vector3(0.0, TOP_Y - 0.6, 11.5), gravel)                                  # ground under the walkway
	for sx in [-1.0, 1.0]:                                                                                   # the mine-mouth timber frame
		_kit("Beam4m", Vector3(1.75 * sx, TOP_Y + 2.1, SHAFT_HALF + 1.5), Vector3(0.0, 0.0, PI * 0.5), Vector3(1.1, 1.0, 1.0))
	_kit("Beam4m", Vector3(0.0, TOP_Y + 4.25, SHAFT_HALF + 1.5), Vector3.ZERO, Vector3(1.05, 1.0, 1.0))
	_skull(Vector3(0.0, TOP_Y + 4.85, SHAFT_HALF + 1.25), PI)
	_lantern(Vector3(1.42, TOP_Y + 1.45, 4.0), 2.4, 8.0)
	_surface_outside()


## A run of plank walkway from `start` along +z: `n` 2 m deck sections, 3 m wide, posts every 2 m with a top rail and a sagging chain.
func _walkway(start: Vector3, n: int, rail_left: bool, rail_right: bool) -> void:
	for i in n:
		var z: float = start.z + 2.0 * i
		_kit("Deck2m", Vector3(start.x, start.y, z + 1.0), Vector3.ZERO, Vector3(1.25, 1.0, 1.0))
		for sx in [-1.0, 1.0]:
			if (sx < 0.0 and not rail_left) or (sx > 0.0 and not rail_right):
				continue
			var px: float = start.x + 1.42 * sx
			_kit("Post", Vector3(px, start.y, z))
			_kit("Rail2m", Vector3(px, start.y, z))
			_kit("Chain2m", Vector3(px, start.y, z))
			if i == n - 1:
				_kit("Post", Vector3(px, start.y, z + 2.0))


## A lantern with a soft additive HALO card around it: the Compatibility renderer has no volumetric fog, and the target's lanterns glow
## in the smoke. The card is a camera-facing radial gradient, unshaded and additive, so it never darkens and costs one quad.
func _haze_lantern(pos: Vector3, energy: float = 4.2, rng: float = 16.0, halo: float = 1.6) -> void:
	_lantern(pos, energy, rng)
	_halo(pos, halo, Color(1.0, 0.62, 0.30, 0.55))


func _halo(pos: Vector3, size: float, c: Color) -> void:
	if _halo_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.35))
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 64
		_halo_tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.albedo_color = c
	m.albedo_texture = _halo_tex
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(mi)


## An iron fire basket on a post (the target's braziers on the right walkway): glowing coals, a flame halo and a warm light.
func _brazier(pos: Vector3) -> void:
	var iron: StandardMaterial3D = _kit_mats["RustIron"]
	_cyl(0.05, 0.07, 0.9, pos + Vector3(0.0, 0.45, 0.0), iron, null, 6)
	_cyl(0.32, 0.22, 0.3, pos + Vector3(0.0, 1.05, 0.0), iron, null, 10)
	_sphere(0.26, pos + Vector3(0.0, 1.18, 0.0), _glow(Color(1.0, 0.45, 0.12), 3.5), null, 0.45)
	_halo(pos + Vector3(0.0, 1.55, 0.0), 1.5, Color(1.0, 0.55, 0.2, 0.9))
	_halo(pos + Vector3(0.0, 1.35, 0.0), 0.8, Color(1.0, 0.8, 0.45, 0.9))
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.55, 0.25)
	o.light_energy = 3.0
	o.omni_range = 9.0
	o.position = pos + Vector3(0.0, 1.6, 0.0)
	_visuals.add_child(o)


## One piece of the modular kit (mine_lift_kit.glb), textured with the shared triplanar materials. Deck2m: centred, top at 0, 2 m along z;
## Post: its foot; Rail2m / Chain2m: start at a post and run 2 m along +z; Beam4m: centred, 4 m along x.
func _kit(piece: String, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, parent: Node3D = null) -> Node3D:
	if _kit_root == null:
		if not ResourceLoader.exists(KIT_MODEL):
			return null
		_kit_root = (load(KIT_MODEL) as PackedScene).instantiate() as Node3D
		for mi in _kit_root.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for i in m.mesh.get_surface_count():
				var src: Material = m.mesh.surface_get_material(i)
				var key: String = String(src.resource_name) if src != null else ""
				if _kit_mats.has(key):
					m.mesh.surface_set_material(i, _kit_mats[key])
	var src_node: Node3D = _kit_root.find_child(piece, true, false) as Node3D
	if src_node == null:
		return null
	var n: Node3D = src_node.duplicate() as Node3D
	n.transform = Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)      # LOCAL scale (Basis.scaled() scales world axes: an upright beam went 1.3 m thick)
	(parent if parent != null else _visuals).add_child(n)
	return n


func _tex_mat(path: String, tint: Color, uv_scale: float, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = _tex(path, tint, uv_scale)
	m.roughness = rough
	m.metallic = metal
	return m


## A bleached longhorn skull (Tripo model from the Muapi still), facing +z of `yaw`; a bone-white stand-in if it is not in the build.
func _skull(pos: Vector3, yaw: float, parent: Node3D = null) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	(parent if parent != null else _visuals).add_child(holder)
	if ResourceLoader.exists(SKULL_MODEL):
		holder.add_child((load(SKULL_MODEL) as PackedScene).instantiate())
		return
	var bone := _plain(Color(0.78, 0.72, 0.62), 0.8)
	_sphere(0.16, Vector3.ZERO, bone, holder, 1.3)
	for sx in [-1.0, 1.0]:
		var horn := _cyl(0.015, 0.05, 0.55, Vector3(0.3 * sx, 0.08, 0.0), bone, holder, 6)
		horn.rotation = Vector3(0.0, 0.0, -1.1 * sx)


## A Tripo prop (barrel / crate), standing on `pos` (its base at y = pos.y), turned `yaw`; `rot` tips it over (a barrel on its side
## lies with its axis level, raised by `lift` so it rests on its staves); `scl` scales it. Nothing is placed if the model is not in the build.
func _prop(path: String, pos: Vector3, yaw: float, rot: Vector3 = Vector3.ZERO, lift: float = 0.0, scl: float = 1.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var n: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	n.position = pos + Vector3(0.0, lift, 0.0)
	n.rotation = Vector3(rot.x, yaw, rot.z)
	n.scale = Vector3.ONE * scl
	_visuals.add_child(n)


## A tattered bull banner (the Muapi still keyed to alpha), hung flat on a wall facing +z of `yaw`.
func _banner(pos: Vector3, yaw: float, size: float) -> void:
	if not ResourceLoader.exists(BANNER_TEX):
		return
	var qm := QuadMesh.new()
	qm.size = Vector2(1.15, 1.8) * size
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(BANNER_TEX)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.albedo_color = Color(0.78, 0.66, 0.58)            # 40 % toward a dirty ochre (art review: the bright red fought the lanterns)
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = m
	mi.position = pos
	mi.rotation = Vector3(0.0, yaw, 0.0)
	_visuals.add_child(mi)


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
	# Graded against the founder's target with tools/ep2_forge/ref_metrics.py (skill ep2-set-piece-forge): the first pass (warm ambient + thick
	# warm fog) measured lum 0.09 vs 0.20, saturation 0.96 vs 0.56 and edge detail 0.28 of the target - one orange murk. The palette's rule holds:
	# COOL ambient against WARM lanterns, a thin haze, and enough exposure to read the timber.
	var env: Environment = Ep2Palette.make_environment()
	env.ambient_light_energy = 0.75
	env.fog_density = 0.011
	env.tonemap_exposure = 1.55
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_contrast = 1.12
	_env_node.environment = env
	# daylight from the surface mouth (+z) travelling into the shaft and down: it only reaches the top landing
	_sun.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	_sun.light_color = Color(1.0, 0.90, 0.74)
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true


func _surface_outside() -> void:
	# Use the playable wood's builder, meshes, deterministic placement and materials.
	# Three near slices only: no town, bears, quad, player or second running chamber.
	var source: Ep2Interlude = load("res://src/episode2/chamber/woods_quad.gd").new()
	var vista: Node3D = source.call("build_surface_vista")
	vista.name = "SurfaceWoods"
	vista.position = SURFACE_OFFSET
	_visuals.add_child(vista)
	_surface_environment = source._env_node.environment
	_surface_sun = source._sun
	source.remove_child(_surface_sun)
	_surface_sun.visible = false
	_visuals.add_child(_surface_sun)
	source.free()
	_mine_environment = _env_node.environment


func _surface_light() -> void:
	if _surface_environment == null:
		return
	# Enter the same daylight before the doorway cut, while keeping the shaft warm below.
	var daylight: bool = _cage_y >= TOP_Y - 0.5
	if daylight == _surface_daylight:
		return
	_surface_daylight = daylight
	if daylight and _vm != null:
		_vm.set_exposure(0.82)
		_vm.set_world_shadows(false)
		_vm.set_own_light(WoodsQuadChamber.VM_KEY_ENERGY, _surface_sun)
	_env_node.environment = _surface_environment if daylight else _mine_environment
	_sun.visible = not daylight
	_surface_sun.visible = daylight


func _build_cage(timber: StandardMaterial3D, iron: StandardMaterial3D) -> void:
	_cage = Node3D.new()
	_cage.name = "Cage"
	_visuals.add_child(_cage)
	if ResourceLoader.exists(CAGE_MODEL):
		# THE TRIPO CAGE (Muapi stills -> Tripo H3.1 multiview -> ai_prop_to_game.py): rusted riveted iron, plank panels, gears on the roof.
		# Its two doorways (the walkway side -z, the gate side +z) are cut out of the mesh in the clean-up.
		var model: Node3D = (load(CAGE_MODEL) as PackedScene).instantiate() as Node3D
		model.name = "CageModel"
		_cage.add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):       # darker, rougher iron than Tripo's bronze bake (art review)
			var mm := mi as MeshInstance3D
			for si in mm.mesh.get_surface_count():
				var src := mm.mesh.surface_get_material(si) as StandardMaterial3D
				if src != null:
					var d: StandardMaterial3D = src.duplicate()
					d.albedo_color = Color(0.62, 0.55, 0.52)
					d.roughness = 0.8
					mm.set_surface_override_material(si, d)
		_box(Vector3(CAGE_HALF * 2.0 - 0.2, 0.08, CAGE_HALF * 2.0 - 0.2), Vector3(0.0, 0.03, 0.0), _kit_mats["Planks"], _cage)   # the floor he stands on
	else:
		_box(Vector3(CAGE_HALF * 2.0, 0.25, CAGE_HALF * 2.0), Vector3(0.0, -0.125, 0.0), timber, _cage)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				_box(Vector3(0.1, CAGE_TOP, 0.1), Vector3((CAGE_HALF - 0.07) * cx, CAGE_TOP * 0.5, (CAGE_HALF - 0.07) * cz), iron, _cage)
		for tz in [-1.0, 1.0]:
			_box(Vector3(CAGE_HALF * 2.0, 0.1, 0.1), Vector3(0.0, CAGE_TOP, (CAGE_HALF - 0.07) * tz), iron, _cage)
			_box(Vector3(0.1, 0.1, CAGE_HALF * 2.0), Vector3((CAGE_HALF - 0.07) * tz, CAGE_TOP, 0.0), iron, _cage)
	_gate = Node3D.new()
	_gate.position = Vector3(0.0, 0.0, CAGE_HALF - 0.05)                                             # the surface side: a sliding gate of rusted bars
	_cage.add_child(_gate)
	for gy in [0.25, 1.4, 3.2]:
		_box(Vector3(CAGE_DOOR_HALF * 2.0 + 0.1, 0.09, 0.07), Vector3(0.0, gy, 0.0), iron, _gate)
	var gx: float = -CAGE_DOOR_HALF + 0.1
	while gx < CAGE_DOOR_HALF - 0.05:
		_box(Vector3(0.05, 3.1, 0.05), Vector3(gx, 1.7, 0.0), iron, _gate)
		gx += 0.3
	# the walkway-side gate (-z): a drop gate of the same rusted bars, RAISED (open) while they board, dropped shut behind them
	_gate_in = Node3D.new()
	_gate_in.name = "WalkwayGate"
	_gate_in.position = Vector3(0.0, 0.0, -CAGE_HALF + 0.05)
	_cage.add_child(_gate_in)
	for gy in [0.25, 1.4, 3.2]:
		_box(Vector3(CAGE_DOOR_HALF * 2.0 + 0.1, 0.09, 0.07), Vector3(0.0, gy, 0.0), iron, _gate_in)
	var gx2: float = -CAGE_DOOR_HALF + 0.1
	while gx2 < CAGE_DOOR_HALF - 0.05:
		_box(Vector3(0.05, 3.1, 0.05), Vector3(gx2, 1.7, 0.0), iron, _gate_in)
		gx2 += 0.3
	for cx in [-1.0, 1.0]:                                                                           # two heavy chains from the roof gears to the pulley
		var ch := _cyl(0.05, 0.05, 16.0, Vector3(0.9 * cx, CAGE_TOP + 9.5, 0.0), iron, _cage, 6)
		ch.name = "Chain"
	_cage.add_child(_cage_lantern())
	_cage.position = Vector3(0.0, 0.0, 0.0)


func _cage_lantern() -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(0.0, CAGE_TOP - 0.5, 0.0)
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


## THE LEVER, INSIDE THE CAGE: a short iron handle on a bracket on the cage's left wall, the same rusted iron as the cage's struts,
## no colour, no glow - it reads as part of the frame until Inferno's hand closes on it. A child of the cage, so it rides up.
func _build_lever() -> void:
	_lever = Node3D.new()
	_lever.name = "CageLever"
	_lever.position = LEVER_POS
	_cage.add_child(_lever)
	var iron: StandardMaterial3D = _iron
	var arm := _cyl(0.025, 0.03, 0.5, Vector3(0.0, 0.0, 0.0), iron, _lever, 7)       # pivots at the bracket, swings in the y-z plane
	arm.rotation = Vector3(deg_to_rad(-35.0), 0.0, 0.0)
	var grip := _cyl(0.04, 0.04, 0.14, Vector3(0.0, 0.25, 0.0), iron, arm, 7)
	grip.rotation = Vector3(0.0, 0.0, PI * 0.5)
	grip.name = "Grip"
	var bracket := _box(Vector3(0.06, 0.18, 0.18), Vector3(-0.04, 0.0, 0.0), iron, _lever)
	bracket.name = "Bracket"


func get_lever_position() -> Vector3:
	return _lever.global_position if _lever != null and _lever.is_inside_tree() else LEVER_POS


func get_lever_node() -> Node3D:
	return _lever


func get_rock_material() -> StandardMaterial3D:
	return _rock


func get_cage_y() -> float:
	return _cage_y


func is_gate_open() -> bool:
	return _gate_open > 0.9


# --- the story --------------------------------------------------------------------------------------------------------

func _wants_handoff() -> bool:
	return _beat == Beat.SURFACE and _player_pos.z >= EXIT_Z


func get_handoff() -> Dictionary:
	var data: Dictionary = super.get_handoff()
	data["surface_player"] = _player_pos - SURFACE_OFFSET
	if _bull != null:
		data["surface_bull"] = _bull.position - SURFACE_OFFSET
		data["surface_bull_facing"] = _bull.facing
		if _bull.anim != null:
			data["surface_bull_walk_time"] = _bull.anim.current_animation_position
	return data


func _on_setup() -> void:
	prebuild_requested.emit(NEXT_CHAMBER)      # the bear woods build behind the shaft while the cage is boarded and rises
	_beat = Beat.ARRIVE
	_player_pos = START_POS
	if handoff.has("lift_player"):            # walked in through the open doorway: exactly where the doorway showed him
		var lp: Vector3 = handoff["lift_player"]
		_player_pos = Vector3(clampf(lp.x, -1.2, 1.2), 0.0, maxf(lp.z, MOUTH_MIN_Z))
	_ground_y = 0.0
	_player_yaw = 0.0
	_apply_handoff_gaze(0.0, -0.04)           # first person, eyes level (keeps the gaze he had at the previous chamber's exit)
	if _bull == null:
		_bull = _build_bull(START_POS + Vector3(-1.2, 0.0, 4.0), 0.0)
	if handoff.has("lift_bull"):              # Inferno walked through ahead of him: keep him where he was, facing the way he faced
		_bull.position = handoff["lift_bull"]
		_bull.facing = float(handoff.get("lift_bull_facing", _bull.facing))
	if _bull != null:
		_bull.visible = true
	_loop = _loop_player(LOOP_SFX, -8.0)
	_on_beat_entered(Beat.ARRIVE)


func _on_beat_entered(b: int) -> void:
	if _hud:
		_hud.objective = ["Follow Inferno onto the lift", "", "", "", "Head out into the wood", ""][clampi(b, 0, 5)]
	match b:
		Beat.ARRIVE:
			# he walks in through the DOORWAY (centre of the walkway-side opening), never through the bars, and waits by the lever
			_start_show([
				{"do": "call", "fn": func() -> void: _begin_carry_line("vo_bull_lift1")},
				{"do": "walk", "to": Vector3(0.0, 0.0, -3.4), "speed": 3.0},
				{"do": "walk", "to": Vector3(0.0, 0.0, -1.0), "speed": 2.4},
				{"do": "walk", "to": CAGE_STAND_BULL, "speed": 2.0},
				{"do": "face", "at": Vector3(0.0, 0.0, -4.0)}])
		Beat.LEVER:
			# both aboard: the walkway gate drops shut behind them, Inferno turns to the lever on the cage wall and pulls it. He never
			# leaves the cage. Not control-locking (one motion): Lil Blunt keeps the rifle and can look around.
			_bull_on_cage = true
			_gate_in_goal = 0.0
			_sfx("ep2_lift_start")
			_start_show([
				{"do": "call", "fn": func() -> void: look_toward(get_lever_position() + Vector3(0.0, 0.1, 0.0), 2.6)},
				{"do": "face", "at": LEVER_POS + Vector3(0.0, 0.0, 0.0)},
				{"do": "reach", "at": LEVER_POS + Vector3(0.12, 0.2, 0.0), "ramp": 0.45, "hold": 0.3, "lean": 0.0},
				{"do": "call", "fn": _pull_lever},
				{"do": "wait", "t": 0.6},
				{"do": "release", "ramp": 0.45, "t": 0.4},
				{"do": "face", "at": Vector3(0.0, 0.0, 1.0)}])
		Beat.RISE:
			release_look()
			_rise_t = 0.0
			_bull_on_cage = true
			if _loop and not _loop.playing:
				_loop.play()
			_start_show([
				{"do": "face", "at": _player_pos},
				{"do": "until", "pred": func() -> bool: return _hold <= 0.0},
				FacilityShow._say("vo_bull_plan1", 0.25),
				FacilityShow._say("vo_bull_plan2", 0.25),
				FacilityShow._say("vo_bull_plan3", 0.3),
				FacilityShow._say("vo_lb_plan_reply", 0.3)])
		Beat.SURFACE:
			# This shaft brace lies at chest height across the only exit. Clear it before
			# the gate slides open; neither character may walk through solid timber.
			if _exit_crossbeam != null:
				_exit_crossbeam.visible = false
			_sfx("ep2_lift_arrive")
			if _loop:
				_loop.stop()
			camera_max = Vector3(4.1, 40.0, 16.0)
			_bull_on_cage = false
			_start_show([
				{"do": "walk", "to": Vector3(0.75, TOP_Y, 12.8), "speed": 2.8},          # he leads out along the walkway's right edge, clear of the view
				{"do": "face", "at": Vector3(0.0, TOP_Y, 0.0)}])


func _pull_lever() -> void:
	_lever_t = 0.0


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
	if _mouth_open and _running and _player_pos.z > CAVE_Z0 + 1.6:
		_set_mouth_open(false)          # he is in: the tunnel behind him is the dark tunnel again
	_surface_light()
	# lever animation: the iron handle swings from back (-35 deg) to forward (+35 deg) as Inferno pulls it
	if _lever_t >= 0.0 and _lever_t < 1.0 and _lever:
		_lever_t = minf(1.0, _lever_t + delta / 0.7)
		var arm: Node3D = _lever.get_child(0) as Node3D
		if arm:
			arm.rotation.x = deg_to_rad(-35.0 + 70.0 * _lever_t)
	# the walkway gate: raised (open) while they board, it drops shut when the lever beat starts
	_gate_in_k = move_toward(_gate_in_k, _gate_in_goal, delta / 0.6)
	if _gate_in:
		_gate_in.position.y = 3.3 * _gate_in_k
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
			if _player_pos.z >= EXIT_Z and _handoff_ok():
				_advance_to(Beat.DONE)
				_resolve({"next_chamber": NEXT_CHAMBER, "next_mode": "stealth"})
	if _cage:
		_cage.position.y = _cage_y
		if _gate:
			_gate.position.x = 2.3 * _gate_open             # slid a full gate-width aside along the cage face, clear of the doorway
	if _counter:
		_counter.position.y = TOP_Y - _cage_y + 0.6
	# the cage carries whoever stands on it
	if _beat >= Beat.RISE and _on_cage_xz(_player_pos):
		_set_ground(_cage_y)
	elif _beat >= Beat.SURFACE:
		_set_ground(TOP_Y)
	if _bull_on_cage and _bull != null:
		_bull.position.y = _cage_y


## THE CAGE IS SOLID (founder 2026-10-13: "why are they walking through the pole bars"): from outside, Lil Blunt can only get in
## through a doorway that is open (the walkway side while its gate is up, the surface side once the top gate has slid aside);
## from inside, only out through an open doorway. Only applies while he is on the cage's floor level.
func _cage_bars(old: Vector3, new: Vector3) -> Vector3:
	if absf(new.y - _cage_y) > 1.2 and absf(old.y - _cage_y) > 1.2:
		return new
	var outer: float = CAGE_HALF + BODY_R
	var inner: float = CAGE_HALF - BODY_R
	var door: float = CAGE_DOOR_HALF - BODY_R
	var walk_open: bool = _gate_in_k > 0.8
	var top_open: bool = _gate_open > 0.9
	var was_in: bool = absf(old.x) < CAGE_HALF and absf(old.z) < CAGE_HALF
	var q := new
	if was_in:
		var walk_ok: bool = walk_open and absf(q.x) <= door
		var top_ok: bool = top_open and absf(q.x) <= door
		if q.z < -inner and not walk_ok:
			q.z = -inner
		if q.z > inner and not top_ok:
			q.z = inner
		q.x = clampf(q.x, -door, door) if absf(q.z) > inner else clampf(q.x, -inner, inner)
		return q
	if absf(q.x) < outer and absf(q.z) < outer:
		var via_walk: bool = walk_open and old.z <= -CAGE_HALF and absf(q.x) <= door
		var via_top: bool = top_open and old.z >= CAGE_HALF and absf(q.x) <= door
		if via_walk or via_top:
			return q
		return Vector3(old.x, q.y, old.z)        # blocked by the bars: stay outside
	return q


func _on_cage_xz(p: Vector3) -> bool:
	return absf(p.x) < CAGE_HALF - 0.15 and absf(p.z) < CAGE_HALF - 0.15


func _player_on_cage() -> bool:
	return _on_cage_xz(_player_pos) and absf(_player_pos.y - _cage_y) < 0.6


# --- walking limits ---------------------------------------------------------------------------------------------------

func _collide(p: Vector3) -> Vector3:
	var q := _cage_bars(_player_pos, p)
	if _beat >= Beat.LEVER and _beat < Beat.SURFACE:
		# on the rising cage: the railings (the surface side is the gate, shut until the top)
		q.x = clampf(q.x, -(CAGE_HALF - 0.45), CAGE_HALF - 0.45)      # keep the eye off the cage's plank panels and bars
		q.z = clampf(q.z, -(CAGE_HALF - 0.45), CAGE_HALF - 0.45)
		return q
	if _beat >= Beat.SURFACE:
		if q.z > CAGE_HALF:
			q.x = clampf(q.x, -1.2, 1.2)       # along the walkway, between its rails, through the surface mouth
		else:
			q.x = clampf(q.x, -(CAGE_HALF - 0.3), CAGE_HALF - 0.3)
		q.z = clampf(q.z, -(CAGE_HALF - 0.3), 14.0)
		return q
	# ground floor: the tunnel then the shaft base
	if q.z < -SHAFT_HALF:
		q.x = clampf(q.x, -1.2, 1.2)        # between the bridge rails (a 7 m drop beyond them)
		q.z = maxf(q.z, MOUTH_MIN_Z if _mouth_open else CAVE_Z0 + 0.6)
	else:
		q.x = clampf(q.x, -(SHAFT_HALF - 0.5), SHAFT_HALF - 0.5)
		q.z = clampf(q.z, -SHAFT_HALF - 5.0, SHAFT_HALF - 0.6)
	return q


func _can_jump() -> bool:
	return true
