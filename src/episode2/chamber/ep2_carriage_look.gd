class_name Ep2CarriageLook
extends RefCounted
## The visitor carriages' real materials and the teams' harness (founder brief 2026-11-23 "option 5": big and exuberant, but expensive and
## hand-made, gold that is METAL reflecting the sunset, nothing glowing, horses hitched in proper harness, not fused into the carriage).
##
## The hand-built GLBs (tools/ep2_blender/build_visitor_carriages.py) carry material NAMES and a COLOR_0 of baked occlusion + red-ground
## dust; `dress` gives every named surface its PBR look here, so no texture files ride in the pack. `hitch_team` puts the rigged town horse
## on each Hitch_<i>_<kind> empty, coats it, pins the harness kit (build_visitor_harness.py) to its skeleton as ONE skinned mesh, and
## starts a slow idle offset per horse so no two move together.

const HARNESS_KIT := "res://src/episode2/extras/auction/visitors/visitor_harness.glb"
## Metals stay part-diffuse: the road room's dusk sky radiance (32 px, dark top) cannot light a fully metallic surface in the web
## renderer, which reads near-black; 0.55-0.6 keeps the metal highlights and still reads as gold leaf.
## name -> [albedo, metallic, roughness, texture ("grain" | "mottle" | ""), texture strength]
const LOOKS := {
	"Gilt": [Color(1.0, 0.77, 0.36), 0.6, 0.27, "mottle", 0.25],
	"Brass": [Color(0.95, 0.73, 0.42), 0.55, 0.34, "mottle", 0.25],
	"Lacquer": [Color(0.016, 0.016, 0.02), 0.0, 0.1, "", 0.0],
	"RedPaint": [Color(0.66, 0.08, 0.05), 0.0, 0.32, "mottle", 0.2],
	"WoodWeathered": [Color(0.72, 0.6, 0.46), 0.0, 0.86, "grain", 0.55],
	"WoodOiled": [Color(0.38, 0.22, 0.1), 0.0, 0.55, "grain", 0.45],
	"Iron": [Color(0.22, 0.21, 0.2), 0.5, 0.55, "mottle", 0.35],
	"Leather": [Color(0.2, 0.1, 0.05), 0.0, 0.55, "mottle", 0.3],
	"BlackLeather": [Color(0.035, 0.03, 0.028), 0.0, 0.36, "mottle", 0.2],
	"Velvet": [Color(0.5, 0.03, 0.06), 0.0, 0.95, "mottle", 0.15],
	"Glass": [Color(0.12, 0.14, 0.16, 0.3), 0.0, 0.04, "", 0.0],
	"Canvas": [Color(0.8, 0.73, 0.6), 0.0, 0.95, "mottle", 0.35],
	"Carpet": [Color(0.55, 0.035, 0.05), 0.0, 1.0, "mottle", 0.2],
	"Plume": [Color(0.96, 0.94, 0.9), 0.0, 1.0, "", 0.0],
	"PlumeRed": [Color(0.66, 0.04, 0.05), 0.0, 1.0, "", 0.0],
	"Rope": [Color(0.62, 0.52, 0.36), 0.0, 0.95, "grain", 0.4],
}
## Polished finishes reflect the SUNSET itself: a view-dependent reflection of the road room's dusk (red ground, orange horizon, blue
## overhead) times the finish colour, darkened in the recesses by the baked occlusion. The web renderer's 32 px sky radiance blurs to a
## dim brown and leaves metal near-black, which is why the reflection is computed here. Gilt/brass reflect at every angle (metal);
## lacquer, paint, patent leather and glass only toward grazing angles (Fresnel).
## name -> [reflect tint, strength, base reflectance (1 = metal), roughness, metallic, alpha]
const POLISH := {
	"Gilt": [Color(1.0, 0.76, 0.34), 0.95, 1.0, 0.28, 0.6, 1.0],
	"Brass": [Color(0.95, 0.72, 0.4), 0.7, 1.0, 0.34, 0.55, 1.0],
	"Lacquer": [Color(1, 1, 1), 1.0, 0.06, 0.08, 0.0, 1.0],
	"RedPaint": [Color(1, 0.85, 0.8), 0.7, 0.05, 0.3, 0.0, 1.0],
	"BlackLeather": [Color(1, 1, 1), 0.5, 0.04, 0.34, 0.0, 1.0],
	"Glass": [Color(1, 1, 1), 1.0, 0.12, 0.03, 0.0, 0.3],
}
const _POLISH_SHADER := """
shader_type spatial;
render_mode %s;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.8;
uniform float base_refl = 1.0;
uniform float rough = 0.3;
uniform float metal = 0.6;
uniform float alpha = 1.0;
varying vec3 w_n;
varying vec3 w_p;
void vertex() {
	w_n = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	w_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
vec3 dusk(vec3 r) {
	vec3 ground = vec3(0.46, 0.24, 0.13);
	vec3 horizon = vec3(1.0, 0.6, 0.3);
	vec3 sky = vec3(0.2, 0.26, 0.46);
	if (r.y < 0.0) {
		return mix(horizon * 0.85, ground, smoothstep(0.0, 0.35, -r.y));
	}
	return mix(horizon, sky, smoothstep(0.02, 0.5, r.y));
}
void fragment() {
	vec3 n = normalize(w_n);
	if (!FRONT_FACING) { n = -n; }
	vec3 v = normalize(CAMERA_POSITION_WORLD - w_p);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	float fres = base_refl + (1.0 - base_refl) * pow(1.0 - ndv, 5.0);
	float ao = COLOR.r;
	ALBEDO = albedo.rgb * COLOR.rgb;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = dusk(reflect(-v, n)) * tint.rgb * strength * fres * ao * ao;
	%s
}
"""
## Royal teams wear black patent leather with gilt fittings and plumes.
const ROYAL_SWAP := {"Leather": "BlackLeather", "Brass": "Gilt"}

static var _mats: Dictionary = {}
static var _tex: Dictionary = {}
static var _harness: Dictionary = {}          # "royal:lead" -> [ArrayMesh, Skin]


static func _texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := FastNoiseLite.new()
	n.seed = 1123 if kind == "grain" else 77
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02 if kind == "grain" else 0.05
	n.fractal_octaves = 4
	var img: Image = n.get_seamless_image(128, 128, false, false, 0.1, true)
	img.convert(Image.FORMAT_RGB8)
	if kind == "grain":                         # long streaks: squash across, stretch along
		img.resize(32, 128, Image.INTERPOLATE_BILINEAR)
		img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	for y in img.get_height():
		for x in img.get_width():
			var v: float = img.get_pixel(x, y).r
			var g: float = 0.72 + 0.4 * v
			img.set_pixel(x, y, Color(g, g, g))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## The shared material for a name (null for names this look does not know).
static func material(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m: BaseMaterial3D = null
	if name == "Shadow":
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.0, 0.0, 0.0, 0.62)
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		m.albedo_texture = g
		m.render_priority = -1
	elif POLISH.has(name):
		var p: Array = POLISH[name]
		var glass: bool = name == "Glass"
		var sh := Shader.new()
		sh.code = _POLISH_SHADER % ["blend_mix, cull_disabled, depth_draw_opaque" if glass else "blend_mix, cull_back",
			"ALPHA = clamp(alpha + fres * 0.6, 0.0, 1.0);" if glass else ""]
		var sm := ShaderMaterial.new()
		sm.shader = sh
		var spec: Array = LOOKS[name]
		sm.set_shader_parameter("albedo", spec[0])
		sm.set_shader_parameter("tint", p[0])
		sm.set_shader_parameter("strength", float(p[1]))
		sm.set_shader_parameter("base_refl", float(p[2]))
		sm.set_shader_parameter("rough", float(p[3]))
		sm.set_shader_parameter("metal", float(p[4]))
		sm.set_shader_parameter("alpha", float(p[5]))
		_mats[name] = sm
		return sm
	elif LOOKS.has(name):
		var spec: Array = LOOKS[name]
		m = StandardMaterial3D.new()
		m.albedo_color = spec[0]
		m.metallic = float(spec[1])
		m.metallic_specular = 0.6
		m.roughness = float(spec[2])
		m.vertex_color_use_as_albedo = true
		if str(spec[3]) != "":
			var t: Texture2D = _texture(str(spec[3]))
			var k: float = float(spec[4])
			m.albedo_texture = t
			m.albedo_color = Color(m.albedo_color.r * (1.0 - k * 0.35), m.albedo_color.g * (1.0 - k * 0.35), m.albedo_color.b * (1.0 - k * 0.35), m.albedo_color.a)
			m.roughness_texture = t
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(2.5, 2.5, 2.5) if str(spec[3]) == "grain" else Vector3(1.5, 1.5, 1.5)
		if name == "Glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic_specular = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.vertex_color_use_as_albedo = false
		elif name in ["Plume", "PlumeRed"]:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		elif name == "Velvet":
			m.rim_enabled = true
			m.rim = 0.6
			m.rim_tint = 0.4
		elif name == "Lacquer":
			m.metallic_specular = 0.9
	_mats[name] = m
	return m


static func _mat_name(src: Material) -> String:
	return src.resource_name if src != null else ""


## Give every surface under `root` its look by material name. Returns how many surfaces were dressed.
static func dress(root: Node, swap: Dictionary = {}) -> int:
	var n: int = 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var node: MeshInstance3D = mi
		if node.mesh == null:
			continue
		for s in node.mesh.get_surface_count():
			var name: String = _mat_name(node.mesh.surface_get_material(s))
			name = str(swap.get(name, name))
			var m: Material = material(name)
			if m != null:
				node.set_surface_override_material(s, m)
				n += 1
	return n


static func _xf_in(ancestor: Node, node: Node) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = node
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## One skinned mesh holding the whole harness for this skeleton layout, cached per (royal, lead): each part rides its own bone.
static func harness_mesh(model: Node3D, skel: Skeleton3D, royal: bool, lead: bool) -> Array:
	var key: String = "%s:%s" % [royal, lead]
	if _harness.has(key):
		return _harness[key]
	if not ResourceLoader.exists(HARNESS_KIT):
		return []
	var kit: Node = (load(HARNESS_KIT) as PackedScene).instantiate()
	var skel_from_model: Transform3D = _xf_in(model, skel).affine_inverse()
	var by_mat: Dictionary = {}                  # material name -> [verts, normals, bones, weights, indices]
	var used: Dictionary = {}
	for mi in kit.find_children("Harness_*", "MeshInstance3D", true, false):
		var node: MeshInstance3D = mi
		var nm: String = str(node.name)
		if nm.contains("plume") and not royal:
			continue
		if nm.contains("traces") and nm.contains("lead") != lead:     # the wheelers' set imports as "Harness_root_traces"
			continue
		var bone: String = nm.split("_")[1]
		var bi: int = skel.find_bone(bone)
		if bi < 0 or node.mesh == null:
			continue
		used[bi] = true
		var xf: Transform3D = skel_from_model * _xf_in(kit, node)
		for s in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(s)
			var mname: String = _mat_name(node.mesh.surface_get_material(s))
			if royal:
				mname = str(ROYAL_SWAP.get(mname, mname))
			if not by_mat.has(mname):
				by_mat[mname] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array(), PackedFloat32Array(), PackedInt32Array()]
			var acc: Array = by_mat[mname]
			var pv: PackedVector3Array = acc[0]
			var pn: PackedVector3Array = acc[1]
			var pb: PackedInt32Array = acc[2]
			var pw: PackedFloat32Array = acc[3]
			var pi: PackedInt32Array = acc[4]
			var base: int = pv.size()
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in vs.size():
				pv.append(xf * vs[i])
				pn.append((xf.basis * ns[i]).normalized())
				pb.append_array(PackedInt32Array([bi, 0, 0, 0]))
				pw.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in idx.size():
				pi.append(base + idx[i])
			by_mat[mname] = [pv, pn, pb, pw, pi]          # packed arrays are values: store the grown copies back
	kit.free()
	var mesh := ArrayMesh.new()
	for mname in by_mat.keys():
		var acc: Array = by_mat[mname]
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = acc[0]
		arr[Mesh.ARRAY_NORMAL] = acc[1]
		arr[Mesh.ARRAY_BONES] = acc[2]
		arr[Mesh.ARRAY_WEIGHTS] = acc[3]
		arr[Mesh.ARRAY_INDEX] = acc[4]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(str(mname)))
		mesh.surface_set_name(mesh.get_surface_count() - 1, str(mname))
	var skin := Skin.new()
	for bi in skel.get_bone_count():
		skin.add_bind(bi, skel.get_bone_global_rest(bi).affine_inverse())
	_harness[key] = [mesh, skin]
	return _harness[key]


## Hitch the rigged town horse on every Hitch_<i>_<kind> empty of `rig` (already in the tree). Returns the horses (team order).
static func hitch_team(rig: Node3D, horse_scene: PackedScene, coats: Array, royal: bool) -> Array:
	var horses: Array = []
	if horse_scene == null:
		return horses
	var marks: Array = rig.find_children("Hitch_*", "Node3D", true, false)
	marks.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	for i in marks.size():
		var mark: Node3D = marks[i]
		var lead: bool = str(mark.name).ends_with("lead")
		var h := Node3D.new()
		h.name = "TeamHorse%d" % i
		var m: Node3D = horse_scene.instantiate() as Node3D
		m.rotation.y = -PI * 0.5                     # the model's head is +X; the carriage's horses face +Z
		h.add_child(m)
		rig.add_child(h)
		h.transform = Transform3D(Basis(), _xf_in(rig, mark).origin)
		Ep2HorseCoat.apply(h, str(coats[i % coats.size()]))
		var sks: Array = m.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			var skel: Skeleton3D = sks[0]
			var made: Array = harness_mesh(m, skel, royal, lead)
			if not made.is_empty():
				var hm := MeshInstance3D.new()
				hm.name = "Harness"
				hm.mesh = made[0]
				hm.skin = made[1]
				skel.add_child(hm)
				hm.skeleton = NodePath("..")
		for ap in m.find_children("*", "AnimationPlayer", true, false):
			var player: AnimationPlayer = ap
			if player.has_animation("horse_stand"):
				player.play("horse_stand")
				var length: float = player.get_animation("horse_stand").length
				player.seek(fmod(0.61 * float(i + 1) + 0.23 * float(str(rig.name).length()), maxf(length, 0.1)), true)
				player.speed_scale = 0.8 + 0.07 * float((i * 5 + 3) % 5)
		h.set_meta("lead", lead)
		horses.append(h)
	return horses
