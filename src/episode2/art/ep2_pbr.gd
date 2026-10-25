class_name Ep2Pbr
extends RefCounted
## PHOTO-SCANNED MATERIALS FOR EPISODE 2 (founder 2026-10-25: "hyperreal props, furnace, kegs, tools, surfaces - not grey primitives";
## "Colt Gatling - full quality pass"; "armory interior ... subtle detail").
##
## The Blender kits (Gatling post, Sharps, the two-storey Armory, the hideout's architecture and set dressing) were authored with FLAT
## colours: one albedo per material, no grain, no wear, no relief. This library dresses them with CC0 photo-scanned PBR sets (Poly Haven /
## ambientCG, prepared by tools/ep2_pbr/prep_pbr.py into res://src/episode2/extras/pbr/<set>/{albedo,normal,orm}.jpg): albedo grain, an
## OpenGL normal map, and one ORM texture (R = occlusion, G = roughness, B = metalness).
##
## How it keeps what the founder approved:
##  * Materials are matched by their AUTHORED NAME (GunSteel, Brass, GunWood, Iron, DarkWood, Stone, ...) - nothing else is touched.
##  * The authored colour is kept: the set's albedo is divided by its own mean (MEAN below, linear), so the dressed surface has the
##    approved average colour and brightness and only gains detail - no re-grade of a lit scene.
##  * Object-space triplanar mapping: no UVs needed, and the texture sticks to moving parts (the Gatling's barrels spin with it).
##  * Metals are capped (the web build's Compatibility renderer has no reflection probes: a fully metallic surface goes near black
##    indoors - the hideout's gold note), so brass and blued steel read as metal without turning into holes.
##  * Streamed extras: when the pack is not mounted yet (`available()` false) every caller keeps its old material.

const DIR := "res://src/episode2/extras/pbr/"

## Mean linear albedo of each prepared set (tools/ep2_pbr/prep_pbr.py prints these and writes pbr_sets.json).
const MEAN := {
	"brass_worn": Color(0.9669, 0.7498, 0.3245), "steel_blued": Color(0.1584, 0.1551, 0.1474),
	"wood_walnut": Color(0.4991, 0.3248, 0.2101), "wood_dark": Color(0.1141, 0.0254, 0.0096), "planks_weathered": Color(0.1228, 0.0911, 0.0635),
	"planks_raw": Color(0.3858, 0.225, 0.0978), "stone_dressed": Color(0.3781, 0.289, 0.1764), "iron_painted": Color(0.4126, 0.2867, 0.133),
	"leather_brown": Color(0.0828, 0.027, 0.0056), "brick_red": Color(0.4133, 0.1958, 0.1057), "stone_rustic": Color(0.2524, 0.182, 0.1122),
	"fabric_burlap": Color(0.2514, 0.2392, 0.1949), "rope": Color(0.204, 0.152, 0.0804),
}

## Authored material name -> [set, tile size in metres (object space), metallic cap, roughness scale].
const BY_NAME := {
	"GunSteel": ["steel_blued", 0.30, 0.62, 1.0],
	"CaseHard": ["steel_blued", 0.22, 0.62, 0.9],
	"Iron": ["iron_painted", 0.55, 0.30, 1.0],
	"Brass": ["brass_worn", 0.45, 0.58, 1.0],
	"ArmoryBrass": ["brass_worn", 0.55, 0.50, 1.0],
	"GunWood": ["wood_walnut", 0.40, 0.0, 0.85],
	"DarkWood": ["wood_dark", 0.90, 0.0, 1.0],
	"ArmoryOak": ["wood_dark", 1.00, 0.0, 1.0],
	"ArmoryOakDark": ["wood_dark", 1.00, 0.0, 1.0],
	"Planks": ["planks_weathered", 1.40, 0.0, 1.0],
	"Trim": ["planks_raw", 1.10, 0.0, 1.0],
	"Stone": ["stone_dressed", 1.30, 0.0, 1.0],
	"ArmoryStone": ["stone_rustic", 1.60, 0.0, 1.0],
	"ArmoryStoneLight": ["stone_rustic", 1.60, 0.0, 1.0],
	"Leather": ["leather_brown", 0.45, 0.0, 1.0],
	"Sand": ["fabric_burlap", 0.30, 0.0, 1.0],
	"Burlap": ["fabric_burlap", 0.30, 0.0, 1.0],
	"Rope": ["rope", 0.18, 0.0, 1.0],
	"Brick": ["brick_red", 1.20, 0.0, 1.0],
}

static var _mats: Dictionary = {}          # cache key -> StandardMaterial3D
static var _tex: Dictionary = {}           # path -> Texture2D


## True once the streamed PBR sets can be loaded (always on desktop / in tests; on the web after the extras pack mounted).
static func available() -> bool:
	return ResourceLoader.exists(DIR + "planks_weathered/albedo.jpg")


## The set a material name maps to ("" = not dressed).
static func set_for(material_name: String) -> String:
	var e: Variant = BY_NAME.get(_base_name(material_name))
	return str((e as Array)[0]) if e != null else ""


## A dressed material for `set_id` that keeps `authored` as its mean colour. `tile_m` = one texture repeat in metres (object space).
static func make(set_id: String, authored: Color, tile_m: float, metal_cap: float = 0.0, rough_scale: float = 1.0) -> StandardMaterial3D:
	var key: String = "%s|%s|%.3f|%.2f|%.2f" % [set_id, authored.to_html(), tile_m, metal_cap, rough_scale]
	if _mats.has(key):
		return _mats[key]
	var albedo: Texture2D = _load(set_id, "albedo")
	if albedo == null:
		return null
	var m := StandardMaterial3D.new()
	m.resource_name = "Pbr_%s" % set_id
	m.albedo_texture = albedo
	m.albedo_color = _tint(authored, MEAN.get(set_id, Color(0.5, 0.5, 0.5)))
	var nrm: Texture2D = _load(set_id, "normal")
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 1.0
	var orm: Texture2D = _load(set_id, "orm")
	if orm != null:
		m.ao_enabled = true
		m.ao_texture = orm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.25
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.roughness = clampf(rough_scale, 0.0, 1.0)
		if metal_cap > 0.0:
			m.metallic_texture = orm
			m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.metallic = metal_cap
	m.metallic_specular = 0.5
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false              # object space: the grain rides on moving parts and on duplicated buildings
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / maxf(tile_m, 0.01)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


## Dress every surface under `root` whose authored material is in BY_NAME (or `extra`, name -> [set, tile, metal, rough, colour?];
## the optional fifth entry replaces the authored colour - one prop's own tone, e.g. the Gatling's period bronze, without re-baking it).
## Uses per-instance surface override materials, so the imported (shared) meshes are never modified. Returns how many surfaces changed.
static func dress(root: Node, extra: Dictionary = {}, skip: Array = []) -> int:
	if root == null or not available():
		return 0
	var n: int = 0
	var nodes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for node in nodes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var cur: Material = mi.get_surface_override_material(si)
			if cur == null:
				cur = mi.mesh.surface_get_material(si)
			if not (cur is BaseMaterial3D):
				continue
			var base: String = _base_name(String(cur.resource_name))
			if base in skip:
				continue
			var spec: Variant = extra.get(base, BY_NAME.get(base))
			if spec == null:
				continue
			var s: Array = spec
			var bm := cur as BaseMaterial3D
			var tone: Color = s[4] if s.size() > 4 and s[4] is Color else bm.albedo_color
			var m: StandardMaterial3D = make(str(s[0]), tone, float(s[1]), float(s[2]) if s.size() > 2 else 0.0,
				float(s[3]) if s.size() > 3 else 1.0)
			if m == null:
				continue
			mi.set_surface_override_material(si, m)
			n += 1
	return n


## A flat material built in code (the hideout's _plain/_tex_mat palette) re-made as its PBR set, keeping its colour; null = keep the old.
static func replace(old: BaseMaterial3D, set_id: String, tile_m: float, metal_cap: float = 0.0, rough_scale: float = 1.0) -> StandardMaterial3D:
	if old == null or not available():
		return null
	return make(set_id, old.albedo_color, tile_m, metal_cap, rough_scale)


static func _tint(authored: Color, mean_linear: Color) -> Color:
	var a: Color = authored.srgb_to_linear()
	var t := Color(clampf(a.r / maxf(mean_linear.r, 0.004), 0.0, 3.0), clampf(a.g / maxf(mean_linear.g, 0.004), 0.0, 3.0),
		clampf(a.b / maxf(mean_linear.b, 0.004), 0.0, 3.0), authored.a)
	return t.linear_to_srgb()


static func _load(set_id: String, map: String) -> Texture2D:
	var path: String = "%s%s/%s.jpg" % [DIR, set_id, map]
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_tex[path] = t
	return t


## "Brass.001" / "Brass_2" from a re-import -> "Brass".
static func _base_name(n: String) -> String:
	var dot: int = n.find(".")
	if dot > 0:
		n = n.substr(0, dot)
	return n
