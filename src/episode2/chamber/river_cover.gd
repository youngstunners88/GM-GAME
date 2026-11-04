class_name RiverCoverChamber
extends Ep2Interlude
## THE DAY-88 RIVER COVER (founder lock 2026-11-04, docs/founder-feedback/2026-11-04_day88_river_cover.md).
## Out of Logan's Lake Lil Blunt climbs to a ridge over the river. Crossing the DAY-88 marker and looking down from the first overlook
## puts THE SHIPMENT he bought from Rich & Utah into the water - the same crate Tabs spins (Ep2ShipmentCrate) - and it drifts
## downstream through exactly three gates: the LAUNCH POOL, the BEND / RAPIDS and the DOCK APPROACH. Bears come off the banks, swim at
## it and try to board and tip it; he covers it from the ridge with the Armory's Sharps (any gun he carries works, the Sharps drops a
## bear in one). Between gates the crate waits in an eddy while he drops to the next ledge (one bear on the path each time - the short
## ground scrapes). Utah waits at the lower dock (never at the lake; Rich never comes) and takes it in under the crane.
## Prerequisites: the Sharps AND the Shipment from the Armory. Missing either, the run does not start and no crate is spawned.
## Failure (the crate tipped, or Lil Blunt downed): back to the CURRENT gate's overlook, the crate back at that gate, the gate's wave
## again and the guns' ammunition as it was when the gate began. Never a repurchase.

enum Beat { APPROACH, OVERLOOK, RUN, DOCK, DONE, BLOCKED }

## The river (x, z), water at y = 0; it runs down +z. The three gates and the two eddies are points on it.
const RIVER_POINTS: Array = [Vector2(0, -24), Vector2(0, 0), Vector2(4, 40), Vector2(13, 80), Vector2(10, 100), Vector2(-4, 124),
	Vector2(-5, 150), Vector2(2, 180), Vector2(6, 205), Vector2(8, 236), Vector2(6, 262), Vector2(3, 300), Vector2(-2, 360)]   # on past the dock
const RIVER_HALF := 7.0
const LAUNCH_POINT := Vector2(0, 0)          # gate 1: the launch pool, under the first overlook
const EDDY_1 := Vector2(11, 96)              # waits here for the move to the bend ledge
const BEND_POINT := Vector2(-4, 124)         # gate 2: the bend and its rapids
const EDDY_2 := Vector2(4, 196)              # waits here for the move to the dock ledge
const DOCK_APPROACH := Vector2(8, 236)       # gate 3
const DOCK_POINT := Vector2(6, 262)          # the lower dock, under the crane
const GATE_NAMES := ["LAUNCH POOL", "THE BEND", "DOCK APPROACH"]
## The ridge path (x, y, z): the high ground on the east bank, dropping twice to a new ledge (the relocates).
const RIDGE_POINTS: Array = [Vector3(42, 22, -26), Vector3(38, 22, -8), Vector3(34, 22, 4), Vector3(37, 22, 40), Vector3(40, 21.5, 80),
	Vector3(36, 21, 96), Vector3(32, 15, 112), Vector3(30, 15, 124), Vector3(31, 15, 160), Vector3(30, 14.5, 196), Vector3(27, 13, 212),
	Vector3(24, 8, 228), Vector3(22, 8, 241)]                 # ends at the last overlook: the dock below stays in clear view
const RIDGE_HALF := 3.0
const MARKER := Vector3(38, 22, -8)          # the DAY-88 cairn and post: crossing it arms the run
## The three overlooks stand on the cliff lip (the river side of the path), so the eye clears the edge and sees the water below.
const OVERLOOKS: Array = [Vector3(31.4, 22, 4), Vector3(27.4, 15, 124), Vector3(19.6, 8, 238)]
const OVERLOOK_R := 4.5
const SPAWN := Vector3(42, 22, -26)
## Pacing: the crate's drift (m/s) per gate while bears are on it / once its wave is down; the rapids are the slowest and most exposed.
const DRIFT := [[1.1, 2.4], [0.7, 1.8], [0.9, 2.0]]
const WAVES := [2, 4, 3]
const BOARD_TIME := 5.0                      # bear-seconds aboard that tip the crate
const BEAR_HEIGHT := 2.2
const SWIM_SPEED := 1.6
const BANK_SPEED := 3.6
const RIDGE_BEAR_SPEED := 3.2
const RIDGE_BEAR_AGGRO := 28.0               # the ledge bear holds its ground until he comes down within this range
const LOOK_DOT := 0.93                       # how squarely he must look at the launch pool
const LOOK_HOLD := 0.5
const UTAH_HEIGHT := 1.85
const DOCK_DECK := Vector3(13, 1.2, 262)
const UTAH_LINE := "river_utah_dock"

var _river_pts := PackedVector3Array()
var _river_arc := PackedFloat32Array()
var _river_total: float = 0.0
var _ridge_arc := PackedFloat32Array()
var _crate: Node3D
var _crate_s: float = 0.0
var _crate_board: float = 0.0
var _launched: bool = false
var _launch_delay: float = 0.0
var _look_t: float = 0.0
var _gate: int = -1                          # 0..2 once the run is live
var _gates_passed: int = 0
var _wave_spawned: bool = false
var _wave_left: int = 0
var _spawn_queue: Array = []
var _spawn_t: float = 0.0
var _bears: Array = []                       # dictionaries: actor, state, hp, side, lateral, board, swipe_t, ridge
var _bears_root: Node3D
var _ridge_scrapes: Array = [false, false]
var _health: int = 3
var _invuln: float = 0.0
var _losses: int = 0
var _downs: int = 0
var _gate_ammo: Dictionary = {}
var _utah: Ep2TownFolk
var _utah_t: float = -1.0
var _dock_t: float = -1.0
var _blocked_reason: String = ""
var _water_loop: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	title_card = "DAY-88 RIVER"
	viewmodel_exposure = 0.85
	camera_min = Vector3(-200, -5, -200)
	camera_max = Vector3(260, 150, 420)


func _chamber_id() -> String: return "river_cover"
func _beat_label(b: int) -> String: return Beat.keys()[clampi(b, 0, Beat.size() - 1)]
func _build_steps() -> Array: return [_light, _build_land, _build_river, _build_ridge, _build_marker, _build_dock, _build_crate, _build_utah]


# --- the set ------------------------------------------------------------------------------------------------------------------

func _light() -> void:
	var env := Environment.new()
	_env_node.environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.46, 0.62)
	sky_mat.sky_horizon_color = Color(0.74, 0.76, 0.72)
	sky_mat.ground_horizon_color = Color(0.45, 0.42, 0.33)
	sky_mat.ground_bottom_color = Color(0.14, 0.12, 0.09)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.60, 0.56)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.70, 0.64)
	env.fog_density = 0.0012
	_sun.rotation_degrees = Vector3(-38, 52, 0)
	_sun.light_color = Color(1.0, 0.90, 0.74)
	_sun.light_energy = 1.3
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 160.0


func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


## Ground everywhere (the banks), a long reach of the river valley.
func _build_land() -> void:
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	plane.mesh = pm
	plane.material_override = _mat(Color(0.47, 0.42, 0.29))
	plane.position = Vector3(20, 0.25, 120)
	plane.name = "Valley"
	_visuals.add_child(plane)
	# pines along the west bank and behind the ridge (simple cones: a readable treeline, not a forest to hide bears in)
	var trunk_mat := _mat(Color(0.30, 0.20, 0.12))
	var leaf_mat := _mat(Color(0.16, 0.30, 0.17))
	for i in 34:
		var z: float = -30.0 + i * 9.0
		var west: Vector3 = Vector3(_river_x(z) - RIVER_HALF - 14.0 - float(i % 3) * 5.0, 0.25, z)
		_pine(west, 7.0 + float(i % 4), trunk_mat, leaf_mat)
		if i % 2 == 0:
			_pine(Vector3(58.0 + float(i % 5) * 4.0, 0.25, z + 3.0), 8.0 + float(i % 3), trunk_mat, leaf_mat)


func _pine(at: Vector3, h: float, trunk_mat: Material, leaf_mat: Material) -> void:
	var t := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.18
	tm.bottom_radius = 0.28
	tm.height = h * 0.35
	t.mesh = tm
	t.material_override = trunk_mat
	t.position = at + Vector3(0, h * 0.175, 0)
	_visuals.add_child(t)
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = h * 0.22
	cm.height = h * 0.8
	c.mesh = cm
	c.material_override = leaf_mat
	c.position = at + Vector3(0, h * 0.6, 0)
	_visuals.add_child(c)


## The river: a riverbed ribbon, the water over it, white water at the bend.
func _build_river() -> void:
	_river_pts = Ep2LakeRoad.smooth(RIVER_POINTS, 1.0)
	_river_arc.resize(_river_pts.size())
	_river_total = 0.0
	for i in _river_pts.size():
		if i > 0:
			_river_total += _river_pts[i - 1].distance_to(_river_pts[i])
		_river_arc[i] = _river_total
	var bed := Ep2LakeRoad.ribbon(_visuals, _river_pts, RIVER_HALF * 2.0 + 6.0, _mat(Color(0.30, 0.27, 0.20)), 0.27)
	bed.name = "RiverBed"
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.20, 0.38, 0.40, 0.86)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.08
	water_mat.metallic = 0.25
	var water := Ep2LakeRoad.ribbon(_visuals, _river_pts, RIVER_HALF * 2.0, water_mat, 0.32)
	water.name = "RiverWater"
	var foam := _mat(Color(0.86, 0.90, 0.88), 0.5)
	for i in 14:
		var s: float = river_s_of(BEND_POINT) - 14.0 + i * 2.6
		var p: Vector3 = river_point(s)
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.6 + 0.25 * float(i % 3)
		sm.height = sm.radius * 1.1
		rock.mesh = sm
		rock.material_override = foam if i % 2 == 0 else _mat(Color(0.36, 0.34, 0.31))
		rock.position = p + river_right(s) * (float((i * 7) % 11) - 5.0) + Vector3(0, 0.25, 0)
		rock.name = "Rapids%d" % i
		_visuals.add_child(rock)


## The ridge: the walkable path (a raised strip at the path's heights) and the cliff face down to the east bank.
func _build_ridge() -> void:
	_ridge_arc.resize(RIDGE_POINTS.size())
	var total: float = 0.0
	for i in RIDGE_POINTS.size():
		if i > 0:
			total += _flat(RIDGE_POINTS[i - 1]).distance_to(_flat(RIDGE_POINTS[i]))
		_ridge_arc[i] = total
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_col := Color(0.52, 0.45, 0.35)
	for i in RIDGE_POINTS.size() - 1:
		var a: Vector3 = RIDGE_POINTS[i]
		var b: Vector3 = RIDGE_POINTS[i + 1]
		var dir2: Vector2 = (_flat(b) - _flat(a)).normalized()
		var to_river := Vector3(-dir2.y, 0, dir2.x)          # the path runs down +z with the river to its west: this points at the water
		var lip_a: Vector3 = a + to_river * (RIDGE_HALF + 0.35)        # the cliff lip, just past the overlook stance
		var lip_b: Vector3 = b + to_river * (RIDGE_HALF + 0.35)
		var back_a: Vector3 = a - to_river * (RIDGE_HALF + 3.0)
		var back_b: Vector3 = b - to_river * (RIDGE_HALF + 3.0)
		_quad(st, lip_a, back_a, back_b, lip_b, rock_col)                                                        # the path's top
		var foot_a: Vector3 = lip_a + to_river * 9.0
		var foot_b: Vector3 = lip_b + to_river * 9.0
		foot_a.y = 0.3
		foot_b.y = 0.3
		_quad(st, foot_a, lip_a, lip_b, foot_b, rock_col.darkened(0.3))                                          # the river face
		var heel_a: Vector3 = back_a - to_river * 14.0
		var heel_b: Vector3 = back_b - to_river * 14.0
		heel_a.y = 0.3
		heel_b.y = 0.3
		_quad(st, back_a, heel_a, heel_b, back_b, rock_col.darkened(0.12))                                       # the back slope
	# the ridge's end: a slope down to the bank, so nothing stands between the last overlook and Utah's dock
	var last: Vector3 = RIDGE_POINTS[-1]
	var prev: Vector3 = RIDGE_POINTS[-2]
	var d2: Vector2 = (_flat(last) - _flat(prev)).normalized()
	var fwd := Vector3(d2.x, 0, d2.y)
	var tr := Vector3(-d2.y, 0, d2.x)
	var e_lip: Vector3 = last + tr * (RIDGE_HALF + 0.35)
	var e_back: Vector3 = last - tr * (RIDGE_HALF + 3.0)
	var e_lip_f: Vector3 = e_lip + fwd * 12.0
	var e_back_f: Vector3 = e_back + fwd * 12.0
	e_lip_f.y = 0.3
	e_back_f.y = 0.3
	_quad(st, e_lip, e_back, e_back_f, e_lip_f, rock_col.darkened(0.2))
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var m := _mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = m
	mesh.name = "Ridge"
	_visuals.add_child(mesh)
	# each overlook: a flat rock lip and a stake, readable from the path
	for i in OVERLOOKS.size():
		var o: Vector3 = OVERLOOKS[i]
		_box(Vector3(2.6, 0.22, 2.6), o + Vector3(0.2, 0.07, 0), _mat(Color(0.62, 0.55, 0.44)))           # the flat rock he stands on
		_box(Vector3(0.12, 1.3, 0.12), o + Vector3(1.0, 0.65, -1.5), _mat(Color(0.42, 0.28, 0.16)))     # behind him, out of the view


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(v)


## The DAY-88 marker: a cairn of river stones, a painted post and its plank - Western readable, not a billboard.
func _build_marker() -> void:
	var root := Node3D.new()
	root.name = "Day88Marker"
	root.position = MARKER + Vector3(2.2, 0, 0)                 # on the back of the path: it never blocks the view down
	_visuals.add_child(root)
	var stone := _mat(Color(0.62, 0.58, 0.52))
	for i in 5:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55 - i * 0.08
		sm.height = sm.radius * 1.2
		s.mesh = sm
		s.material_override = stone
		s.position = Vector3(0.05 * float(i % 2), 0.3 + i * 0.42, 0)
		root.add_child(s)
	var red := _mat(Color(0.62, 0.16, 0.10))
	var band := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.34
	bm.height = 0.36
	band.mesh = bm
	band.material_override = red                          # the painted top stone
	band.position = Vector3(0, 2.25, 0)
	root.add_child(band)
	var wood := _mat(Color(0.45, 0.30, 0.17))
	_box(Vector3(0.16, 2.6, 0.16), Vector3(1.1, 1.3, 0), wood, root)
	_box(Vector3(0.12, 0.8, 1.9), Vector3(1.1, 2.2, 0), wood, root)
	for face in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "DAY 88\nRIVER RUN"
		label.font_size = 64
		label.pixel_size = 0.0055
		label.modulate = Color(0.97, 0.86, 0.60)
		label.outline_size = 6
		label.outline_modulate = Color(0.20, 0.10, 0.05)
		label.position = Vector3(1.1 + face * 0.07, 2.2, 0)
		label.rotation.y = PI * 0.5 * face
		root.add_child(label)


## The lower dock on the east bank: deck, piles, a shed, and the A-frame crane that lifts the crate out.
func _build_dock() -> void:
	var root := Node3D.new()
	root.name = "LowerDock"
	_visuals.add_child(root)
	var wood := _mat(Color(0.42, 0.29, 0.17))
	var dark := _mat(Color(0.27, 0.18, 0.11))
	_box(Vector3(12, 0.3, 7), DOCK_DECK + Vector3(0, -0.15, 0), wood, root)
	for x in [-5.5, -1.5, 2.5, 5.5]:
		for z in [-3.0, 3.0]:
			_box(Vector3(0.35, 2.4, 0.35), DOCK_DECK + Vector3(x, -1.2, z), dark, root)
	_box(Vector3(5, 3.2, 4), DOCK_DECK + Vector3(9, 1.6, 0), wood, root)      # the shed on the bank
	_box(Vector3(5.4, 0.25, 4.4), DOCK_DECK + Vector3(9, 3.3, 0), dark, root)
	# the crane: two legs, a beam and a boom out over the water, a rope down to the hook
	_box(Vector3(0.3, 6.0, 0.3), DOCK_DECK + Vector3(-3.5, 3.0, -2.2), dark, root)
	_box(Vector3(0.3, 6.0, 0.3), DOCK_DECK + Vector3(-3.5, 3.0, 2.2), dark, root)
	_box(Vector3(0.3, 0.3, 4.7), DOCK_DECK + Vector3(-3.5, 6.0, 0), dark, root)
	_box(Vector3(5.5, 0.28, 0.28), DOCK_DECK + Vector3(-6.0, 6.0, 0), dark, root)
	var rope := _box(Vector3(0.05, 4.0, 0.05), DOCK_DECK + Vector3(-8.4, 4.0, 0), _mat(Color(0.72, 0.62, 0.42)), root)
	rope.name = "CraneRope"
	var sign := Label3D.new()
	sign.text = "DAY-88 DOCK"
	sign.font_size = 56
	sign.pixel_size = 0.006
	sign.modulate = Color(0.97, 0.86, 0.60)
	sign.outline_size = 5
	sign.position = DOCK_DECK + Vector3(6.4, 2.6, 0)
	sign.rotation.y = -PI * 0.5
	root.add_child(sign)


## THE SHIPMENT: only when he owns it (no free crate). It waits in the launch pool until the run is live.
func _build_crate() -> void:
	if not armory.river_gear:
		return
	_crate = Ep2ShipmentCrate.model(1.5)
	_crate.name = "Shipment"
	_visuals.add_child(_crate)
	# a pennant on a pole lashed to it: his package reads from the ridge at a glance, not only through the scope
	var pole := _box(Vector3(0.06, 2.4, 0.06), Vector3(0, 1.9, 0), _mat(Color(0.35, 0.24, 0.14)), _crate)
	pole.name = "PennantPole"
	var flag := _box(Vector3(0.04, 0.55, 0.9), Vector3(0, 2.75, 0.47), _mat(Color(0.78, 0.13, 0.08), 0.7), _crate)
	flag.name = "Pennant"
	_crate_s = river_s_of(LAUNCH_POINT)
	_place_crate(0.0)


## Utah, at the lower dock only (never at Logan's Lake; Rich never comes). Hidden until the dock approach is clear.
func _build_utah() -> void:
	_utah = Ep2TownFolk.new()
	_utah.name = "Utah"
	_utah.looping_clips.assign(["Idle", "Walk", "Talk"])
	_visuals.add_child(_utah)
	var path: String = Ep2Extras.UTAH if Ep2Extras.has(Ep2Extras.UTAH) else GoldTownChamber.UTAH_MODEL
	_utah.setup(path, UTAH_HEIGHT, Color(0.28, 0.33, 0.34))
	_utah.position = DOCK_DECK + Vector3(9, 0, 3.2)
	_utah.visible = false


# --- geometry helpers --------------------------------------------------------------------------------------------------------

func river_point(s: float) -> Vector3:
	if _river_pts.is_empty():
		return Vector3.ZERO
	var d: float = clampf(s, 0.0, _river_total)
	var i: int = 1
	while i < _river_arc.size() - 1 and _river_arc[i] < d:
		i += 1
	var seg: float = maxf(_river_arc[i] - _river_arc[i - 1], 0.0001)
	return _river_pts[i - 1].lerp(_river_pts[i], clampf((d - _river_arc[i - 1]) / seg, 0.0, 1.0))


func river_dir(s: float) -> Vector3:
	var d: Vector3 = river_point(s + 1.0) - river_point(s - 1.0)
	return d.normalized() if d.length_squared() > 0.0001 else Vector3(0, 0, 1)


func river_right(s: float) -> Vector3:
	var d: Vector3 = river_dir(s)
	return Vector3(-d.z, 0, d.x)


func river_s_of(p: Vector2) -> float:
	var best: float = INF
	var at: float = 0.0
	for i in _river_pts.size():
		var d: float = Vector2(_river_pts[i].x, _river_pts[i].z).distance_squared_to(p)
		if d < best:
			best = d
			at = _river_arc[i]
	return at


func _river_x(z: float) -> float:
	for i in RIVER_POINTS.size() - 1:
		var a: Vector2 = RIVER_POINTS[i]
		var b: Vector2 = RIVER_POINTS[i + 1]
		if z <= b.y:
			return lerpf(a.x, b.x, clampf((z - a.y) / maxf(b.y - a.y, 0.001), 0.0, 1.0))
	return (RIVER_POINTS[-1] as Vector2).x


## The nearest point on the ridge path to `p` (x/z): [point on the centre line with its height, arc length, unit right].
func ridge_nearest(p: Vector3) -> Array:
	var best_d: float = INF
	var best: Array = [RIDGE_POINTS[0], 0.0, Vector3.RIGHT]
	for i in RIDGE_POINTS.size() - 1:
		var a: Vector3 = RIDGE_POINTS[i]
		var b: Vector3 = RIDGE_POINTS[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t: float = clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q: Vector3 = a.lerp(b, t)
		var d: float = Vector2(p.x - q.x, p.z - q.z).length_squared()
		if d < best_d:
			best_d = d
			var dir := ab.normalized()
			best = [q, lerpf(_ridge_arc[i], _ridge_arc[i + 1], t), Vector3(-dir.y, 0, dir.x)]
	return best


func ridge_s(p: Vector3) -> float:
	return float(ridge_nearest(p)[1])


## The ridge keeps him on its path: within RIDGE_HALF of the centre line, standing on its height.
func _collide(p: Vector3) -> Vector3:
	var near: Array = ridge_nearest(p)
	var c: Vector3 = near[0]
	var right: Vector3 = near[2]
	var off: float = clampf((p - c).dot(right), -RIDGE_HALF, RIDGE_HALF)
	var out: Vector3 = c + right * off
	out.y = p.y
	return out


# --- setup ---------------------------------------------------------------------------------------------------------------------

func _on_setup() -> void:
	_rng.seed = 88
	_player_pos = SPAWN
	_ground_y = SPAWN.y
	var to: Vector3 = river_point(river_s_of(LAUNCH_POINT)) - SPAWN
	_look_yaw = atan2(to.x, to.z)
	_look_pitch = -0.12
	_health = 3
	if _hud != null:
		_hud.show_health = true
	# the Sharps up: the mountain cover weapon (founder lock); anything else he carries still works
	if armory.owns(Ep2ArmoryState.BUFF) and not armory.is_held(Ep2ArmoryState.BUFF):
		armory.select(Ep2ArmoryState.BUFF)
	_blocked_reason = ""
	if not armory.river_gear:
		_blocked_reason = "shipment"
	elif not armory.sniper_owned:
		_blocked_reason = "sniper"
	_advance_to(Beat.APPROACH)
	if Ep2Extras.has("res://src/episode2/extras/audio/lake/water.ogg"):
		_water_loop = _loop_player("res://src/episode2/extras/audio/lake/water.ogg", -14.0)
		_water_loop.play()


func _on_beat_entered(b: int) -> void:
	if _hud == null:
		return
	match b:
		Beat.APPROACH:
			_hud.objective = "Climb to the DAY-88 marker on the ridge."
		Beat.OVERLOOK:
			_hud.objective = "Hold the overlook and look down at the launch pool."
		Beat.BLOCKED:
			if _blocked_reason == "shipment":
				_hud.objective = "No shipment to cover: THE SHIPMENT is bought at Rich & Utah's counter."
			else:
				_hud.objective = "The day-88 run needs the Sharps buffalo gun from Rich & Utah's counter."
		Beat.DOCK:
			_hud.objective = "DAY-88 RUN · the shipment reaches Utah's dock."


func _shows_health() -> bool:
	return true


func get_health() -> int:
	return _health


func _heal_full() -> bool:
	if _health >= 3:
		return false
	_health = 3
	return true


# --- the run -------------------------------------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	var near: Array = ridge_nearest(_player_pos)
	_ground_y = (near[0] as Vector3).y
	match _beat:
		Beat.APPROACH:
			if ridge_s(_player_pos) >= ridge_s(MARKER):
				if _blocked_reason != "":
					_advance_to(Beat.BLOCKED)
				else:
					_advance_to(Beat.OVERLOOK)
		Beat.OVERLOOK:
			_tick_activation(delta)
		Beat.RUN:
			_tick_run(delta)
		Beat.DOCK:
			_tick_dock(delta)
	if _crate != null:
		_place_crate(delta)
	_step_bears(delta)


## Option A: on the first overlook, looking squarely at the launch pool for half a second, the current takes the crate.
func _tick_activation(delta: float) -> void:
	var o: Vector3 = OVERLOOKS[0]
	var pool: Vector3 = river_point(river_s_of(LAUNCH_POINT))
	var eye: Vector3 = _player_pos + Vector3(0, eye_height, 0)
	var looking: bool = _look_dir().dot((pool - eye).normalized()) >= LOOK_DOT
	if _flat(_player_pos).distance_to(_flat(o)) <= OVERLOOK_R and looking:
		_look_t += delta
		if _look_t >= LOOK_HOLD:
			_launch()
	else:
		_look_t = 0.0


func _look_dir() -> Vector3:
	var cp: float = cos(_look_pitch)
	return Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)


func _launch() -> void:
	_launched = true
	_set_tabs_live(true)                                # the Tabs shipment tile pulses while the run is on
	if _hud != null:
		_hud.toast("DAY-88 RUN LIVE", 2.4)
	_advance_to(Beat.RUN)
	_begin_gate(0)


func _begin_gate(g: int) -> void:
	_gate = g
	_gates_passed = maxi(_gates_passed, g + 1)
	_wave_spawned = false
	_wave_left = WAVES[g]
	_spawn_queue.clear()
	for i in WAVES[g]:
		_spawn_queue.append(i)
	_spawn_t = 1.2
	_gate_ammo = armory.snapshot()
	_launch_delay = 1.0
	if _hud != null:
		_hud.objective = "DAY-88 RUN · GATE %d/3 · %s · cover the shipment from the ridge." % [g + 1, GATE_NAMES[g]]
		_hud.toast("GATE %d/3 · %s" % [g + 1, GATE_NAMES[g]], 2.0)


## Where the crate must wait for him (the eddy before the next gate), or the dock at the end.
func _hold_s() -> float:
	match _gate:
		0: return river_s_of(EDDY_1)
		1: return river_s_of(EDDY_2)
	return river_s_of(DOCK_POINT)


func _tick_run(delta: float) -> void:
	_launch_delay = maxf(0.0, _launch_delay - delta)
	# the gate's wave comes off the banks a few seconds apart, ahead of the crate
	if not _spawn_queue.is_empty():
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_river_bear(int(_spawn_queue.pop_front()))
			_spawn_t = 3.0
	var cleared: bool = _spawn_queue.is_empty() and _river_bears_alive() == 0
	var aboard: int = _bears_aboard()
	# the crate drifts unless a bear has hold of it
	if _launch_delay <= 0.0 and aboard == 0:
		var v: float = float(DRIFT[_gate][1] if cleared else DRIFT[_gate][0])
		_crate_s = minf(_crate_s + v * delta, _hold_s())
	if aboard > 0:
		_crate_board += float(aboard) * delta
		if _crate_board >= BOARD_TIME:
			_package_lost()
			return
	else:
		_crate_board = maxf(0.0, _crate_board - delta * 0.5)
	# a ground scrape on the way down to the next ledge, once the gate is clear
	if cleared and _gate < 2 and not _ridge_scrapes[_gate]:
		_ridge_scrapes[_gate] = true
		_spawn_ridge_bear(_gate)
	if cleared and _crate_s >= _hold_s() - 0.05:
		if _gate < 2:
			var next_o: Vector3 = OVERLOOKS[_gate + 1]
			if _hud != null:
				_hud.objective = "The shipment waits in the eddy · drop to the next ledge overlook."
			if _flat(_player_pos).distance_to(_flat(next_o)) <= OVERLOOK_R and absf(_player_pos.y - next_o.y) < 1.5:
				_begin_gate(_gate + 1)
		else:
			_advance_to(Beat.DOCK)
			_dock_t = 0.0
			_utah_arrives()


func _river_bears_alive() -> int:
	var n: int = 0
	for b in _bears:
		if not bool(b["ridge"]) and str(b["state"]) != "dead":
			n += 1
	return n


func _bears_aboard() -> int:
	var n: int = 0
	for b in _bears:
		if str(b["state"]) == "board":
			n += 1
	return n


## The crate on the water: bobbing, turning with the current, heeling over as bears haul on it.
func _place_crate(_delta: float) -> void:
	var p: Vector3 = river_point(_crate_s)
	var d: Vector3 = river_dir(_crate_s)
	_crate.position = p + Vector3(0, 0.18 + 0.06 * sin(_anim_t * 2.1), 0)
	if _beat == Beat.DOCK and _dock_t >= 0.0:
		var k: float = clampf(_dock_t / 2.4, 0.0, 1.0)
		_crate.position = _crate.position.lerp(DOCK_DECK + Vector3(-1.0, 0.05, 0), smoothstep(0.0, 1.0, k))
	var heel: float = deg_to_rad(28.0) * clampf(_crate_board / BOARD_TIME, 0.0, 1.0)
	_crate.rotation = Vector3(0.03 * sin(_anim_t * 1.7), atan2(d.x, d.z), 0.04 * sin(_anim_t * 1.3) + heel)


# --- bears ---------------------------------------------------------------------------------------------------------------------

func _ensure_bears_root() -> void:
	if _bears_root == null:
		_bears_root = Node3D.new()
		_bears_root.name = "Bears"
		_visuals.add_child(_bears_root)


## A river bear: comes out of the trees on a bank downstream of the crate, wades in and swims at it.
func _spawn_river_bear(i: int) -> void:
	_ensure_bears_root()
	var side: float = -1.0 if i % 2 == 0 else 1.0
	var s: float = minf(_crate_s + 22.0 + 7.0 * float(i), _hold_s() + 6.0)
	var bank: Vector3 = river_point(s) + river_right(s) * side * (RIVER_HALF + 7.0)
	var a: Ep2Actor = Ep2BearKit.make_bear(_bears_root, bank + Vector3(0, 0.25, 0), BEAR_HEIGHT)
	a.name = "RiverBear%d_%d" % [_gate, i]
	_bears.append({"actor": a, "state": "bank", "hp": 2, "side": side, "s": s, "swipe_t": 0.0, "ridge": false, "dead_t": 0.0})
	Ep2BearKit.pose(a, "run")
	_sfx("ep2_bear_attack_%d" % (1 + i % 3))


## A ridge bear on the path down to the next ledge (the short scrape on foot).
func _spawn_ridge_bear(g: int) -> void:
	_ensure_bears_root()
	var at: Vector3 = OVERLOOKS[g + 1]
	var near: Array = ridge_nearest(at + Vector3(0, 0, -10.0))
	var a: Ep2Actor = Ep2BearKit.make_bear(_bears_root, near[0], BEAR_HEIGHT)
	a.name = "RidgeBear%d" % g
	_bears.append({"actor": a, "state": "ridge", "hp": 2, "side": 0.0, "s": 0.0, "swipe_t": 1.0, "ridge": true, "dead_t": 0.0})
	Ep2BearKit.pose(a, "walk")


func _step_bears(delta: float) -> void:
	for b in _bears:
		var a: Ep2Actor = b["actor"]
		if not is_instance_valid(a):
			continue
		a.step(delta)
		Ep2BearKit.tick_pose(a, delta)
		match str(b["state"]):
			"bank":
				var s: float = float(b["s"])
				var edge: Vector3 = river_point(s) + river_right(s) * float(b["side"]) * (RIVER_HALF - 0.5)
				if _walk_to(a, edge + Vector3(0, 0.25, 0), BANK_SPEED, delta):
					b["state"] = "swim"
					Ep2BearKit.pose(a, "walk")
			"swim":
				var target: Vector3 = _crate.position if _crate != null else a.position
				target.y = -0.95
				var flat_d: float = _flat(a.position).distance_to(_flat(target))
				a.position.y = move_toward(a.position.y, -0.95, delta * 1.2)
				if flat_d <= 1.6:
					b["state"] = "board"
					Ep2BearKit.pose(a, "swipe")
				else:
					_walk_to(a, Vector3(target.x, a.position.y, target.z), SWIM_SPEED, delta)
			"board":
				if _crate != null:
					var hold: Vector3 = _crate.position + river_right(_crate_s) * float(b["side"]) * 1.2
					a.position = Vector3(hold.x, -0.75, hold.z)
					a.rotation.y = atan2(_crate.position.x - a.position.x, _crate.position.z - a.position.z)
			"ridge":
				var to_player: float = _flat(a.position).distance_to(_flat(_player_pos))
				if to_player > RIDGE_BEAR_AGGRO:
					Ep2BearKit.pose(a, "stomp")             # on the ledge, waiting across his way down
				elif to_player > 2.2:
					var next: Vector3 = _player_pos
					var step: Vector3 = (_flat3(next) - _flat3(a.position)).normalized() * RIDGE_BEAR_SPEED * delta
					var moved: Vector3 = _collide(a.position + step)
					moved.y = (ridge_nearest(moved)[0] as Vector3).y
					a.position = moved
					a.rotation.y = atan2(step.x, step.z)
					Ep2BearKit.pose(a, "run")
				else:
					Ep2BearKit.pose(a, "swipe")
					b["swipe_t"] = float(b["swipe_t"]) - delta
					if float(b["swipe_t"]) <= 0.0:
						b["swipe_t"] = 1.4
						_hurt_player()
			"dead":
				b["dead_t"] = float(b["dead_t"]) + delta
				if a.position.y < 0.0:
					a.position.y -= delta * 0.4          # a river bear sinks out of the way
					if float(b["dead_t"]) > 4.0:
						a.visible = false


func _flat3(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _walk_to(a: Ep2Actor, target: Vector3, speed: float, delta: float) -> bool:
	var to: Vector3 = target - a.position
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() <= speed * delta + 0.05:
		a.position = Vector3(target.x, a.position.y, target.z)
		return true
	var step: Vector3 = flat.normalized() * speed * delta
	a.position += step
	a.rotation.y = atan2(step.x, step.z)
	return false


## A bear's body for a bullet: one capsule along him (he is upright on the bank, chest-deep swimming).
func _bear_capsule(a: Ep2Actor) -> Array:
	var k: float = a.height_m / 2.2
	return [a.position + Vector3(0, 0.45 * k, 0), a.position + Vector3(0, 1.85 * k, 0), 0.62 * k]


func _bear_on_ray(eye: Vector3, dir: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_t: float = 260.0
	for b in _bears:
		if str(b["state"]) == "dead":
			continue
		var a: Ep2Actor = b["actor"]
		if not is_instance_valid(a) or not a.visible:
			continue
		var cap: Array = _bear_capsule(a)
		var t: float = WoodsQuadChamber._ray_capsule(eye, dir, cap[0], cap[1], float(cap[2]))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = b
	return best


func aim_on_target(eye: Vector3, dir: Vector3) -> bool:
	return not _bear_on_ray(eye, dir).is_empty()


func _on_player_shot() -> void:
	var eye: Vector3 = _player_pos + Vector3(0, eye_height, 0)
	var dir: Vector3 = _look_dir()
	if _vm != null and _vm.gun != null:
		var sigma: float = _vm.gun.spread_deg(_moving, false)
		if sigma > 0.0:
			var yaw: float = _look_yaw + deg_to_rad(_rng.randfn(0.0, sigma))
			var pitch: float = _look_pitch + deg_to_rad(_rng.randfn(0.0, sigma))
			dir = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var hit: Dictionary = _bear_on_ray(eye, dir)
	if hit.is_empty():
		return
	# the Sharps drops a bear in one; the lighter guns take two
	var dmg: int = 2 if armory.equipped == Ep2ArmoryState.BUFF else 1
	var killed: bool = damage_bear(hit, dmg)
	if _hud != null:
		_hud.hit_marker(killed)


## Wound a bear; true when that killed him. Public so the headless gate can drive the waves without aiming.
func damage_bear(b: Dictionary, dmg: int) -> bool:
	if str(b["state"]) == "dead":
		return false
	b["hp"] = int(b["hp"]) - dmg
	if int(b["hp"]) > 0:
		return false
	b["state"] = "dead"
	var a: Ep2Actor = b["actor"]
	Ep2BearKit.pose(a, "dead")
	_sfx("ep2_bear_death_%d" % (1 + _rng.randi() % 2))
	return true


func _hurt_player() -> void:
	if _invuln > 0.0 or _resolved:
		return
	_health = maxi(0, _health - 1)
	_invuln = 1.0
	if _hud != null:
		_hud.hurt()
	_sfx("damage")
	if _health <= 0:
		_downed()


# --- failure: back to the current gate -----------------------------------------------------------------------------------------

func _package_lost() -> void:
	_losses += 1
	if _hud != null:
		_hud.toast("THE SHIPMENT TIPPED · BACK TO THE %s OVERLOOK" % GATE_NAMES[_gate], 2.6)
	_retry_gate()


func _downed() -> void:
	_downs += 1
	if _hud != null:
		_hud.toast("DOWNED · BACK TO THE %s OVERLOOK" % GATE_NAMES[_gate], 2.6)
	_retry_gate()


## The one retry rule: the current gate again - the crate back where the gate began, its wave again, him on its overlook with full
## hearts and the ammunition he had then. The Shipment stays his; nothing is bought again.
func _retry_gate() -> void:
	for b in _bears:
		var a: Ep2Actor = b["actor"]
		if is_instance_valid(a):
			a.queue_free()
	_bears.clear()
	if _gate == 0:
		_crate_s = river_s_of(LAUNCH_POINT)
	elif _gate == 1:
		_crate_s = river_s_of(EDDY_1)
	else:
		_crate_s = river_s_of(EDDY_2)
	_crate_board = 0.0
	_health = 3
	_invuln = 1.5
	if not _gate_ammo.is_empty():
		armory.restore(_gate_ammo, armory.owns(Ep2ArmoryState.REM))
	var o: Vector3 = OVERLOOKS[_gate]
	_player_pos = Vector3(o.x, o.y, o.z)
	_ground_y = o.y
	if _gate < 2:
		_ridge_scrapes[_gate] = false                  # the ledge bear on the way down comes again with the gate
	_begin_gate(_gate)


# --- the dock --------------------------------------------------------------------------------------------------------------------

func _utah_arrives() -> void:
	if _utah == null:
		return
	_utah.visible = true
	_utah_t = 0.0
	_utah.play_clip("Walk")


func _tick_dock(delta: float) -> void:
	if _utah_t >= 0.0 and _utah != null:
		_utah_t += delta
		var from: Vector3 = DOCK_DECK + Vector3(9, 0, 3.2)
		var to: Vector3 = DOCK_DECK + Vector3(-0.5, 0, 1.8)
		var k: float = clampf(_utah_t / 3.0, 0.0, 1.0)
		_utah.position = from.lerp(to, k)
		if k >= 1.0 and _utah_t < 3.1:
			_utah.play_clip("Idle")
			_utah.face_point(_crate.position if _crate != null else to)
	# the crate rides the last stretch to the crane, then swings up onto the deck
	if _crate_s < river_s_of(DOCK_POINT) - 0.05:
		_crate_s = minf(_crate_s + 2.0 * delta, river_s_of(DOCK_POINT))
		return
	if _dock_t < 0.0:
		_dock_t = 0.0
	var before: float = _dock_t
	_dock_t += delta
	if before < 2.4 and _dock_t >= 2.4:
		_hand_off_line()
	if _dock_t >= 2.4 + _line_len() + 0.6:
		_set_tabs_live(false)
		_advance_to(Beat.DONE)
		_resolve({"end_session": true, "river_complete": true, "gates": _gates_passed, "losses": _losses, "downs": _downs,
			"companion": ""})


func _hand_off_line() -> void:
	var text: String = "Got her! Day-eighty-eight's in, Lil Blunt. Clean shooting up there."
	if _hud != null:
		var id: String = Ep2TownVoiceBank.id_for("utah", text)
		_hud.speech("UTAH: " + text, _line_len(), Ep2Speech.voiced(id))
		if id != "":
			_speak(id)
	if _utah != null:
		_utah.play_clip("Talk")


func _line_len() -> float:
	return maxf(2.5, Ep2TownVoiceBank.seconds(UTAH_LINE) + 0.4) if Ep2TownVoiceBank.LINES.has(UTAH_LINE) else 3.0


func _set_tabs_live(on: bool) -> void:
	var panel: Variant = _hud.get("_panel") if _hud != null else null
	if panel is Ep2WeaponSelector:
		(panel as Ep2WeaponSelector).shipment_live = on


## E at the marker when the run cannot start: the slice ends here and says what to bring (no free crate is ever spawned).
func start_rig(_payment: String = "") -> bool:
	if _beat == Beat.BLOCKED and _flat(_player_pos).distance_to(_flat(MARKER)) < 8.0:
		_resolve({"end_session": true, "river_blocked": _blocked_reason, "companion": ""})
		return true
	return false


# --- read-outs (tests, the HUD, capture tools) --------------------------------------------------------------------------------

func is_launched() -> bool: return _launched
func get_gate() -> int: return _gate
func gates_passed() -> int: return _gates_passed
func crate_s() -> float: return _crate_s
func get_crate() -> Node3D: return _crate
func get_losses() -> int: return _losses
func get_downs() -> int: return _downs
func get_bears() -> Array: return _bears
func utah_visible() -> bool: return _utah != null and _utah.visible
func blocked_reason() -> String: return _blocked_reason
func board_progress() -> float: return _crate_board / BOARD_TIME
