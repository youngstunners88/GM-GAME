class_name GoldTownChamber
extends Ep2Interlude
## THE GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; skills ep2-surface-to-town,
## ep2-gold-rush-town, ep2-sheriff-jake, ep2-quickdraw-duel). Bull has dropped Lil Blunt in the main street and ridden off to see
## his blonde lady friend. The town chamber takes over in the same street (one invisible cut: Ep2GoldTown builds the town and the
## desert at the same coordinates in both rooms) and plays the rest of the slice in first person, the Winchester in his hands:
##
##   STREET    walk to the CERTIFICATES office
##   OFFICE    The Sheriff (the founder's own character: weathered, long duster, star, a wisp of smoke) and Minister Mike Dean (the certificate book) behind the counter: the certificate is made out in your
##             name, can't be sold on or traded, bring your share and he stamps it (whitepaper-faithful, no invented numbers)
##   TO_BAR    cross the street to the SALOON
##   BAR       a whiskey, a quarter of a Bitcoin on the bar, the bartender's jaw drops, a stranger at the end of the bar noticed -
##             "Give me a bitcoin or I give you the map to the auction where they can get more intel." Lil Blunt won't. the Sheriff walks
##             in: he is the witness
##   SQUARE_UP out in the street, face him; the Sheriff stands to the side
##   DRAW      the rifle stays down until the Sheriff says DRAW (a seeded wait). Fire early = a foul, the Sheriff makes them redo it. Hit him first
##             = the map. Too slow = he shoots first: the screen drops, hearts restored, the Sheriff sets it up again (retry, never a death)
##   WON       the Sheriff hands him the map; Bull comes walking up the street (his reaction is not locked: no line yet)
##   DONE      TO BE CONTINUED
## Never in this room: the banned Episode 2 protocol (ep2-fort-knox-arc rule 4), a second health system, a wallet or contract address.

enum Beat { STREET, OFFICE, TO_BAR, BAR, SQUARE_UP, DRAW, WON, DONE }

const SHERIFF_MODEL := "res://src/episode2/assets/town/sheriff.glb"          # the founder's own Sheriff (Drive 2026-10-14): weathered, bearded, long coat, pipe - baked for the pack
const MINISTER_MODEL := "res://src/episode2/assets/town/minister.glb"      # Minister Mike Dean: the founder's robot-headed minister (Drive 2026-10-14), baked for the pack
const COWBOY_MODEL := "res://src/episode2/assets/town/cowboy.glb"        # the stranger: a HUMAN cowboy (child meshes "Idle" and "Draw")
const BARTENDER_MODEL := "res://src/episode2/assets/town/bartender.glb"  # the barman: a human too - the town has no bears
const COWBOY_HEIGHT := 1.84
## His gun hand in the Draw pose, as a fraction of his height (x right, y up, z forward; measured in Blender by prep_founder_town_models.py).
const COWBOY_HAND_DRAW := Vector3(-0.18, 0.75, 0.10)
const BARTENDER_HEIGHT := 1.76
const WHISKEY_MODEL := "res://src/episode2/assets/whiskey_glass.glb"
const COIN_MODEL := "res://src/episode2/assets/btc_coin.glb"
const SHERIFF_HEIGHT := 1.78
const MINISTER_HEIGHT := 1.65
const MINISTER_STEP := 0.5                               # the low wooden step he stands on behind the counter, so the counter does not hide him
## In each building's local frame (x along the front, -z inside).
## Where the cigarette sits on the Sheriff, as a fraction of his height (x right, y up, z forward).
const SHERIFF_MOUTH := Vector3(0.0, 0.9, 0.07)
const MINISTER_DESK := Vector3(0.6, 0.0, -5.7)          # Minister Mike Dean behind the certificate counter, the certificate book open
const SHERIFF_OFFICE_AT := Vector3(-2.3, 0.0, -2.9)     # the Sheriff by the stove, where he greets whoever walks in
const OFFICE_SPOT := Vector3(0.6, 0.0, -3.4)          # where Lil Blunt stands at the counter
const BAR_SPOT := Vector3(-0.6, 0.0, -7.7)            # at the saloon bar
const BARTENDER_AT := Vector3(-0.8, 0.0, -10.0)
const OPP_AT_BAR := Vector3(2.5, 0.0, -7.6)
const SHERIFF_SALOON := Vector3(1.4, 0.0, -2.2)           # just inside the saloon door
## The duel in the street (world).
const DUEL_MARK := Vector3(0.0, 0.0, 1417.0)
const OPP_MARK := Vector3(0.0, 0.0, 1432.0)
const WITNESS_MARK := Vector3(-5.4, 0.0, 1424.5)
const DRAW_WAIT_MIN := 1.8
const DRAW_WAIT_MAX := 4.2
const OPP_REACTION := 1.45                            # seconds from "Draw!" to his shot on the first try (the rifle must come up)
const OPP_REACTION_STEP := 0.3                        # ...a little more each time he wins (never a wall)
const OPP_HIT_R := 0.5

var _town_col: Dictionary = {}
var _sheriff: Ep2TownFolk = null
var _minister: Ep2TownFolk = null
var _sheriff_delay: float = 0.0
var _sheriff_goes: Array = []                            # where the Sheriff walks once his delay has run out
var _sheriff_smoke: CPUParticles3D = null
var _bartender: Ep2TownFolk = null
var _opp: Ep2TownFolk = null
var _revolver: Node3D = null
var _glass: Node3D = null
var _coin: Node3D = null
var _rng := RandomNumberGenerator.new()
var _draw_state: String = ""                          # "" | "wait" | "go" | "won" | "lost" | "foul"
var _draw_t: float = 0.0
var _draw_wait: float = 0.0
var _losses: int = 0
var _fouls: int = 0
var _got_map: bool = false
var _bull_arrived: bool = false
var _end_t: float = -1.0
var _duel_ready: bool = false
var _flash_t: float = 0.0
var _flash: OmniLight3D = null


func _init() -> void:
	title_card = "GOLDMINE"
	music_path = ""                                   # the ride's song carries on into the street (one motion)
	walk_speed = 3.0
	viewmodel_exposure = 0.8                          # desert daylight: the rifle's metal would read cream
	camera_min = Vector3(-300.0, 0.4, 1000.0)
	camera_max = Vector3(300.0, 80.0, 1800.0)


func _chamber_id() -> String:
	return "gold_town"


func _beat_label(b: int) -> String:
	return Beat.keys()[clampi(b, 0, Beat.size() - 1)]


# --- the set ----------------------------------------------------------------------------------------------------------

func _build_room() -> void:
	for s in _build_steps():
		(s as Callable).call()


func _build_steps() -> Array:
	return [_step_light, _step_ground, _step_town, _step_desert, _step_people]


func _warm_views() -> Array:
	var eye: Vector3 = Ep2GoldTown.DROP_POINT + Vector3(-2.0, 1.55, 0.0)
	return [{"eye": eye, "yaw": 0.0, "pitch": -0.03}, {"eye": eye, "yaw": -1.4, "pitch": -0.03}, {"eye": eye, "yaw": 1.4, "pitch": -0.03},
		{"eye": eye, "yaw": PI, "pitch": -0.03}, {"eye": Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 1.55, -2.0)), "yaw": -PI * 0.5, "pitch": 0.0},
		{"eye": Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.0, 1.55, -3.0)), "yaw": PI * 0.5, "pitch": 0.0}]


func _step_light() -> void:
	var env := Environment.new()
	_env_node.environment = env
	Ep2GoldTown.apply_desert_grade(env, _sun, 1.0)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func _step_ground() -> void:
	var dg := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400.0, 1300.0)
	dg.mesh = pm
	dg.material_override = Ep2GoldTown.desert_ground_mat()
	dg.position = Vector3(0.0, -0.012, 1450.0)
	dg.name = "DesertFloor"
	_visuals.add_child(dg)


func _step_town() -> void:
	_town_col = Ep2GoldTown.build(_visuals, true)
	# the counter and the bar are solid (Lil Blunt stands at them, the sheriff and the barman behind)
	var walls: Array = _town_col.get("walls", [])
	for seg in [["Bldg_Certificates", Vector3(-1.45, 0, -4.2), Vector3(2.65, 0, -4.2)], ["Bldg_Saloon", Vector3(-5.1, 0, -8.55), Vector3(3.1, 0, -8.55)]]:
		var a: Vector3 = Ep2GoldTown.local_to_world(str(seg[0]), seg[1])
		var b: Vector3 = Ep2GoldTown.local_to_world(str(seg[0]), seg[2])
		walls.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	_town_col["walls"] = walls


func _step_desert() -> void:
	var m: Array = Ep2GoldTown.desert_meshes()
	Ep2GoldTown.build_desert(_visuals, WoodsQuadChamber.RIDE_TRAIL, WoodsQuadChamber.FOREST_END_Z, WoodsQuadChamber.WORLD_END_Z, m[0], m[1],
		Ep2GoldTown.scrub_mat(), Ep2GoldTown.desert_rock_mat(), Ep2GoldTown.TOWN_Z - 260.0)


func _step_people() -> void:
	_build_sheriff()
	_bartender = Ep2TownFolk.new()
	_bartender.name = "Bartender"
	_visuals.add_child(_bartender)
	_bartender.setup(BARTENDER_MODEL, BARTENDER_HEIGHT, Color(0.85, 0.82, 0.74))
	_bartender.position = Ep2GoldTown.local_to_world("Bldg_Saloon", BARTENDER_AT)
	_face_folk(_bartender, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT))
	_opp = Ep2TownFolk.new()
	_opp.name = "Stranger"
	_visuals.add_child(_opp)
	_opp.setup(COWBOY_MODEL, COWBOY_HEIGHT, Color(0.2, 0.17, 0.15), false)
	_opp.position = Ep2GoldTown.local_to_world("Bldg_Saloon", OPP_AT_BAR)
	_face_folk(_opp, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT + Vector3(0.0, 0.0, -1.5)))
	# his revolver: in the holster (hidden) until he draws, then in his gun hand
	_revolver = _make_revolver()
	_opp.add_child(_revolver)
	_revolver.visible = false
	_glass = _prop(WHISKEY_MODEL, 0.11)
	_coin = _prop(COIN_MODEL, 0.06)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.45)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_visuals.add_child(_flash)
	if _bull == null:
		_bull = _build_bull(Ep2GoldTown.door_world("Bldg_B", 0.8), PI * 0.5)
		_bull.visible = false


## The Sheriff: the founder's own model (Drive 2026-10-14), arms lowered out of the T-pose, grey beard, star, pipe - with a
## thin curl of smoke over his lip. Beside him stands Minister Mike Dean, the founder's robot-headed minister. Without the model a plain stand-in keeps the beats playable.
func _build_sheriff() -> void:
	_sheriff = Ep2TownFolk.new()
	_sheriff.name = "Sheriff"
	_visuals.add_child(_sheriff)
	_sheriff.setup(SHERIFF_MODEL, SHERIFF_HEIGHT, Color(0.42, 0.30, 0.18))
	_sheriff_smoke = _particles(18, 2.6, Color(0.86, 0.86, 0.84, 0.33), 0.06)
	_sheriff_smoke.name = "CigSmoke"
	_sheriff_smoke.position = SHERIFF_MOUTH * SHERIFF_HEIGHT
	_sheriff_smoke.direction = Vector3.UP
	_sheriff_smoke.spread = 12.0
	_sheriff_smoke.initial_velocity_min = 0.05
	_sheriff_smoke.initial_velocity_max = 0.12
	_sheriff_smoke.gravity = Vector3(0.02, 0.06, 0.0)
	_sheriff_smoke.scale_amount_min = 0.6
	_sheriff_smoke.scale_amount_max = 2.6
	_sheriff.add_child(_sheriff_smoke)
	_sheriff.position = Ep2GoldTown.local_to_world("Bldg_Certificates", SHERIFF_OFFICE_AT)
	_face_folk(_sheriff, Ep2GoldTown.local_to_world("Bldg_Certificates", OFFICE_SPOT))
	_minister = Ep2TownFolk.new()
	_minister.name = "MinisterMikeDean"
	_visuals.add_child(_minister)
	_minister.setup(MINISTER_MODEL, MINISTER_HEIGHT, Color(0.1, 0.1, 0.12))
	_minister.position = Ep2GoldTown.local_to_world("Bldg_Certificates", MINISTER_DESK) + Vector3(0.0, MINISTER_STEP, 0.0)
	var step := MeshInstance3D.new()
	step.name = "MinisterStep"
	var box := BoxMesh.new()
	box.size = Vector3(1.1, MINISTER_STEP, 0.9)
	step.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.11)
	wood.roughness = 0.9
	step.material_override = wood
	step.position = _minister.position - Vector3(0.0, MINISTER_STEP * 0.5, 0.0)
	_visuals.add_child(step)
	_face_folk(_minister, Ep2GoldTown.local_to_world("Bldg_Certificates", OFFICE_SPOT))


static func _aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var bx: AABB = (n.global_transform.affine_inverse() * m.global_transform) * m.mesh.get_aabb() if n.is_inside_tree() else _local_xf(n, m) * m.mesh.get_aabb()
		out = bx if first else out.merge(bx)
		first = false
	return out


static func _local_xf(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t





func _make_revolver() -> Node3D:
	var g := Node3D.new()
	g.name = "Revolver"
	var steel := _plain(Color(0.22, 0.22, 0.24), 0.35, 0.85)
	var grip := _plain(Color(0.35, 0.22, 0.12), 0.7)
	_box(Vector3(0.03, 0.03, 0.2), Vector3(0.0, 0.0, 0.1), steel, g)
	_cyl(0.022, 0.022, 0.045, Vector3(0.0, -0.006, 0.0), steel, g).rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var gp := _box(Vector3(0.028, 0.1, 0.04), Vector3(0.0, -0.06, -0.04), grip, g)
	gp.rotation = Vector3(-0.35, 0.0, 0.0)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, 0.21)
	g.add_child(muzzle)
	return g


func _prop(path: String, size: float) -> Node3D:
	var n := Node3D.new()
	_visuals.add_child(n)
	n.visible = false
	if ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		n.add_child(m)
		var bx: AABB = _aabb_of(m)
		var s: float = size / maxf(maxf(bx.size.x, bx.size.y), maxf(bx.size.z, 0.001))
		m.scale = Vector3.ONE * s
		m.position = Vector3(-(bx.position.x + bx.size.x * 0.5) * s, -bx.position.y * s, -(bx.position.z + bx.size.z * 0.5) * s)
	else:
		_cyl(size * 0.4, size * 0.35, size, Vector3(0.0, size * 0.5, 0.0), _plain(Color(0.8, 0.55, 0.2), 0.2, 0.6), n)
	return n


static func _yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


func _face_folk(a: Ep2TownFolk, p: Vector3) -> void:
	a.face_point(p)
	a.rotation.y = a.facing


# --- setup + beats -----------------------------------------------------------------------------------------------------

func _on_setup() -> void:
	_player_pos = handoff.get("pos", Ep2GoldTown.DROP_POINT + Vector3(-2.2, 0.0, 0.6))
	_player_pos.y = 0.0
	_ground_y = 0.0
	_apply_handoff_gaze(0.0, -0.03, PI)
	_player_yaw = _look_yaw
	_rng.seed = 1886
	if _hud:
		_hud.show_health = false
	if _vm != null:
		_vm.set_world_shadows(false)
		_vm.set_own_light(WoodsQuadChamber.VM_KEY_ENERGY, _sun)
	_advance_to(Beat.STREET)


func _on_beat_entered(b: int) -> void:
	match b:
		Beat.STREET:
			if _hud:
				_hud.objective = "Go to the CERTIFICATES office. Get the sheriff to sort you a certificate."
		Beat.OFFICE:
			if _hud:
				_hud.objective = ""
			look_toward(_sheriff.position + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.6)
			_sheriff_look_at_player()
			_start_show([
				FacilityShow._say("vo_sheriff_1", 0.35),
				FacilityShow._say("vo_lb_cert1", 0.25),
				FacilityShow._say("vo_sheriff_2", 0.3),
				{"do": "call", "fn": func() -> void: look_toward(_minister.position + Vector3(0.0, MINISTER_HEIGHT * 0.85, 0.0), 2.4)},
				FacilityShow._say("vo_minister_1", 0.3),
				{"do": "call", "fn": func() -> void: look_toward(_sheriff.position + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.4)},
				FacilityShow._say("vo_sheriff_3", 0.3),
				{"do": "call", "fn": release_look}], true)
		Beat.TO_BAR:
			if _hud:
				_hud.objective = "Cross the street to the SALOON."
			# the sheriff finishes his smoke at the counter, then strolls over behind you (he has a feeling about that saloon)
			_sheriff_delay = 6.0
			_sheriff_goes = [Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 0.0, -2.0)), Ep2GoldTown.door_world("Bldg_Certificates", 1.6),
				Ep2GoldTown.door_world("Bldg_Saloon", 2.2)]
		Beat.BAR:
			if _hud:
				_hud.objective = ""
			var bar_top: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(-0.6, 1.2, -8.7))
			look_toward(_bartender.position + Vector3(0.0, 1.7, 0.0), 2.6)
			_start_show([
				FacilityShow._say("vo_bar_1", 0.3),
				FacilityShow._say("vo_lb_bar1", 0.2),
				{"do": "call", "fn": func() -> void: _place(_glass, bar_top)},
				{"do": "wait", "t": 0.6},
				FacilityShow._say("vo_lb_bar2", 0.2),
				{"do": "call", "fn": func() -> void: _place(_coin, bar_top + Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.35, 0, 0)) - Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3.ZERO))},
				FacilityShow._say("vo_bar_2", 0.3),
				{"do": "call", "fn": func() -> void: look_toward(_opp.position + Vector3(0.0, 1.9, 0.0), 2.4)},
				{"do": "call", "fn": func() -> void: _face_folk(_opp, _player_pos)},
				FacilityShow._say("vo_opp_1", 0.3),
				FacilityShow._say("vo_opp_2", 0.35),
				FacilityShow._say("vo_lb_draw1", 0.3),
				FacilityShow._say("vo_opp_3", 0.4),
				{"do": "call", "fn": _sheriff_enters_saloon},
				{"do": "call", "fn": func() -> void: look_toward(Ep2GoldTown.local_to_world("Bldg_Saloon", SHERIFF_SALOON) + Vector3(0.0, SHERIFF_HEIGHT * 0.9, 0.0), 2.0)},
				{"do": "wait", "t": 2.6},
				FacilityShow._say("vo_sheriff_witness", 0.3),
				{"do": "call", "fn": release_look}], true)
		Beat.SQUARE_UP:
			if _hud:
				_hud.objective = "Step out into the street and face him."
			var sd: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 1.5)
			_opp.walk_path([Ep2GoldTown.door_world("Bldg_Saloon", -1.0), sd, Vector3(3.0, 0.0, 1426.0), OPP_MARK], 1.5)
			_sheriff.walk_path([sd + Vector3(0.0, 0.0, 1.0), WITNESS_MARK], 1.4)
		Beat.DRAW:
			if _hud:
				_hud.objective = "Hands still till the sheriff says DRAW."
				_hud.show_health = true
			_start_round()
		Beat.WON:
			_got_map = true
			if _hud:
				_hud.objective = "THE AUCTION MAP is yours."
				_hud.toast("YOU GOT THE MAP TO THE AUCTION", 3.0)
			# he strolls out of the HOTEL (the blonde lady friend; nothing shown), hat and grin, and walks over
			_bull.visible = true
			_bull.position = Ep2GoldTown.door_world("Bldg_B", 0.8)
			_start_show([
				FacilityShow._say("vo_sheriff_win", 0.4),
				{"do": "wait", "t": 0.4}], false)
			_bull.walk_to(_player_pos + Vector3(1.4, 0.0, 2.6), 1.6)
		Beat.DONE:
			_resolve({"end_session": true, "to_be_continued": true, "got_map": _got_map, "draw_losses": _losses, "draw_fouls": _fouls})


func _show_finished() -> void:
	match _beat:
		Beat.OFFICE:
			_advance_to(Beat.TO_BAR)
		Beat.BAR:
			_advance_to(Beat.SQUARE_UP)


func _place(n: Node3D, p: Vector3) -> void:
	n.position = p
	n.visible = true


## The sheriff pushes in through the saloon doors (if Lil Blunt outran him, he is already at the door) and walks up to the bar.
func _sheriff_enters_saloon() -> void:
	var outside: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 1.2)
	if _sheriff.position.distance_to(outside) > 4.0:
		_sheriff.position = outside
	_sheriff.walk_path([Ep2GoldTown.door_world("Bldg_Saloon", -0.6), Ep2GoldTown.local_to_world("Bldg_Saloon", SHERIFF_SALOON)], 1.4)


func _sheriff_look_at_player() -> void:
	_sheriff.face_point(_player_pos)


func _tick(delta: float) -> void:
	_tick_people(delta)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		_flash.light_energy = 6.0 * _flash_t / 0.08
	match _beat:
		Beat.STREET:
			if _in_room("Bldg_Certificates", -1.4):
				_advance_to(Beat.OFFICE)
		Beat.TO_BAR:
			if _in_room("Bldg_Saloon", -5.5):
				_advance_to(Beat.BAR)
		Beat.SQUARE_UP:
			_duel_ready = _player_pos.distance_to(DUEL_MARK) < 2.0 and not _opp.is_walking() and not _sheriff.is_walking()
			if _duel_ready:
				_advance_to(Beat.DRAW)
		Beat.DRAW:
			_tick_draw(delta)
		Beat.WON:
			if not _bull_arrived and not _bull.is_walking():
				_bull_arrived = true
				_bull.face_point(_player_pos)
				_end_t = 3.0
			if _end_t >= 0.0 and not _show_active:
				_end_t -= delta
				if _end_t < 0.0:
					_advance_to(Beat.DONE)


## True when Lil Blunt is inside `piece` deeper than `depth` (local z, negative = inside).
func _in_room(piece: String, depth: float) -> bool:
	var e: Array = Ep2GoldTown.entry(piece)
	var lp: Vector3 = Ep2GoldTown.building_xform(e).affine_inverse() * _player_pos
	var fp: Array = Ep2GoldTown.FOOTPRINT[piece]
	return lp.z < depth and absf(lp.x) < float(fp[0]) * 0.5


## The cast: the Sheriff strolls where he is sent (after his delay) and turns to whoever he is talking to; the stranger walks and squares up.
func _tick_people(delta: float) -> void:
	if _sheriff_delay > 0.0:
		_sheriff_delay -= delta
		if _sheriff_delay <= 0.0 and not _sheriff_goes.is_empty():
			_sheriff.walk_path(_sheriff_goes, 1.35)
			_sheriff_goes = []
	if not _sheriff.is_walking():
		if _beat == Beat.DRAW:
			_sheriff.face_point((DUEL_MARK + OPP_MARK) * 0.5)
		elif _beat in [Beat.OFFICE, Beat.BAR, Beat.WON]:
			_sheriff_look_at_player()
	if _beat == Beat.SQUARE_UP and not _opp.is_walking():
		_opp.face_point(DUEL_MARK)
	_sheriff.step(delta)
	_minister.step(delta)
	_opp.step(delta)
	_bartender.step(delta)


# --- the draw ---------------------------------------------------------------------------------------------------------

func _start_round() -> void:
	_draw_state = "wait"
	_draw_t = 0.0
	_draw_wait = _rng.randf_range(DRAW_WAIT_MIN, DRAW_WAIT_MAX)
	_opp.position = OPP_MARK
	_face_folk(_opp, DUEL_MARK)
	_opp.set_pose("idle")
	_opp.dead = false
	_opp.rotation = Vector3(0.0, _opp.rotation.y, 0.0)
	_revolver.visible = false
	_sheriff.position = WITNESS_MARK
	look_toward(OPP_MARK + Vector3(0.0, 1.6, 0.0), 3.0)


## Seconds the stranger takes from "Draw!" to his shot this round.
func opp_reaction() -> float:
	return OPP_REACTION + OPP_REACTION_STEP * float(mini(_losses, 3))


func _tick_draw(delta: float) -> void:
	_draw_t += delta
	match _draw_state:
		"wait":
			if _draw_t > 0.6:
				release_look()
			if _draw_t >= _draw_wait and _hold <= 0.0:
				_draw_state = "go"
				_draw_t = 0.0
				_begin_carry_line("vo_sheriff_draw")
				_opp_draws()
				if _hud:
					_hud.objective = "DRAW!"
		"go":
			if _draw_t >= opp_reaction():
				_opp_fires()
		"won":
			if _draw_t > 0.8 and not _show_active:
				_advance_to(Beat.WON)
		"lost":
			if _hud:
				_hud.fade = clampf(_draw_t / 0.5, 0.0, 1.0) if _draw_t < 1.6 else clampf(1.0 - (_draw_t - 1.6) / 0.7, 0.0, 1.0)
			if _draw_t > 1.6 and _draw_state == "lost" and not _show_active and _hold <= 0.0:
				_restage()
				_begin_carry_line("vo_sheriff_lose")
				_draw_state = "relost"
		"relost", "foul":
			if _hud and _draw_state == "relost":
				_hud.fade = clampf(1.0 - (_draw_t - 1.6) / 0.7, 0.0, 1.0)
			if _hold <= 0.0 and _draw_t > 2.4:
				if _hud:
					_hud.fade = 0.0
					_hud.objective = "Hands still till the sheriff says DRAW."
				_start_round()


func _restage() -> void:
	_player_pos = DUEL_MARK
	_look_yaw = _yaw_to(DUEL_MARK, OPP_MARK)
	_look_pitch = -0.02


## The rifle stays at low ready until the word.
func _viewmodel_lowered() -> bool:
	return _beat == Beat.DRAW and _draw_state in ["wait", "foul", "lost", "relost"]


## Feet stay planted in the duel: he may look and aim, not walk.
func _current_speed() -> float:
	return 0.0 if _beat == Beat.DRAW else super._current_speed()


## A shot before the word is a FOUL (the round is redone); after it, the round is real.
func shoot() -> bool:
	if _beat == Beat.DRAW and _draw_state == "wait" and has_player_control():
		_fouls += 1
		_draw_state = "foul"
		_draw_t = 0.0
		_begin_carry_line("vo_sheriff_foul")
		if _hud:
			_hud.objective = "FOUL - wait for the word."
		return false
	if _beat == Beat.DRAW and _draw_state != "go":
		return false
	return super.shoot()


func _on_player_shot() -> void:
	if _beat != Beat.DRAW or _draw_state != "go":
		return
	var eye: Vector3 = _camera.global_position if _camera != null else _player_pos + Vector3(0.0, eye_height, 0.0)
	var dir: Vector3 = -_camera.global_transform.basis.z if _camera != null else Vector3(sin(_look_yaw), 0.0, cos(_look_yaw))
	if aim_hits_opponent(eye, dir):
		_draw_state = "won"
		_draw_t = 0.0
		_opp.fall_dead()
		_revolver.visible = false
		if _hud:
			_hud.objective = ""


## True when a ray from `eye` along `dir` passes within OPP_HIT_R of the stranger's body (feet to hat).
func aim_hits_opponent(eye: Vector3, dir: Vector3) -> bool:
	var a: Vector3 = _opp.position + Vector3(0.0, 0.3, 0.0)
	var b: Vector3 = _opp.position + Vector3(0.0, _opp.height_m, 0.0)
	var d: Vector3 = dir.normalized()
	# closest points between the ray and the body's axis
	var u: Vector3 = b - a
	var w0: Vector3 = eye - a
	var aa: float = d.dot(d)
	var bb: float = d.dot(u)
	var cc: float = u.dot(u)
	var dd: float = d.dot(w0)
	var ee: float = u.dot(w0)
	var den: float = aa * cc - bb * bb
	var sc: float = 0.0
	var tc: float = 0.0
	if den > 1e-6:
		sc = (bb * ee - cc * dd) / den
		tc = clampf((aa * ee - bb * dd) / den, 0.0, 1.0)
	sc = maxf(sc, 0.0)
	return (eye + d * sc).distance_to(a + u * tc) < OPP_HIT_R


## The stranger's gun hand comes up with the revolver in it (the baked "Draw" arm pose + the prop at his hand).
func _opp_draws() -> void:
	_opp.set_pose("draw")
	_revolver.visible = true
	_revolver.position = COWBOY_HAND_DRAW * COWBOY_HEIGHT
	_revolver.rotation = Vector3(0.0, 0.0, 0.0)
	_opp.kick()


func _opp_fires() -> void:
	_opp.kick()
	_losses += 1
	_draw_state = "lost"
	_draw_t = 0.0
	_sfx("ep2_revolver_blast_1")
	_sfx("damage")
	_flash.position = _revolver.global_position if _revolver.is_inside_tree() else _opp.position + Vector3(0.3, 1.2, 0.4)
	_flash_t = 0.08
	if _hud:
		_hud.objective = ""


# --- state the tests read ----------------------------------------------------------------------------------------------

func get_draw_state() -> String: return _draw_state
func get_draw_wait() -> float: return _draw_wait
func get_losses() -> int: return _losses
func get_fouls() -> int: return _fouls
func has_map() -> bool: return _got_map
func get_sheriff() -> Ep2TownFolk: return _sheriff
func get_minister() -> Ep2TownFolk: return _minister
func get_opponent() -> Ep2TownFolk: return _opp
func get_bartender() -> Ep2TownFolk: return _bartender
func is_bull_here() -> bool: return _bull != null and _bull.visible
func is_coin_on_bar() -> bool: return _coin != null and _coin.visible
func is_glass_on_bar() -> bool: return _glass != null and _glass.visible


## Hearts are restored after a lost draw (a retry, never a death); the duel is the only place the HUD shows them.
func _shows_health() -> bool:
	return _beat == Beat.DRAW


## The street and the two rooms: the building walls (door gaps open into the office and the saloon), the counter, the bar, the props.
func _collide(p: Vector3) -> Vector3:
	var c: Vector2 = Ep2GoldTown.collide(Vector2(p.x, p.z), 0.3, _town_col.get("walls", []), _town_col.get("props", []))
	return Vector3(clampf(c.x, -40.0, 40.0), p.y, clampf(c.y, Ep2GoldTown.TOWN_Z - 60.0, Ep2GoldTown.TOWN_Z + 95.0))
