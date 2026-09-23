class_name RunnerView
extends Node3D
## Episode 2 runner — PRESENTATION layer.
##
## Draws the gold-mine descent from the reference art (artifacts/episode2-gold-mine/
## references/IMG_2492 + IMG_2479): parallel rails on timber trestles over a pit,
## one cart per rail rolling as a convoy, Lil Blunt riding and hopping between them,
## balaclava bear archers on scaffolds beside the track, boulders rolled down the
## rails, overhead ziplines, gold veins and lanterns in the rock.
##
## Separation of concerns: this node only READS the simulation (the parent
## RunnerGraybox) and listens to its signals. Nothing in the sim reads anything
## back from here, so every gameplay rule stays headless-testable and this file can
## be restyled freely without touching a single gate.
##
## Readability is the priority over spectacle: each hazard is announced by a
## glowing floor strip in its lane and a floating verb (JUMP / DUCK / HOP / SHOOT),
## colour-coded by the action that clears it. The founder's bar was "so that it's
## clear" what Lil Blunt must do.
##
## Web budget: everything repeated (sleepers, posts, rocks, gold, lanterns) is a
## MultiMesh; only a handful of real OmniLights exist and they leapfrog along the
## track; the only textured assets are two small Meshy GLBs.

const RIDER_SCENE := preload("res://src/episode2/assets/lil_blunt.glb")
const ARCHER_SCENE := preload("res://src/episode2/assets/bear_archer.glb")

# --- Layout constants (view-only; the sim owns every gameplay number) ---------
const TRACK_PAD := 60.0            # track drawn past the portal so the end isn't a cliff
const TIE_SPACING := 1.1
const POST_SPACING := 5.5
const PIT_DEPTH := 14.0            # trestle legs vanish into the dark below
const WALL_X := 11.0               # cave wall inner face
const ARCHER_X := 5.4              # scaffold distance from track centre (just past the outer cart)
const ARCHER_Y := 2.2
const ARROW_Y := 1.45              # head height — the duck line
const ARROW_LEAD := 22.0           # arrow is loosed this far before it reaches its z
const BOULDER_ROLL := 0.85         # boulders close at (1 + this) x run speed
const BOULDER_R := 1.35
const TELEGRAPH_RANGE := 42.0      # verb labels appear this far ahead
const RIDER_HEIGHT := 1.75         # hero scale: head, shoulders and pickaxe clear the rim
const RIDER_FLOOR := 0.1           # standing on the cart floor
const RIDER_YAW := 0.0             # Meshy faces +Z == away from camera; flip to PI if not
const HOP_ARC := 1.1               # peak height of a cart-to-cart hop
const CABLE_CLEARANCE := 1.55      # cable above the rider's hanging point

# --- Palette ------------------------------------------------------------------
const C_ROCK := Color(0.13, 0.10, 0.085)
const C_TIMBER := Color(0.36, 0.23, 0.12)
const C_TIMBER_DARK := Color(0.22, 0.14, 0.08)
const C_IRON := Color(0.30, 0.29, 0.30)
const C_GOLD := Color(1.0, 0.72, 0.18)
const C_LANTERN := Color(1.0, 0.62, 0.22)
const C_JUMP := Color(1.0, 0.82, 0.18)     # yellow — jump
const C_DUCK := Color(1.0, 0.22, 0.20)     # red — duck
const C_HOP := Color(1.0, 0.50, 0.10)      # orange — hop carts
const C_SHOOT := Color(0.35, 0.85, 1.0)    # cyan — shoot
const C_ZIP := Color(0.95, 0.85, 0.40)

var _sim: Node = null
var _world: Node3D = null          # rebuilt per track
var _carts: Array[Node3D] = []
var _cart_wheels: Array = []       # per cart: Array[Node3D]
var _rider: Node3D = null
var _rider_model: Node3D = null
var _hook: MeshInstance3D = null
var _camera: Camera3D = null
var _sparks: CPUParticles3D = null
var _lights: Array[OmniLight3D] = []
var _lantern_z: PackedFloat32Array = PackedFloat32Array()
var _archer_nodes: Dictionary = {}     # id -> Node3D
var _archer_fall: Dictionary = {}      # id -> seconds since down
var _arrow_nodes: Array = []           # parallel to sim obstacles (null for non-arrows)
var _boulder_nodes: Array = []
var _labels: Array = []                # [{"node": Label3D, "z": float, "strip": MeshInstance3D}]
var _zip_markers: Array = []           # [{"ring": MeshInstance3D, "z": float}]
var _tracer: MeshInstance3D = null
var _tracer_t: float = 0.0
var _flash: OmniLight3D = null
var _shake: float = 0.0
var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _prev_x: float = 0.0
var _hop_from_x: float = 0.0
var _hop_to_x: float = 0.0
var _last_lane: int = 1


# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

## Called by the sim's setup(). Tears down the previous track and builds this one.
func rebuild(sim: Node) -> void:
	_sim = sim
	_rng.seed = 20260923                # same track, same rocks — no shimmer between retries
	if _world and is_instance_valid(_world):
		_world.queue_free()
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_carts.clear()
	_cart_wheels.clear()
	_archer_nodes.clear()
	_archer_fall.clear()
	_arrow_nodes.clear()
	_boulder_nodes.clear()
	_labels.clear()
	_zip_markers.clear()
	_lights.clear()

	var length: float = float(_sim.get_chamber_z()) + TRACK_PAD
	_build_track(length)
	_build_cave(length)
	_build_lanterns(length)
	_build_carts()
	_build_rider()
	_build_archers()
	_build_hazards()
	_build_ziplines()
	_build_portal(float(_sim.get_chamber_z()))
	_build_camera()
	_build_fx()
	_connect_sim()
	_prev_x = float(_sim.get_cart_x())
	_hop_from_x = _prev_x
	_hop_to_x = _prev_x
	_last_lane = int(_sim.get_lane())

func _connect_sim() -> void:
	var pairs := {
		"obstacle_hit": _on_hit,
		"shot_fired": _on_shot,
		"archer_down": _on_archer_down,
		"zip_caught": _on_zip_caught,
		"zip_missed": _on_zip_missed,
	}
	for sig in pairs:
		var cb: Callable = pairs[sig]
		if _sim.has_signal(sig) and not _sim.is_connected(sig, cb):
			_sim.connect(sig, cb)

func _process(delta: float) -> void:
	if _sim == null or _world == null:
		return
	var dist: float = float(_sim.get_distance())
	_update_convoy(dist)
	_update_rider(dist, delta)
	_update_archers(dist, delta)
	_update_arrows(dist)
	_update_boulders(dist)
	_update_labels(dist)
	_update_lights(dist)
	_update_camera(dist, delta)
	_update_fx(delta)

# ------------------------------------------------------------------------------
# Materials + mesh helpers
# ------------------------------------------------------------------------------

func _mat(key: String, c: Color, emit: float = 0.0, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

func _glow_mat(key: String, c: Color, alpha: float) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

func _mesh_node(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else _world).add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _multi(mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_world.add_child(mmi)
	return mmi

## Low-poly faceted rock: a UV sphere pushed around by noise, flat-shaded. Built
## once per track and instanced, so it costs one mesh however many rocks there are.
## The sphere is generated with plain math on the CPU rather than read back from a
## PrimitiveMesh, so building it never depends on what the renderer keeps around.
func _rock_mesh(seed_val: int, jag: float) -> Mesh:
	const SEGS := 10
	const RINGS := 7
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 1.3
	var grid: Array[PackedVector3Array] = []
	for r in RINGS + 1:
		var phi: float = PI * float(r) / float(RINGS)
		var row := PackedVector3Array()
		for sgi in SEGS + 1:
			var theta: float = TAU * float(sgi % SEGS) / float(SEGS)   # wrap: seam verts identical
			var v := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			row.append(v * (1.0 + jag * noise.get_noise_3dv(v)))
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in RINGS:
		for sgi in SEGS:
			var a: Vector3 = grid[r][sgi]
			var b: Vector3 = grid[r][sgi + 1]
			var c: Vector3 = grid[r + 1][sgi]
			var d: Vector3 = grid[r + 1][sgi + 1]
			if r > 0:                          # skip degenerate triangles at the poles
				st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
			if r < RINGS - 1:
				st.add_vertex(b); st.add_vertex(d); st.add_vertex(c)
	st.generate_normals()                      # un-indexed, so normals come out flat
	return st.commit()

func _lane_xs() -> Array:
	return RunnerGraybox.LANE_X

## Archer data uses side -1 = screen-left, +1 = screen-right. The camera looks down
## +Z, so screen-left is world +X — hence the minus sign.
func _side_x(side: float, dist_from_centre: float) -> float:
	return -side * dist_from_centre

# ------------------------------------------------------------------------------
# Static world
# ------------------------------------------------------------------------------

func _build_track(length: float) -> void:
	var ties: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var beams: Array[Transform3D] = []
	for lx in _lane_xs():
		var x: float = float(lx)
		var z := -20.0
		while z < length:
			ties.append(Transform3D(Basis.IDENTITY, Vector3(x, -0.5, z)))
			z += TIE_SPACING
		for side in [-0.55, 0.55]:
			rails.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, length + 20.0)),
				Vector3(x + float(side), -0.38, (length - 20.0) * 0.5)))
		z = -20.0
		while z < length:
			for side in [-0.85, 0.85]:
				posts.append(Transform3D(Basis.IDENTITY, Vector3(x + float(side), -0.6 - PIT_DEPTH * 0.5, z)))
			z += POST_SPACING
	# Cross-beams tie the three trestles together — reads as one structure.
	var z2 := -20.0
	while z2 < length:
		beams.append(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.75, z2)))
		beams.append(Transform3D(Basis.IDENTITY, Vector3(0.0, -4.5, z2 + POST_SPACING * 0.5)))
		z2 += POST_SPACING
	_multi(_box(Vector3(2.0, 0.14, 0.34)), _mat("tie", C_TIMBER_DARK), ties)
	_multi(_box(Vector3(0.12, 0.14, 1.0)), _mat("rail", C_IRON, 0.0, 0.35, 0.8), rails)
	_multi(_box(Vector3(0.26, PIT_DEPTH, 0.26)), _mat("post", C_TIMBER), posts)
	_multi(_box(Vector3(7.8, 0.22, 0.28)), _mat("beam", C_TIMBER), beams)

func _build_cave(length: float) -> void:
	var rock := _rock_mesh(7, 0.32)
	var walls: Array[Transform3D] = []
	var golds: Array[Transform3D] = []
	var z := -30.0
	while z < length + 20.0:
		for side in [-1.0, 1.0]:
			# Wall: a stack of big rocks, jittered, from the pit up to the ceiling.
			for tier in 4:
				var s: float = _rng.randf_range(2.6, 4.6)
				var pos := Vector3(side * (WALL_X + _rng.randf_range(0.0, 3.5)),
					-6.0 + tier * 4.6 + _rng.randf_range(-1.0, 1.0), z + _rng.randf_range(-1.5, 1.5))
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 1.2, s))
				walls.append(Transform3D(b, pos))
			# Gold veins glinting on the inner face of the wall.
			for _g in 5:
				var gs: float = _rng.randf_range(0.05, 0.16)
				var gp := Vector3(side * (WALL_X - 1.4 + _rng.randf_range(-0.6, 0.6)),
					_rng.randf_range(-2.0, 9.0), z + _rng.randf_range(-2.0, 2.0))
				golds.append(Transform3D(Basis(Vector3(_rng.randf(), _rng.randf(), _rng.randf()).normalized(),
					_rng.randf() * TAU).scaled(Vector3(gs, gs * 1.6, gs)), gp))
		# Ceiling — the descent is enclosed, not an open canyon.
		var cs: float = _rng.randf_range(4.0, 6.5)
		walls.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(cs, cs * 0.7, cs)),
			Vector3(_rng.randf_range(-8.0, 8.0), 13.0 + _rng.randf_range(0.0, 2.0), z)))
		z += 5.0
	_multi(rock, _mat("rock", C_ROCK, 0.0, 0.95), walls)
	_multi(_rock_mesh(11, 0.45), _mat("gold", C_GOLD, 1.3, 0.25, 0.9), golds)

	# Faint warm floor far below — the pit has a bottom, lit by the mine's glow.
	var pit := _box(Vector3(WALL_X * 2.4, 0.2, length + 60.0))
	_mesh_node(pit, _mat("pit", Color(0.10, 0.06, 0.03)), Vector3(0.0, -PIT_DEPTH - 0.6, (length - 20.0) * 0.5))

func _build_lanterns(length: float) -> void:
	var lanterns: Array[Transform3D] = []
	var hangers: Array[Transform3D] = []
	_lantern_z = PackedFloat32Array()
	var z := 6.0
	var side := 1.0
	while z < length:
		var p := Vector3(side * 4.3, 2.4, z)
		lanterns.append(Transform3D(Basis.IDENTITY, p))
		hangers.append(Transform3D(Basis.IDENTITY, p + Vector3(0.0, 1.6, 0.0)))
		_lantern_z.append(z)
		z += 11.0
		side = -side
	_multi(_box(Vector3(0.32, 0.46, 0.32)), _mat("lantern", C_LANTERN, 4.0), lanterns)
	_multi(_box(Vector3(0.1, 3.0, 0.1)), _mat("hanger", C_TIMBER_DARK), hangers)
	# A small pool of real lights leapfrogs along the lanterns nearest the rider.
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = C_LANTERN
		l.light_energy = 3.2
		l.omni_range = 12.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		_world.add_child(l)
		_lights.append(l)

## Open wooden ore cart, built from parts: floor, four walls, iron corner bands,
## four wheels. Open-topped so Lil Blunt reads as standing IN it (the bpy
## minecart.glb is a closed box, which read as him poking out of a crate).
## Parametric and free, per the asset lock's "bpy/procedural for hard-surface".
func _make_cart() -> Node3D:
	var c := Node3D.new()
	var wood := _mat("cart_wood", Color(0.34, 0.21, 0.11), 0.0, 0.8)
	var wood_dark := _mat("cart_wood_dark", Color(0.20, 0.12, 0.06), 0.0, 0.9)
	var iron := _mat("cart_iron", Color(0.22, 0.21, 0.20), 0.0, 0.45, 0.85)
	const W := 1.7     # outer width
	const L := 2.1     # outer length
	const H := 1.0     # wall height
	const T := 0.09    # plank thickness
	const FLOOR_Y := 0.35
	_mesh_node(_box(Vector3(W, T, L)), wood_dark, Vector3(0, FLOOR_Y, 0), c)
	for sx in [-1.0, 1.0]:
		_mesh_node(_box(Vector3(T, H, L)), wood, Vector3(sx * (W - T) * 0.5, FLOOR_Y + H * 0.5, 0), c)
	for sz in [-1.0, 1.0]:
		_mesh_node(_box(Vector3(W, H, T)), wood, Vector3(0, FLOOR_Y + H * 0.5, sz * (L - T) * 0.5), c)
	# Iron: top rim band all round, and a vertical strap at each corner.
	for sx in [-1.0, 1.0]:
		_mesh_node(_box(Vector3(T * 1.6, T * 1.4, L + 0.04)), iron, Vector3(sx * (W - T) * 0.5, FLOOR_Y + H, 0), c)
	for sz in [-1.0, 1.0]:
		_mesh_node(_box(Vector3(W + 0.04, T * 1.4, T * 1.6)), iron, Vector3(0, FLOOR_Y + H, sz * (L - T) * 0.5), c)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh_node(_box(Vector3(0.13, H + 0.05, 0.13)), iron,
				Vector3(sx * (W * 0.5 - 0.02), FLOOR_Y + H * 0.5, sz * (L * 0.5 - 0.02)), c)
	var wheels: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-0.62, 0.62]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.3
			wm.bottom_radius = 0.3
			wm.height = 0.12
			wm.radial_segments = 12
			var w := _mesh_node(wm, iron, Vector3(sx * (W * 0.5 - 0.1), 0.2, sz * L * 0.5), c)
			w.rotation.z = PI * 0.5
			wheels.append(w)
	c.set_meta("wheels", wheels)
	return c

func _build_carts() -> void:
	for lx in _lane_xs():
		var c := _make_cart()
		c.position = Vector3(float(lx), -0.3, 0.0)
		_world.add_child(c)
		_carts.append(c)
		_cart_wheels.append(c.get_meta("wheels"))

func _build_rider() -> void:
	_rider = Node3D.new()
	_rider.name = "Rider"
	_world.add_child(_rider)
	_rider_model = RIDER_SCENE.instantiate()
	_rider_model.scale = Vector3.ONE * RIDER_HEIGHT
	_rider_model.rotation.y = RIDER_YAW
	_rider.add_child(_rider_model)
	# The axe hook: shown only while hanging from a cable.
	var hook := CylinderMesh.new()
	hook.top_radius = 0.05
	hook.bottom_radius = 0.05
	hook.height = CABLE_CLEARANCE - 0.2
	_hook = _mesh_node(hook, _mat("iron_bright", Color(0.7, 0.7, 0.72), 0.0, 0.3, 0.9),
		Vector3(0.15, RIDER_HEIGHT + (CABLE_CLEARANCE - 0.2) * 0.5, 0.0), _rider)
	_hook.visible = false

func _build_archers() -> void:
	var scaffold_posts: Array[Transform3D] = []
	var decks: Array[Transform3D] = []
	for a in _sim.get_archers():
		var side: float = float(a["side"])
		var z: float = float(a["z"])
		var x: float = _side_x(side, ARCHER_X)
		for dx in [-1.0, 1.0]:
			for dz in [-1.0, 1.0]:
				scaffold_posts.append(Transform3D(Basis.IDENTITY,
					Vector3(x + dx * 1.1, ARCHER_Y - 0.1 - (ARCHER_Y + PIT_DEPTH) * 0.5, z + dz * 1.0)))
		decks.append(Transform3D(Basis.IDENTITY, Vector3(x, ARCHER_Y - 0.1, z)))
		var bear: Node3D = ARCHER_SCENE.instantiate()
		bear.scale = Vector3.ONE * 2.6
		bear.position = Vector3(x, ARCHER_Y, z)
		# Face the track and slightly toward the oncoming convoy.
		var to_track := Vector3(-signf(x), 0.0, -0.55).normalized()
		bear.rotation.y = atan2(to_track.x, to_track.z)
		_world.add_child(bear)
		# Miner's headlamp, as in the reference art: makes each bear pop out of the
		# dark and tells the player where the next volley is coming from.
		var lamp := SphereMesh.new()
		lamp.radius = 0.06
		lamp.height = 0.12
		_mesh_node(lamp, _mat("headlamp", Color(1.0, 0.92, 0.6), 8.0), Vector3(0.0, 1.07, 0.16), bear)
		var ll := OmniLight3D.new()
		ll.light_color = Color(1.0, 0.8, 0.5)
		ll.light_energy = 1.6
		ll.omni_range = 4.5
		ll.position = Vector3(0.0, 1.2, 0.5)
		bear.add_child(ll)
		_mesh_node(_box(Vector3(0.3, 0.42, 0.3)), _mat("lantern", C_LANTERN, 4.0),
			Vector3(x + signf(x) * 1.0, ARCHER_Y + 0.3, z + 0.9))
		_archer_nodes[str(a["id"])] = bear
	if scaffold_posts.size() > 0:
		_multi(_box(Vector3(0.24, ARCHER_Y + PIT_DEPTH, 0.24)), _mat("post", C_TIMBER), scaffold_posts)
		_multi(_box(Vector3(2.8, 0.22, 2.6)), _mat("beam", C_TIMBER), decks)

func _arrow_mesh_node() -> Node3D:
	var root := Node3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.06
	shaft.bottom_radius = 0.06
	shaft.height = 1.9
	var s := _mesh_node(shaft, _mat("arrow_shaft", Color(0.85, 0.70, 0.45), 0.6), Vector3.ZERO, root)
	s.rotation.z = PI * 0.5
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.14
	head.height = 0.38
	var h := _mesh_node(head, _mat("arrow_head", C_DUCK, 3.0, 0.4, 0.6), Vector3(1.1, 0.0, 0.0), root)
	h.rotation.z = -PI * 0.5
	var fletch := _mesh_node(_box(Vector3(0.28, 0.2, 0.02)), _mat("fletch", Color(0.85, 0.15, 0.12), 0.6),
		Vector3(-0.7, 0.0, 0.0), root)
	fletch.rotation.x = 0.4
	# Streak behind the arrow so its flight line is readable at speed.
	_mesh_node(_box(Vector3(2.6, 0.05, 0.05)), _glow_mat("arrow_trail", C_DUCK, 0.45), Vector3(-2.2, 0.0, 0.0), root)
	_world.add_child(root)
	return root

func _build_hazards() -> void:
	var boulder_mesh := _rock_mesh(23, 0.28)
	var crate_mat := _mat("crate", Color(0.55, 0.36, 0.18))
	var obs_all: Array = _sim.get_obstacles()
	for oi in obs_all.size():
		var o: Dictionary = obs_all[oi]
		var lane: int = clampi(int(o["lane"]), 0, _lane_xs().size() - 1)
		var x: float = float(_lane_xs()[lane])
		var z: float = float(o["z"])
		var t: String = str(o["type"])
		var arrow_node: Node3D = null
		var boulder_node: Node3D = null
		match t:
			"arrow":
				arrow_node = _arrow_mesh_node()
				arrow_node.visible = false
				_add_telegraph(x, z, C_DUCK, "DUCK" if not _sim.can_shoot() else "DUCK / SHOOT", oi)
			"boulder":
				boulder_node = _mesh_node(boulder_mesh, _mat("boulder", Color(0.66, 0.60, 0.52), 0.0, 0.85),
					Vector3(x, BOULDER_R - 0.35, z))
				boulder_node.scale = Vector3.ONE * BOULDER_R
				_add_telegraph(x, z, C_HOP, "HOP!")
			_:
				var crate := _mesh_node(_box(Vector3(1.4, 1.0, 1.0)), crate_mat, Vector3(x, 0.15, z))
				_mesh_node(_box(Vector3(1.46, 0.14, 1.06)), _mat("crate_band", C_TIMBER_DARK),
					Vector3(0.0, 0.3, 0.0), crate)
				_add_telegraph(x, z, C_JUMP, "JUMP")
		_arrow_nodes.append(arrow_node)
		_boulder_nodes.append(boulder_node)
	if _sim.can_shoot():
		for a in _sim.get_archers():
			var lbl := _label("SHOOT", C_SHOOT)
			lbl.position = Vector3(_side_x(float(a["side"]), ARCHER_X), ARCHER_Y + 3.6, float(a["z"]))
			_labels.append({"node": lbl, "z": float(a["z"]), "strip": null, "archer": str(a["id"])})

func _label(text: String, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 96
	l.pixel_size = 0.012
	l.outline_size = 18
	l.modulate = c
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	l.no_depth_test = true
	l.visible = false
	_world.add_child(l)
	return l

## `obs_index` links an arrow telegraph to its hazard, so it can vanish the moment
## the archer is shot and the volley is cancelled. -1 for hazards that can't be.
func _add_telegraph(x: float, z: float, c: Color, verb: String, obs_index: int = -1) -> void:
	var strip := _mesh_node(_box(Vector3(1.9, 0.04, 6.0)), _glow_mat("strip_" + verb, c, 0.35),
		Vector3(x, -0.36, z - 1.5))
	strip.visible = false
	# Several hazards of the same verb at the same z (a volley across all rails)
	# share ONE label, re-centred over them, instead of overprinting.
	for e in _labels:
		if e.get("verb", "") == verb and is_equal_approx(float(e["z"]), z):
			var xs: Array = e["xs"]
			xs.append(x)
			var mean := 0.0
			for v in xs:
				mean += float(v)
			(e["node"] as Label3D).position.x = mean / float(xs.size())
			(e["strips"] as Array).append(strip)
			if obs_index >= 0:
				(e["obs"] as Array).append(obs_index)
			return
	var lbl := _label(verb, c)
	lbl.position = Vector3(x, 3.3, z)
	_labels.append({"node": lbl, "z": z, "strip": null, "strips": [strip], "archer": "", "verb": verb,
		"xs": [x], "obs": ([obs_index] if obs_index >= 0 else [])})

func _build_ziplines() -> void:
	var segs: Array = _sim.get_zip_segments()
	var cable_y: float = RunnerGraybox.ZIP_HEIGHT + RIDER_HEIGHT + CABLE_CLEARANCE - 0.2
	for i in segs.size():
		var s0: float = float(segs[i]["start_z"])
		var s1: float = float(segs[i]["end_z"])
		if s1 <= s0:
			continue
		var cable := CylinderMesh.new()
		cable.top_radius = 0.045
		cable.bottom_radius = 0.045
		cable.height = s1 - s0 + 4.0
		var cm := _mesh_node(cable, _mat("cable", Color(0.55, 0.52, 0.48), 0.0, 0.4, 0.8),
			Vector3(0.0, cable_y, (s0 + s1) * 0.5))
		cm.rotation.x = PI * 0.5
		# Gantry at each end: legs OUTSIDE the outer rails, crossbeam overhead. The
		# first version stood a pole on the centre rail — the camera flew through it.
		for pz in [s0 - 2.0, s1 + 2.0]:
			for gx in [-4.6, 4.6]:
				_mesh_node(_box(Vector3(0.45, cable_y + PIT_DEPTH + 0.8, 0.45)), _mat("post", C_TIMBER),
					Vector3(float(gx), (cable_y - PIT_DEPTH) * 0.5 + 0.4, float(pz)))
			_mesh_node(_box(Vector3(9.8, 0.4, 0.45)), _mat("beam", C_TIMBER),
				Vector3(0.0, cable_y + 0.45, float(pz)))
		# Catch ring: the glowing spot to be airborne under.
		var ring := TorusMesh.new()
		ring.inner_radius = 0.16
		ring.outer_radius = 0.26
		var rm := _mesh_node(ring, _mat("zip_ring", C_ZIP, 1.4, 0.3, 0.8), Vector3(0.0, cable_y, s0))
		rm.rotation.x = PI * 0.5
		_zip_markers.append({"ring": rm, "z": s0})
		var chained: bool = i > 0 and s0 - float(segs[i - 1]["end_z"]) <= RunnerGraybox.ZIP_CHAIN_GAP
		var verb := "JUMP → next line" if chained else "JUMP → ZIPLINE"
		var lbl := _label(verb, C_ZIP)
		lbl.font_size = 72
		lbl.position = Vector3(0.0, cable_y - 0.6, s0 - (2.0 if chained else 0.0))
		# near: the label hides before it reaches the camera (which rises to cable height).
		_labels.append({"node": lbl, "z": s0, "strip": null, "archer": "", "near": 9.0})

func _build_portal(z: float) -> void:
	var h := 7.5
	for x in [-4.8, 4.8]:
		_mesh_node(_box(Vector3(0.9, h + PIT_DEPTH, 0.9)), _mat("post", C_TIMBER),
			Vector3(float(x), (h - PIT_DEPTH) * 0.5, z))
	_mesh_node(_box(Vector3(11.0, 0.9, 1.0)), _mat("beam", C_TIMBER), Vector3(0.0, h, z))
	_mesh_node(_box(Vector3(9.0, h + 0.5, 0.2)), _mat("portal_glow", Color(0.85, 0.5, 0.12), 0.9, 0.5),
		Vector3(0.0, h * 0.5 - 0.4, z + 3.0))
	var l := OmniLight3D.new()
	l.light_color = C_GOLD
	l.light_energy = 6.0
	l.omni_range = 26.0
	l.position = Vector3(0.0, 3.5, z - 1.0)
	_world.add_child(l)
	var plate := _label("GOLD MINE PROTOCOL", C_GOLD)
	plate.position = Vector3(0.0, h + 1.2, z - 0.6)
	plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plate.rotation.y = PI
	plate.visible = true
	plate.no_depth_test = false

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 66.0
	_camera.near = 0.1
	_camera.far = 160.0
	_world.add_child(_camera)
	_camera.current = true

func _build_fx() -> void:
	_sparks = CPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.35
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(0.9, 0.05, 0.9)
	_sparks.direction = Vector3(0.0, 0.6, -1.0)
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 6.0
	_sparks.gravity = Vector3(0.0, -12.0, 0.0)
	_sparks.scale_amount_min = 0.03
	_sparks.scale_amount_max = 0.06
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 4
	sm.rings = 2
	_sparks.mesh = sm
	_sparks.material_override = _mat("spark", Color(1.0, 0.75, 0.3), 6.0)
	_world.add_child(_sparks)

	var tracer := CylinderMesh.new()
	tracer.top_radius = 0.03
	tracer.bottom_radius = 0.03
	tracer.height = 1.0
	_tracer = _mesh_node(tracer, _mat("tracer", C_SHOOT, 6.0), Vector3.ZERO)
	_tracer.visible = false
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.85, 0.5)
	_flash.omni_range = 7.0
	_flash.light_energy = 0.0
	_world.add_child(_flash)

# ------------------------------------------------------------------------------
# Per-frame
# ------------------------------------------------------------------------------

func _update_convoy(dist: float) -> void:
	var spin: float = -dist / 0.3     # wheel radius ~0.3
	for i in _carts.size():
		var c: Node3D = _carts[i]
		c.position.z = dist
		# Carts jostle a little on the rails — sells speed at almost no cost.
		c.position.y = -0.3 + sin(dist * 1.7 + i * 2.1) * 0.025
		c.rotation.z = sin(dist * 1.1 + i) * 0.015
		for w in _cart_wheels[i]:
			(w as Node3D).rotation = Vector3(spin, 0.0, PI * 0.5)

func _update_rider(dist: float, delta: float) -> void:
	var x: float = float(_sim.get_cart_x())
	var y: float = float(_sim.get_cart_y())
	var zipping: bool = _sim.is_ziplining()
	# Shown the instant duck is pressed; the sim separately decides when it counts.
	var ducking: bool = _sim.is_duck_held() and not zipping

	# Hop arc: a lane change is a LEAP between carts, not a slide. When the sim's
	# lane changes, arc from where the rider visibly is to the new rail.
	var lane: int = int(_sim.get_lane())
	if lane != _last_lane:
		_hop_from_x = x
		_hop_to_x = float(_lane_xs()[lane])
		_last_lane = lane
	var arc := 0.0
	var span: float = absf(_hop_to_x - _hop_from_x)
	if span > 0.01 and not zipping:
		var t: float = clampf(absf(x - _hop_from_x) / span, 0.0, 1.0)
		arc = 4.0 * HOP_ARC * t * (1.0 - t)

	var target_y: float = RIDER_FLOOR + y + arc
	var sy: float = 1.0
	if zipping:
		target_y = RunnerGraybox.ZIP_HEIGHT
	elif ducking:
		target_y = RIDER_FLOOR - 0.45
		sy = 0.5
	_rider.position = Vector3(x, target_y, dist)
	_rider_model.scale = _rider_model.scale.lerp(Vector3(RIDER_HEIGHT, RIDER_HEIGHT * sy, RIDER_HEIGHT),
		clampf(delta * 18.0, 0.0, 1.0))
	_hook.visible = zipping
	# Lean into a hop; sway on the cable.
	_rider.rotation.z = (-(x - _prev_x) * 6.0) if not zipping else sin(dist * 0.6) * 0.12
	_prev_x = x
	_sparks.position = Vector3(x, -0.2, dist - 0.8)
	_sparks.emitting = not zipping and _sim.is_running()

func _nearest_lane_x(x: float) -> float:
	var best: float = float(_lane_xs()[0])
	for lx in _lane_xs():
		if absf(float(lx) - x) < absf(best - x):
			best = float(lx)
	return best

func _update_archers(dist: float, delta: float) -> void:
	for id in _archer_fall.keys():
		var n: Node3D = _archer_nodes.get(id)
		if n == null:
			continue
		var t: float = float(_archer_fall[id]) + delta
		_archer_fall[id] = t
		n.rotation.x = minf(t * 5.0, 1.5)
		n.position.y = ARCHER_Y - t * t * 6.0
		if t > 1.2:
			n.visible = false
	# Living archers draw back as the convoy closes in.
	for a in _sim.get_archers():
		if not a["alive"]:
			continue
		var n2: Node3D = _archer_nodes.get(str(a["id"]))
		if n2:
			var dz: float = float(a["z"]) - dist
			n2.position.y = ARCHER_Y + (sin(dist * 4.0) * 0.04 if dz < ARROW_LEAD * 1.5 and dz > -4.0 else 0.0)

func _update_arrows(dist: float) -> void:
	var obs: Array = _sim.get_obstacles()
	for i in obs.size():
		var node: Node3D = _arrow_nodes[i]
		if node == null:
			continue
		var o: Dictionary = obs[i]
		var z: float = float(o["z"])
		if o.get("cancelled", false):
			node.visible = false
			continue
		var to_go: float = z - dist
		if to_go > ARROW_LEAD or to_go < -3.0:
			node.visible = false
			continue
		var lane_x: float = float(_lane_xs()[clampi(int(o["lane"]), 0, _lane_xs().size() - 1)])
		var from_side: float = _archer_side(str(o.get("archer", "")))
		var start_x: float = _side_x(from_side, ARCHER_X)
		var t: float = clampf(1.0 - to_go / ARROW_LEAD, 0.0, 1.0)
		node.visible = true
		node.position = Vector3(lerpf(start_x, lane_x, t), ARROW_Y + sin(t * PI) * 0.8, z)
		# Point the head (local +X) along the flight: toward the lane from the archer's side.
		var dir: float = signf(lane_x - start_x) if absf(lane_x - start_x) > 0.01 else 1.0
		node.rotation = Vector3(0.0, 0.0 if dir > 0.0 else PI, cos(t * PI) * 0.35 * dir)

func _archer_side(id: String) -> float:
	for a in _sim.get_archers():
		if str(a["id"]) == id:
			return float(a["side"])
	return 1.0

func _update_boulders(dist: float) -> void:
	var obs: Array = _sim.get_obstacles()
	for i in obs.size():
		var node: Node3D = _boulder_nodes[i]
		if node == null:
			continue
		var z: float = float(obs[i]["z"])
		var vz: float = z + (z - dist) * BOULDER_ROLL
		node.position.z = vz
		node.visible = vz - dist < 70.0 and vz - dist > -12.0
		node.rotation.x = -vz / BOULDER_R

func _update_labels(dist: float) -> void:
	for e in _labels:
		var z: float = float(e["z"])
		var ahead: float = z - dist
		var show: bool = ahead > float(e.get("near", 1.0)) and ahead < TELEGRAPH_RANGE
		var archer_id: String = str(e["archer"])
		if archer_id != "":
			show = show and _archer_alive(archer_id)
		var live := true
		var linked: Array = e.get("obs", [])
		if linked.size() > 0:
			live = false
			for i in linked:
				if not bool(_sim.get_obstacles()[int(i)].get("cancelled", false)):
					live = true
					break
		show = show and live
		(e["node"] as Label3D).visible = show
		for st in e.get("strips", []):
			(st as MeshInstance3D).visible = live and ahead > -2.0 and ahead < TELEGRAPH_RANGE + 10.0
	for m in _zip_markers:
		var r: MeshInstance3D = m["ring"]
		var pulse: float = 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		r.scale = Vector3.ONE * pulse
		r.visible = float(m["z"]) - dist > 4.0      # never flies through the camera

func _archer_alive(id: String) -> bool:
	for a in _sim.get_archers():
		if str(a["id"]) == id:
			return bool(a["alive"])
	return false

func _update_lights(dist: float) -> void:
	# Park the light pool on the lanterns just behind and ahead of the rider.
	var first := 0
	while first < _lantern_z.size() and _lantern_z[first] < dist - 8.0:
		first += 1
	for i in _lights.size():
		var idx := first + i
		var l: OmniLight3D = _lights[i]
		if idx < _lantern_z.size():
			var lz: float = _lantern_z[idx]
			var side: float = 1.0 if idx % 2 == 0 else -1.0
			l.position = Vector3(side * 4.3, 2.2, lz)
			l.visible = true
		else:
			l.visible = false

func _update_camera(dist: float, delta: float) -> void:
	var rx: float = float(_sim.get_cart_x())
	var target := Vector3(rx * 0.6, 3.1, dist - 5.4)
	if _sim.is_ziplining():
		target.y = 4.1                  # below the cable, so rings/labels pass overhead
	var k: float = clampf(delta * 6.0, 0.0, 1.0)
	var p: Vector3 = _camera.position
	p.x = lerpf(p.x, target.x, k)
	p.y = lerpf(p.y, target.y, k)
	p.z = target.z                     # never lag in z — the run speed must feel locked
	if _shake > 0.0:
		p += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * _shake * 0.25
		_shake = maxf(0.0, _shake - delta * 3.0)
	_camera.position = p
	_camera.look_at(Vector3(rx * 0.4, 1.9, dist + 11.0), Vector3.UP)

func _update_fx(delta: float) -> void:
	if _tracer_t > 0.0:
		_tracer_t -= delta
		_tracer.visible = _tracer_t > 0.0
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 40.0)

# ------------------------------------------------------------------------------
# Sim events
# ------------------------------------------------------------------------------

func _on_hit(_remaining: int) -> void:
	_shake = 1.0

func _on_shot() -> void:
	_flash.position = _rider.position + Vector3(0.3, 1.2, 0.8)
	_flash.light_energy = 5.0

func _on_archer_down(id: String) -> void:
	_archer_fall[id] = 0.0
	var n: Node3D = _archer_nodes.get(id)
	if n == null:
		return
	var from: Vector3 = _rider.position + Vector3(0.3, 1.2, 0.8)
	var to: Vector3 = n.position + Vector3(0.0, 1.5, 0.0)
	var mid: Vector3 = (from + to) * 0.5
	_tracer.position = mid
	_tracer.look_at(to, Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
	_tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_tracer.scale = Vector3(1.0, from.distance_to(to), 1.0)   # after look_at, which resets scale
	_tracer_t = 0.09
	_tracer.visible = true

func _on_zip_caught(_i: int) -> void:
	_shake = maxf(_shake, 0.25)

func _on_zip_missed(_i: int) -> void:
	_shake = 1.2
