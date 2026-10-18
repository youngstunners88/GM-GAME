class_name Ep2GoldTown
extends RefCounted
## THE GOLDMINE TOWN (founder lock 2026-10-14, PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md; look: skill ep2-gold-rush-town, target
## artifacts/episode2-gold-mine/references/founder_2026-10-13_town/goldmine_town_target.jpg + the Muapi street still
## artifacts/episode2-gold-mine/references/fort_knox_prep/town_street/hero.jpg).
##
## ONE layout, built by BOTH the bear woods (you see the town and Fort Knox grow out of the desert as the quad comes down the road, and
## Bull drops you in its street) and the town chamber (where you walk in), at the SAME world coordinates - so the hand-over between the
## two rooms is a single invisible cut (skill ep2-no-blackouts).
##
## The street runs along +z from TOWN_Z, centred on x = 0, fronts at x = +-STREET_HALF. Buildings come from the Blender town kit
## (tools/ep2_blender/build_town_kit.py); their origin is the middle of the front edge, the front faces local +Z. Signs are painted
## textures (tools/ep2_forge/paint_town_signs.py) hung on each building's SignAnchor_<WORD>. No sign for the protocol Episode 2 bans (ep2-fort-knox-arc rule 4).

const KIT := "res://src/episode2/assets/town/town_kit.glb"
const TEX_DIR := "res://src/episode2/assets/town/"
const BARREL := "res://src/episode2/assets/mine_lift/mine_barrel.glb"
const CRATE := "res://src/episode2/assets/mine_lift/mine_crate.glb"
const ROCK := "res://src/episode2/assets/woods/woods_rock.glb"
const PLANK_TEX := "res://src/episode2/assets/mine_lift/tex_lift_planks.jpg"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const TOWN_Z := 1400.0
const STREET_HALF := 9.0
const DROP_POINT := Vector3(0.0, 0.0, 1403.0)        # where the quad stops and Lil Blunt hops off
const FORT_POS := Vector3(34.0, 0.0, 1610.0)          # Fort Knox on its rock hill beyond the town (FORT_HILL_H up)
const FORT_HILL_H := 20.0

## [kit piece, x of the front plane, z of the front centre, faces the street from the left (+1) / right (-1) / along -z (0)]
const LAYOUT: Array = [
	["Bldg_Certificates", -STREET_HALF, 1412.0, 1], ["Bldg_A", -STREET_HALF, 1421.5, 1], ["Bldg_B", -STREET_HALF, 1430.0, 1],
	["Bldg_C", -STREET_HALF, 1438.5, 1], ["Bldg_E", -STREET_HALF, 1447.0, 1],
	["Bldg_Saloon", STREET_HALF, 1414.0, -1], ["Bldg_Treasury", STREET_HALF, 1426.5, -1], ["Bldg_D", STREET_HALF, 1437.5, -1],
	["Bldg_F", STREET_HALF, 1447.0, -1],
	["Church", 0.0, 1478.0, 0],
	["Bldg_Armory", -20.0, 1468.0, 0],   # Rich & Utah's shop: down a side lane off the left row, set back off the Main Street sightline
]
## Kit piece -> [width, depth, door half-width (0 = shut), door open]
const FOOTPRINT: Dictionary = {
	"Bldg_Certificates": [8.0, 9.0, 0.75], "Bldg_Saloon": [12.0, 12.0, 0.95], "Bldg_Treasury": [10.0, 12.0, 0.0], "Bldg_A": [7.0, 8.0, 0.0],
	"Bldg_B": [8.0, 9.0, 0.0], "Bldg_C": [6.0, 8.0, 0.0], "Bldg_D": [9.0, 9.0, 0.0], "Bldg_E": [7.0, 8.0, 0.0], "Bldg_F": [8.0, 9.0, 0.0],
	"Church": [8.0, 14.0, 0.0],
	"Bldg_Armory": [8.0, 9.0, 0.7],
}


## The yaw that turns a kit piece's local +Z front toward the street.
static func yaw_for(side: int) -> float:
	match side:
		1:
			return PI * 0.5            # on the left (x < 0): faces +x
		-1:
			return -PI * 0.5           # on the right: faces -x
	return PI                          # at the end of the street: faces back down it (-z)


## A building's transform (origin = middle of the front edge at street level).
static func building_xform(entry: Array) -> Transform3D:
	var side: int = int(entry[3])
	return Transform3D(Basis(Vector3.UP, yaw_for(side)), Vector3(float(entry[1]), 0.0, float(entry[2])))


static func entry(piece: String) -> Array:
	for e in LAYOUT:
		if str(e[0]) == piece:
			return e
	return []


## A point given in a building's LOCAL frame (x along the front, z negative = inside) -> world.
static func local_to_world(piece: String, p: Vector3) -> Vector3:
	var e: Array = entry(piece)
	return building_xform(e) * p if not e.is_empty() else p


static func door_world(piece: String, out: float = 1.0) -> Vector3:
	return local_to_world(piece, Vector3(0.0, 0.0, out))


## Build the town into `parent`. `interiors` = furnish the certificate office and the saloon (the town chamber); the woods only needs the
## street seen from the road. Returns {"walls": [[Vector2 a, Vector2 b], ...], "props": [[Vector2 p, radius], ...]} for collision.
static func build(parent: Node3D, interiors: bool) -> Dictionary:
	var walls: Array = []
	var props: Array = []
	var root := Node3D.new()
	root.name = "GoldTown"
	parent.add_child(root)
	if not ResourceLoader.exists(KIT):
		return {"walls": walls, "props": props}
	var kit: Node3D = (load(KIT) as PackedScene).instantiate() as Node3D
	_apply_mats(kit)
	for e in LAYOUT:
		var src: Node3D = kit.find_child(str(e[0]), true, false) as Node3D
		if src == null:
			continue
		var b: Node3D = src.duplicate() as Node3D
		b.transform = building_xform(e)
		root.add_child(b)
		_hang_signs(b)
		walls.append_array(_walls_of(str(e[0]), building_xform(e)))
	# the street furniture: hitching rails, troughs, wagons, lamps, barrels and crates, benches on the porches
	var dress: Array = [
		["HitchRail", Vector3(-6.4, 0.0, 1418.0), PI * 0.5], ["HitchRail", Vector3(6.4, 0.0, 1431.0), PI * 0.5],
		["HitchRail", Vector3(-6.4, 0.0, 1441.0), PI * 0.5], ["Trough", Vector3(-6.0, 0.0, 1425.0), PI * 0.5],
		["Trough", Vector3(6.2, 0.0, 1420.5), PI * 0.5], ["Wagon", Vector3(4.2, 0.0, 1452.0), 0.2], ["Wagon", Vector3(-3.6, 0.0, 1463.0), -2.9],
		["LampPost", Vector3(-6.8, 0.0, 1409.0), 0.0], ["LampPost", Vector3(6.8, 0.0, 1424.0), PI], ["LampPost", Vector3(-6.8, 0.0, 1434.0), 0.0],
		["Bench", Vector3(-7.6, 0.44, 1423.0), PI * 0.5], ["Bench", Vector3(7.6, 0.44, 1446.0), -PI * 0.5],
		# the armory lane, off the left row past the STATS block: a lamp, and river gear staged at the lean-to
		["LampPost", Vector3(-10.0, 0.0, 1450.0), 0.0],
		["Arm_PowderKeg", Vector3(-17.0, 0.0, 1465.2), 0.0], ["Arm_PowderKeg", Vector3(-16.1, 0.0, 1465.7), 0.0],
		["River_Crate", Vector3(-14.9, 0.0, 1465.0), 0.3], ["River_Skiff", Vector3(-22.4, 0.0, 1460.0), PI * 0.5],
	]
	for d in dress:
		var s: Node3D = kit.find_child(str(d[0]), true, false) as Node3D
		if s == null:
			continue
		var n: Node3D = s.duplicate() as Node3D
		n.transform = Transform3D(Basis(Vector3.UP, float(d[2])), d[1])
		root.add_child(n)
		props.append([Vector2((d[1] as Vector3).x, (d[1] as Vector3).z), 1.6 if str(d[0]) == "Wagon" else 0.7])
	for bp in [Vector3(-6.9, 0.0, 1427.5), Vector3(-7.3, 0.0, 1428.3), Vector3(7.0, 0.0, 1433.0), Vector3(6.6, 0.0, 1443.6), Vector3(-7.0, 0.0, 1450.0)]:
		_glb(root, BARREL, bp, bp.x * 0.7, 1.0)
		props.append([Vector2(bp.x, bp.z), 0.45])
	for cp in [Vector3(7.4, 0.0, 1434.2), Vector3(-7.1, 0.0, 1416.2), Vector3(6.9, 0.0, 1451.0)]:
		_glb(root, CRATE, cp, cp.z, 1.0)
		props.append([Vector2(cp.x, cp.z), 0.6])
	# Fort Knox on its rock hill, flags flying
	var hill := Node3D.new()
	hill.name = "FortHill"
	root.add_child(hill)
	for i in 9:
		var a: float = float(i) * 0.7
		var r: float = 10.0 + 9.0 * float(i % 3)
		_glb(hill, ROCK, FORT_POS + Vector3(cos(a) * r, -4.0, sin(a) * r * 0.8), a, 13.0 + 3.0 * float(i % 4), Color(0.86, 0.72, 0.52))
	var plateau := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 30.0
	cm.bottom_radius = 46.0
	cm.height = FORT_HILL_H
	cm.radial_segments = 14
	plateau.mesh = cm
	plateau.material_override = _tex_mat("tex_sandstone.jpg", Color(0.78, 0.64, 0.46), 0.05)
	plateau.position = FORT_POS + Vector3(0.0, FORT_HILL_H * 0.5 - 0.2, -6.0)
	hill.add_child(plateau)
	var fort_src: Node3D = kit.find_child("FortKnox", true, false) as Node3D
	if fort_src != null:
		var fort: Node3D = fort_src.duplicate() as Node3D
		fort.transform = Transform3D(Basis(Vector3.UP, PI), FORT_POS + Vector3(0.0, FORT_HILL_H - 0.2, 0.0))
		root.add_child(fort)
		_hang_signs(fort)
		for fa in fort.find_children("FlagAnchor*", "", true, false):
			_flag(fort, (fa as Node3D).position)
	if interiors:
		_furnish(root, kit)
	kit.free()
	return {"walls": walls, "props": props}


## The kit's named materials -> textured, world-triplanar ones (one material per name, shared by every instance).
static func _apply_mats(kit: Node) -> void:
	var mats: Dictionary = {
		"Siding": _tex_mat("tex_siding.jpg", Color(0.92, 0.84, 0.74), 0.45, PLANK_TEX),
		"Trim": _tex_mat("tex_siding.jpg", Color(0.55, 0.42, 0.30), 0.8, TIMBER_TEX),
		"Roof": _tex_mat("tex_roof.jpg", Color(0.85, 0.82, 0.78), 0.35, ""),
		"Sandstone": _tex_mat("tex_sandstone.jpg", Color(1.0, 0.95, 0.86), 0.35, ""),
		"FortStone": _tex_mat("tex_fortstone.jpg", Color(0.95, 0.90, 0.82), 0.12, ""),
		"PaintWhite": _tex_mat("tex_siding.jpg", Color(1.35, 1.32, 1.25), 0.45, PLANK_TEX),
		"Planks": _tex_mat("", Color(0.80, 0.72, 0.62), 0.7, PLANK_TEX),
	}
	(mats["Roof"] as StandardMaterial3D).metallic = 0.35
	for mi in kit.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(si)
			var key: String = String(src.resource_name) if src != null else ""
			if mats.has(key):
				m.mesh.surface_set_material(si, mats[key])


## A world-triplanar material from a town texture (falls back to `fallback`, then to a flat colour) - tinted.
static func _tex_mat(file: String, tint: Color, uv_scale: float, fallback: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.88
	var path: String = TEX_DIR + file if file != "" else ""
	if path == "" or not ResourceLoader.exists(path):
		path = fallback
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
	return m


## Hang the painted board on every SignAnchor_<WORD> of a building.
static func _hang_signs(b: Node3D) -> void:
	for an in b.find_children("SignAnchor_*", "", true, false):
		var word: String = String(an.name).trim_prefix("SignAnchor_")
		var path: String = TEX_DIR + "sign_%s.png" % word
		if not ResourceLoader.exists(path):
			continue
		var q := MeshInstance3D.new()
		q.name = "Sign_" + word
		var qm := QuadMesh.new()
		var w: float = 6.0 if word != "FORTKNOX" else 5.6
		if word in ["ASSAY", "STATS"]:
			w = 4.6
		qm.size = Vector2(w, w * 180.0 / 1024.0)
		q.mesh = qm
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load(path)
		sm.roughness = 0.9
		q.material_override = sm
		(an as Node3D).add_child(q)


## The building's walls as ground-plane segments (the door gap left open on the enterable ones), for collision.
static func _walls_of(piece: String, xf: Transform3D) -> Array:
	var fp: Array = FOOTPRINT.get(piece, [8.0, 9.0, 0.0])
	var w: float = float(fp[0]) * 0.5
	var d: float = float(fp[1])
	var door: float = float(fp[2])
	var local: Array = []
	if door > 0.0:
		local.append([Vector3(-w, 0, 0), Vector3(-door, 0, 0)])
		local.append([Vector3(door, 0, 0), Vector3(w, 0, 0)])
	else:
		local.append([Vector3(-w, 0, 0), Vector3(w, 0, 0)])
	local.append([Vector3(-w, 0, 0), Vector3(-w, 0, -d)])
	local.append([Vector3(w, 0, 0), Vector3(w, 0, -d)])
	local.append([Vector3(-w, 0, -d), Vector3(w, 0, -d)])
	var out: Array = []
	for s in local:
		var a: Vector3 = xf * (s[0] as Vector3)
		var b: Vector3 = xf * (s[1] as Vector3)
		out.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	return out


## Push a body of radius `r` at ground point `p` out of every wall segment and prop circle.
static func collide(p: Vector2, r: float, walls: Array, props: Array) -> Vector2:
	var q := p
	for s in walls:
		var a: Vector2 = s[0]
		var ab: Vector2 = (s[1] as Vector2) - a
		var t: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var c: Vector2 = a + ab * t
		var dv: Vector2 = q - c
		var dl: float = dv.length()
		if dl < r:
			q = c + (dv / dl if dl > 1e-5 else Vector2(-ab.y, ab.x).normalized()) * r
	for pr in props:
		var cp: Vector2 = pr[0]
		var rr: float = float(pr[1]) + r
		var dv2: Vector2 = q - cp
		if dv2.length() < rr:
			q = cp + (dv2.normalized() if dv2.length() > 1e-5 else Vector2(1, 0)) * rr
	return q


static func _glb(parent: Node3D, path: String, pos: Vector3, yaw: float, scale: float, tint: Color = Color(1, 1, 1)) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos)
	parent.add_child(n)
	if tint != Color(1, 1, 1):
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var sm := StandardMaterial3D.new()
			sm.albedo_color = tint
			var src: Material = m.mesh.surface_get_material(0) if m.mesh and m.mesh.get_surface_count() > 0 else null
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				sm.albedo_texture = (src as BaseMaterial3D).albedo_texture
			sm.roughness = 0.95
			m.material_override = sm
	return n


## A cloth flag on a pole top (a quad that ripples in the shader-free way: a slow rotation wobble driven by the owner, if any).
static func _flag(parent: Node3D, pos: Vector3) -> void:
	var q := MeshInstance3D.new()
	q.name = "Flag"
	var qm := QuadMesh.new()
	qm.size = Vector2(1.8, 1.1)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.62, 0.18)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material_override = m
	q.position = pos
	parent.add_child(q)


## The two rooms Lil Blunt walks into: the certificate office (counter, pigeonholes, desk, stove, lamps) and the saloon (the long bar,
## the back shelf of bottles round a mirror, tables and chairs, a piano, oil lamps). Positions are in each building's local frame.
static func _furnish(root: Node3D, kit: Node3D) -> void:
	var rooms: Array = [
		["Bldg_Certificates", "Int_Counter", Vector3(0.6, 0.0, -4.6), 0.0], ["Bldg_Certificates", "Int_Shelves", Vector3(0.6, 0.0, -8.6), 0.0],
		["Bldg_Certificates", "Int_Desk", Vector3(-2.3, 0.0, -7.0), 0.0], ["Bldg_Certificates", "Int_Stove", Vector3(-3.0, 0.0, -2.4), 0.0],
		["Bldg_Saloon", "Bar_Counter", Vector3(-1.0, 0.0, -9.0), 0.0], ["Bldg_Saloon", "Bar_BackShelf", Vector3(-1.0, 0.0, -11.6), 0.0],
		["Bldg_Saloon", "Bar_Piano", Vector3(4.9, 0.0, -10.6), -PI * 0.5],
		["Bldg_Saloon", "Bar_Table", Vector3(-3.2, 0.0, -3.6), 0.0], ["Bldg_Saloon", "Bar_Table", Vector3(3.6, 0.0, -3.0), 0.0],
		["Bldg_Saloon", "Bar_Table", Vector3(3.8, 0.0, -6.8), 0.0],
		# the armory: counter, wall racks, a revolver case, the lit long-rifle case, a powder keg
		["Bldg_Armory", "Arm_Counter", Vector3(0.6, 0.0, -4.4), 0.0], ["Bldg_Armory", "Arm_Rack", Vector3(-3.4, 0.0, -7.4), PI * 0.5],
		["Bldg_Armory", "Arm_Rack", Vector3(3.4, 0.0, -7.4), -PI * 0.5], ["Bldg_Armory", "Arm_Case", Vector3(-1.4, 0.0, -6.6), 0.0],
		["Bldg_Armory", "Arm_SniperCase", Vector3(1.8, 0.0, -7.8), 0.0], ["Bldg_Armory", "Arm_PowderKeg", Vector3(-3.2, 0.0, -2.2), 0.0],
	]
	for rm in rooms:
		var src: Node3D = kit.find_child(str(rm[1]), true, false) as Node3D
		if src == null:
			continue
		var n: Node3D = src.duplicate() as Node3D
		var xf: Transform3D = building_xform(entry(str(rm[0])))
		n.transform = xf * Transform3D(Basis(Vector3.UP, float(rm[3])), rm[2])
		n.name = str(rm[1]) + "_" + str(rm[0])
		root.add_child(n)
	var chair: Node3D = kit.find_child("Bar_Chair", true, false) as Node3D
	if chair != null:
		for tp in [Vector3(-3.2, 0.0, -3.6), Vector3(3.6, 0.0, -3.0), Vector3(3.8, 0.0, -6.8)]:
			for k in 3:
				var a: float = float(k) * TAU / 3.0 + tp.x
				var c: Node3D = chair.duplicate() as Node3D
				c.transform = building_xform(entry("Bldg_Saloon")) * Transform3D(Basis(Vector3.UP, a + PI), tp + Vector3(sin(a), 0, cos(a)) * 0.95)
				root.add_child(c)
	# warm oil lamps in both rooms
	for lp in [["Bldg_Certificates", Vector3(0.0, 3.0, -4.0), 4.5], ["Bldg_Saloon", Vector3(-2.0, 3.2, -4.0), 6.0], ["Bldg_Saloon", Vector3(3.0, 3.2, -8.0), 6.0], ["Bldg_Armory", Vector3(0.0, 3.0, -5.0), 5.0]]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 1.8
		l.omni_range = float(lp[2]) * 2.0
		l.position = local_to_world(str(lp[0]), lp[1])
		root.add_child(l)


## Gold-rush country light (`k` 0 = the woods' golden hour, 1 = the open desert by the town): a warm low sun ahead, amber sky, thin
## warm haze so the mesas and Fort Knox read at distance. Interpolated by road distance as the quad leaves the trees - never a cut.
static func apply_desert_grade(env: Environment, sun: DirectionalLight3D, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if env.sky == null:
		env.background_mode = Environment.BG_SKY
		env.sky = Sky.new()
		env.sky.sky_material = ProceduralSkyMaterial.new()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.fog_enabled = true
		env.adjustment_enabled = true
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_hdr_threshold = 1.0
	var psm := env.sky.sky_material as ProceduralSkyMaterial
	if psm != null:
		psm.sky_top_color = Color(0.46, 0.52, 0.62).lerp(Color(0.42, 0.52, 0.66), k)
		psm.sky_horizon_color = Color(0.92, 0.80, 0.62).lerp(Color(0.98, 0.80, 0.55), k)
		psm.ground_horizon_color = Color(0.40, 0.32, 0.22).lerp(Color(0.66, 0.52, 0.36), k)
		psm.ground_bottom_color = Color(0.30, 0.24, 0.17)
		psm.sky_energy_multiplier = lerpf(1.6, 1.45, k)
		psm.sun_angle_max = 18.0
	env.fog_light_color = Color(0.60, 0.58, 0.48).lerp(Color(0.86, 0.70, 0.50), k)
	env.fog_density = lerpf(0.0095, 0.0022, k)
	env.fog_sun_scatter = 0.35
	env.fog_sky_affect = 0.3
	env.ambient_light_color = Color(0.50, 0.52, 0.46).lerp(Color(0.62, 0.54, 0.44), k)
	env.ambient_light_energy = lerpf(0.55, 0.62, k)
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.adjustment_saturation = lerpf(1.0, 1.05, k)
	env.adjustment_contrast = lerpf(1.22, 1.15, k)
	sun.rotation_degrees = Vector3(lerpf(-14.0, -16.0, k), 160.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.62).lerp(Color(1.0, 0.80, 0.56), k)
	sun.light_energy = lerpf(2.0, 2.3, k)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0


## Dry tan wagon-road dirt, world-tiled.
static func desert_ground_mat() -> StandardMaterial3D:
	var m: StandardMaterial3D = _tex_mat("tex_desert.jpg", Color(0.92, 0.82, 0.66), 0.22, "res://src/episode2/assets/textures/tex_gravel.jpg")
	m.roughness = 0.97
	return m


# --- the desert around the town (built identically by the woods and the town chamber) -------------------------------------

static func _hash01(x: float, z: float, k: float) -> float:
	var h: float = sin(x * 12.9898 * k + z * 78.233) * 43758.5453
	return h - floor(h)


static func _road_dist(p: Vector2, road: Array) -> float:
	var best: float = 1e9
	for i in range(road.size() - 1):
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		if maxf(a.y, b.y) < p.y - 60.0 or minf(a.y, b.y) > p.y + 60.0:
			continue
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## Gold-rush country from the last pines (forest_end_z - 100) to world_end_z: dry sage scrub in 60 m slices with draw distances,
## boulders, and mesas / rock hills on the horizon. Deterministic (hashed), so two rooms building it get the very same desert.
static func build_desert(parent: Node3D, road: Array, forest_end_z: float, world_end_z: float, scrub_mesh: Mesh, rock_mesh: Mesh,
		scrub_mat: Material, rock_mat: Material, z_from: float = -1e9) -> void:
	var rocks: Array = []
	var z: float = forest_end_z - 100.0
	while z < world_end_z:
		if z + 60.0 < z_from:
			z += 60.0
			continue
		var xf_s: Array = []
		var x: float = -160.0
		while x <= 160.0:
			var h1: float = _hash01(x, z, 11.3)
			var h2: float = _hash01(z, x, 13.7)
			var p := Vector2(x + (h1 - 0.5) * 6.0, z + (h2 - 0.5) * 6.0)
			var near_road: float = _road_dist(p, road)
			var in_town: bool = absf(p.x) < 26.0 and p.y > TOWN_Z - 6.0 and p.y < TOWN_Z + 90.0
			var open_k: float = clampf((p.y - (forest_end_z - 100.0)) / 120.0, 0.0, 1.0)      # scrub takes over as the pines thin
			if near_road > 3.5 and not in_town and h1 < 0.55 * open_k:
				var sc: float = 0.6 + 0.9 * h2
				xf_s.append(Transform3D(Basis(Vector3.UP, h1 * TAU) * Basis.from_scale(Vector3(sc, sc * (0.6 + 0.5 * h1), sc)), Vector3(p.x, -0.05, p.y)))
			if near_road > 6.0 and not in_town and h2 > 0.965:
				rocks.append(Transform3D(Basis(Vector3.UP, h2 * TAU) * Basis.from_scale(Vector3.ONE * (0.8 + 2.6 * h1)), Vector3(p.x, -0.3, p.y)))
			x += 4.0
		if scrub_mesh != null and not xf_s.is_empty():
			var mm := _multi(parent, scrub_mesh, xf_s, scrub_mat, 150.0)
			mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mm.name = "DesertScrub_%d" % int(z)
		z += 60.0
	if rock_mesh != null and not rocks.is_empty():
		_multi(parent, rock_mesh, rocks, rock_mat, 220.0).name = "DesertRocks"
	# mesas and rock hills on the horizon (no draw distance: they ARE the horizon)
	var mesas: Array = []
	for k in 16:
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var mz: float = 1050.0 + float(k) * 70.0 + 30.0 * _hash01(float(k), 3.0, 2.0)
		var mx: float = side * (190.0 + 160.0 * _hash01(float(k), 7.0, 5.0))
		var sc2: float = 26.0 + 30.0 * _hash01(float(k), 1.0, 9.0)
		mesas.append(Transform3D(Basis(Vector3.UP, float(k)) * Basis.from_scale(Vector3(sc2 * 1.6, sc2 * 0.55, sc2 * 1.2)), Vector3(mx, -sc2 * 0.12, mz)))
	for k in 6:
		var sc3: float = 60.0 + 25.0 * float(k % 3)
		mesas.append(Transform3D(Basis(Vector3.UP, float(k) * 1.3) * Basis.from_scale(Vector3(sc3 * 1.8, sc3 * 0.5, sc3)), Vector3(-260.0 + 105.0 * float(k), -sc3 * 0.1, 2050.0)))
	if rock_mesh != null:
		_multi(parent, rock_mesh, mesas, rock_mat, 0.0).name = "Mesas"


static func _multi(parent: Node3D, mesh: Mesh, xforms: Array, mat: Material, draw_dist: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if draw_dist > 0.0:
		mmi.visibility_range_end = draw_dist
		mmi.visibility_range_end_margin = 12.0
	parent.add_child(mmi)
	return mmi


## The desert scrub: the founder's sage card (Muapi, keyed) on the wind shader, else the woods' fern card tinted dry.
static func scrub_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/episode2/art/ep2_foliage_wind.gdshader")
	var card: String = TEX_DIR + "card_sage.png"
	var fern: String = "res://src/episode2/assets/woods/tex_woods_fern.png"
	if ResourceLoader.exists(card):
		m.set_shader_parameter("albedo_tex", load(card))
		m.set_shader_parameter("tint", Color(1.0, 1.0, 1.0))
	else:
		if ResourceLoader.exists(fern):
			m.set_shader_parameter("albedo_tex", load(fern))
		m.set_shader_parameter("tint", Color(0.95, 0.82, 0.52))
	m.set_shader_parameter("sway", 0.05)
	m.set_shader_parameter("speed", 1.4)
	m.set_shader_parameter("bend_height", 1.0)
	m.set_shader_parameter("flutter", 0.012)
	return m


static func desert_rock_mat() -> StandardMaterial3D:
	return _tex_mat("tex_sandstone.jpg", Color(0.86, 0.70, 0.52), 0.06, "res://src/episode2/assets/woods/tex_woods_floor.jpg")


## The kit meshes the desert needs, from the woods' kit (the same meshes the woods use): [scrub card mesh, rock mesh].
static func desert_meshes() -> Array:
	var fern: Mesh = null
	var rock: Mesh = null
	var fk: String = "res://src/episode2/assets/woods/forest_kit.glb"
	if ResourceLoader.exists(fk):
		var r: Node = (load(fk) as PackedScene).instantiate()
		var mi: MeshInstance3D = r.find_child("Fern", true, false) as MeshInstance3D
		if mi != null:
			fern = mi.mesh
		r.free()
	if ResourceLoader.exists(ROCK):
		var rr: Node = (load(ROCK) as PackedScene).instantiate()
		for n in rr.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).mesh != null:
				rock = (n as MeshInstance3D).mesh
				break
		rr.free()
	return [fern, rock]
