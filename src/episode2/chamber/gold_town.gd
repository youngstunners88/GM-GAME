class_name GoldTownChamber
extends Ep2Interlude
## THE GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; skills ep2-surface-to-town,
## ep2-gold-rush-town, ep2-sheriff-jake, ep2-quickdraw-duel). Bull has dropped Lil Blunt in the main street and ridden off to see
## his blonde lady friend. The town chamber takes over in the same street (one invisible cut: Ep2GoldTown builds the town and the
## desert at the same coordinates in both rooms) and plays the rest of the slice in first person, the Winchester in his hands:
##
##   STREET    walk to the CERTIFICATES office
##   OFFICE    Sheriff Jake (curls, cigarette, green jakeX hatband, star) behind the counter: the certificate is made out in your
##             name, can't be sold on or traded, bring your share and he stamps it (whitepaper-faithful, no invented numbers)
##   TO_BAR    cross the street to the SALOON
##   BAR       a whiskey, a quarter of a Bitcoin on the bar, the bartender's jaw drops, a stranger at the end of the bar noticed -
##             "Give me a bitcoin or I give you the map to the auction where they can get more intel." Lil Blunt won't. Jake walks
##             in: he is the witness
##   SQUARE_UP out in the street, face him; Jake stands to the side
##   DRAW      the rifle stays down until Jake says DRAW (a seeded wait). Fire early = a foul, Jake makes them redo it. Hit him first
##             = the map. Too slow = he shoots first: the screen drops, hearts restored, Jake sets it up again (retry, never a death)
##   WON       Jake hands him the map; Bull comes walking up the street (his reaction is not locked: no line yet)
##   DONE      TO BE CONTINUED
## Never in this room: the banned Episode 2 protocol (ep2-fort-knox-arc rule 4), a second health system, a wallet or contract address.

enum Beat { STREET, OFFICE, TO_BAR, BAR, SQUARE_UP, DRAW, WON, DONE }

const JAKE_MODEL := "res://src/episode2/assets/town/sheriff_jake.glb"
const WHISKEY_MODEL := "res://src/episode2/assets/whiskey_glass.glb"
const COIN_MODEL := "res://src/episode2/assets/btc_coin.glb"
const JAKE_HEIGHT := 1.86
## In each building's local frame (x along the front, -z inside).
const JAKE_DESK := Vector3(0.6, 0.0, -5.7)           # behind the certificate counter
const OFFICE_SPOT := Vector3(0.6, 0.0, -3.4)          # where Lil Blunt stands at the counter
const BAR_SPOT := Vector3(-0.6, 0.0, -7.7)            # at the saloon bar
const BARTENDER_AT := Vector3(-0.8, 0.0, -10.0)
const OPP_AT_BAR := Vector3(2.5, 0.0, -7.6)
const JAKE_SALOON := Vector3(1.4, 0.0, -2.2)           # just inside the saloon door
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
var _jake: Node3D = null
var _jake_path: Array = []
var _jake_face: float = 0.0
var _jake_walk_t: float = 0.0
var _jake_smoke: CPUParticles3D = null
var _bartender: Ep2Actor = null
var _opp: Ep2Actor = null
var _opp_path: Array = []
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
	_build_jake()
	_bartender = Ep2BearKit.make_bear(_visuals, Ep2GoldTown.local_to_world("Bldg_Saloon", BARTENDER_AT), 2.0)
	_bartender.name = "Bartender"
	_face_actor(_bartender, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT))
	_apron(_bartender)
	_opp = Ep2BearKit.make_bear(_visuals, Ep2GoldTown.local_to_world("Bldg_Saloon", OPP_AT_BAR), 2.25)
	_opp.name = "Stranger"
	_face_actor(_opp, Ep2GoldTown.local_to_world("Bldg_Saloon", BAR_SPOT + Vector3(0.0, 0.0, -1.5)))
	_revolver = _make_revolver()
	var hold: Node3D = _opp.holder("RightHand")
	if hold != null:
		hold.add_child(_revolver)
		_revolver.position = Vector3(0.0, 0.06, 0.04)
		_revolver.rotation = Vector3(0.0, 0.0, -PI * 0.5)
	else:
		_opp.add_child(_revolver)
		_revolver.position = Vector3(0.35, 1.0, 0.1)
	_hat(_opp, Color(0.13, 0.10, 0.08))
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


## Sheriff Jake: the Tripo model (static) if it is in the build, scaled to JAKE_HEIGHT, with a lit cigarette in his mouth trailing smoke.
## Without the model a plain stand-in figure keeps the beats playable (the test does not depend on the art).
func _build_jake() -> void:
	_jake = Node3D.new()
	_jake.name = "SheriffJake"
	_visuals.add_child(_jake)
	var body: Node3D = null
	if ResourceLoader.exists(JAKE_MODEL):
		body = (load(JAKE_MODEL) as PackedScene).instantiate() as Node3D
	if body != null:
		_jake.add_child(body)
		var aabb: AABB = _aabb_of(body)
		var s: float = JAKE_HEIGHT / maxf(aabb.size.y, 0.01)
		body.scale = Vector3.ONE * s
		body.position = Vector3(-(aabb.position.x + aabb.size.x * 0.5) * s, -aabb.position.y * s, -(aabb.position.z + aabb.size.z * 0.5) * s)
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		var coat := _plain(Color(0.30, 0.24, 0.18))
		_cyl(0.24, 0.30, 1.35, Vector3(0.0, 0.68, 0.0), coat, _jake)
		_sphere(0.15, Vector3(0.0, 1.55, 0.0), _plain(Color(0.86, 0.68, 0.55)), _jake)
		_hat(_jake, Color(0.42, 0.30, 0.18), 1.68)
		_box(Vector3(0.08, 0.08, 0.02), Vector3(-0.12, 1.2, 0.27), _plain(Color(0.95, 0.80, 0.35), 0.3, 0.9), _jake)   # the star
	# the cigarette (skill ep2-sheriff-jake: always in his mouth), its ember and a thin curl of smoke
	var cig := Node3D.new()
	cig.name = "Cigarette"
	cig.position = Vector3(0.04, JAKE_HEIGHT * 0.865, 0.13)
	cig.rotation = Vector3(0.25, 0.35, 0.0)
	_jake.add_child(cig)
	var stick := _cyl(0.006, 0.006, 0.075, Vector3.ZERO, _plain(Color(0.95, 0.93, 0.88), 0.7), cig)
	stick.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	stick.position = Vector3(0.0, 0.0, 0.035)
	_sphere(0.008, Vector3(0.0, 0.0, 0.074), _glow(Color(1.0, 0.42, 0.12), 3.5), cig)
	_jake_smoke = _particles(18, 2.6, Color(0.86, 0.86, 0.84, 0.33), 0.07)
	_jake_smoke.name = "CigSmoke"
	_jake_smoke.position = Vector3(0.0, 0.0, 0.076)
	_jake_smoke.direction = Vector3.UP
	_jake_smoke.spread = 12.0
	_jake_smoke.initial_velocity_min = 0.05
	_jake_smoke.initial_velocity_max = 0.12
	_jake_smoke.gravity = Vector3(0.02, 0.06, 0.0)
	_jake_smoke.scale_amount_min = 0.6
	_jake_smoke.scale_amount_max = 2.6
	cig.add_child(_jake_smoke)
	_jake.position = Ep2GoldTown.local_to_world("Bldg_Certificates", JAKE_DESK)
	_jake_face = _yaw_to(_jake.position, Ep2GoldTown.local_to_world("Bldg_Certificates", OFFICE_SPOT))
	_jake.rotation.y = _jake_face


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


func _hat(parent: Node3D, c: Color, y: float = -1.0) -> void:
	var holder: Node3D = parent
	var at := Vector3(0.0, y, 0.0)
	if parent is Ep2Actor and (parent as Ep2Actor).holder("Head") != null:
		holder = (parent as Ep2Actor).holder("Head")
		at = Vector3(0.0, 0.2, 0.0)
	var m := _plain(c, 0.9)
	_cyl(0.30, 0.30, 0.025, at, m, holder, 18)
	_cyl(0.15, 0.17, 0.17, at + Vector3(0.0, 0.09, 0.0), m, holder, 14)


func _apron(a: Ep2Actor) -> void:
	var sp: Node3D = a.holder("Spine") if a.holder("Spine") != null else a
	var ap := _box(Vector3(0.62, 0.8, 0.04), Vector3(0.0, -0.25, 0.3), _plain(Color(0.92, 0.90, 0.84), 0.95), sp)
	ap.name = "Apron"


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


func _face_actor(a: Ep2Actor, p: Vector3) -> void:
	a.facing = _yaw_to(a.position, p)
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
			var jake_eye: Vector3 = _jake.position + Vector3(0.0, JAKE_HEIGHT * 0.9, 0.0)
			look_toward(jake_eye, 2.6)
			_jake_look_at_player()
			_start_show([
				FacilityShow._say("vo_jake_1", 0.35),
				FacilityShow._say("vo_lb_cert1", 0.25),
				FacilityShow._say("vo_jake_2", 0.3),
				FacilityShow._say("vo_jake_3", 0.3),
				{"do": "call", "fn": release_look}], true)
		Beat.TO_BAR:
			if _hud:
				_hud.objective = "Cross the street to the SALOON."
			# the sheriff finishes his smoke at the counter, then strolls over behind you (he has a feeling about that saloon)
			_jake_path = [Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 0.0, -2.0)), Ep2GoldTown.door_world("Bldg_Certificates", 1.6),
				Ep2GoldTown.door_world("Bldg_Saloon", 2.2)]
			_jake_walk_t = -6.0
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
				{"do": "call", "fn": func() -> void: _face_actor(_opp, _player_pos)},
				FacilityShow._say("vo_opp_1", 0.3),
				FacilityShow._say("vo_opp_2", 0.35),
				FacilityShow._say("vo_lb_draw1", 0.3),
				FacilityShow._say("vo_opp_3", 0.4),
				{"do": "call", "fn": _jake_enters_saloon},
				{"do": "call", "fn": func() -> void: look_toward(Ep2GoldTown.local_to_world("Bldg_Saloon", JAKE_SALOON) + Vector3(0.0, JAKE_HEIGHT * 0.9, 0.0), 2.0)},
				{"do": "wait", "t": 2.6},
				FacilityShow._say("vo_jake_witness", 0.3),
				{"do": "call", "fn": release_look}], true)
		Beat.SQUARE_UP:
			if _hud:
				_hud.objective = "Step out into the street and face him."
			var sd: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 1.5)
			_opp_path = [Ep2GoldTown.door_world("Bldg_Saloon", -1.0), sd, Vector3(3.0, 0.0, 1426.0), OPP_MARK]
			_jake_path = [sd + Vector3(0.0, 0.0, 1.0), WITNESS_MARK]
			_jake_walk_t = 0.0
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
				FacilityShow._say("vo_jake_win", 0.4),
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
func _jake_enters_saloon() -> void:
	var outside: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 1.2)
	if _jake.position.distance_to(outside) > 4.0:
		_jake.position = outside
	_jake_path = [Ep2GoldTown.door_world("Bldg_Saloon", -0.6), Ep2GoldTown.local_to_world("Bldg_Saloon", JAKE_SALOON)]
	_jake_walk_t = 0.0


func _jake_look_at_player() -> void:
	_jake_face = _yaw_to(_jake.position, _player_pos)


func _tick(delta: float) -> void:
	_tick_jake(delta)
	_tick_opp(delta)
	if _bartender != null:
		_bartender.step(delta)
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
			_duel_ready = _player_pos.distance_to(DUEL_MARK) < 2.0 and _opp_path.is_empty() and _jake_path.is_empty()
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


## The sheriff walks his path (a gentle stride: his model is a statue, so the walk is a bob and a sway), and turns to whoever he is talking to.
func _tick_jake(delta: float) -> void:
	if _jake == null:
		return
	var walking: bool = false
	if not _jake_path.is_empty():
		_jake_walk_t += delta
		if _jake_walk_t > 0.0:
			var goal: Vector3 = _jake_path[0]
			var d: Vector3 = goal - _jake.position
			d.y = 0.0
			if d.length() < 0.08:
				_jake_path.pop_front()
			else:
				walking = true
				var stepv: Vector3 = d.normalized() * minf(d.length(), 1.35 * delta)
				_jake.position += stepv
				_jake_face = atan2(d.x, d.z)
	elif _beat == Beat.DRAW:
		_jake_face = _yaw_to(_jake.position, (DUEL_MARK + OPP_MARK) * 0.5)
	elif _beat in [Beat.OFFICE, Beat.BAR, Beat.WON]:
		_jake_look_at_player()
	_jake.rotation.y = lerp_angle(_jake.rotation.y, _jake_face, clampf(4.0 * delta, 0.0, 1.0))
	var body: Node3D = _jake.get_child(0) as Node3D
	if body != null:
		var ph: float = _elapsed * 7.0
		body.rotation.z = (sin(ph) * 0.035) if walking else sin(_elapsed * 1.3) * 0.006
		_jake.position.y = (absf(sin(ph)) * 0.035) if walking else 0.0


func _tick_opp(delta: float) -> void:
	if _opp == null:
		return
	if not _opp_path.is_empty() and not _opp.is_walking():
		var nxt: Vector3 = _opp_path.pop_front()
		_opp.walk_to(nxt, 1.5)
	if _opp_path.is_empty() and not _opp.is_walking() and _beat == Beat.SQUARE_UP:
		_opp.face_point(DUEL_MARK)
	_opp.step(delta)


# --- the draw ---------------------------------------------------------------------------------------------------------

func _start_round() -> void:
	_draw_state = "wait"
	_draw_t = 0.0
	_draw_wait = _rng.randf_range(DRAW_WAIT_MIN, DRAW_WAIT_MAX)
	_opp.position = OPP_MARK
	_face_actor(_opp, DUEL_MARK)
	Ep2BearKit.pose(_opp, "idle")
	_jake.position = WITNESS_MARK
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
				_begin_carry_line("vo_jake_draw")
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
				_begin_carry_line("vo_jake_lose")
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
		_begin_carry_line("vo_jake_foul")
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
		Ep2BearKit.pose(_opp, "dead")
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


func _opp_fires() -> void:
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
func get_jake() -> Node3D: return _jake
func get_opponent() -> Ep2Actor: return _opp
func get_bartender() -> Ep2Actor: return _bartender
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
