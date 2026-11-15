class_name Ep2HorseCoat
extends RefCounted
## HORSE COAT COLOURS (founder 2026-11-15: "the horses at Dude are still all brown instead of the variation of colors I stated").
## One supplied horse model, one brown texture. A coat is a shader over the model's OWN texture: the texture's brightness (its shading, mane, eyes, hooves,
## muzzle) is kept and re-coloured, so a white horse still has dark eyes and a black one still shows its muzzle. Each horse gets its own material copies,
## so recolouring one never touches the others (the old yard shared one material, which is why every horse stayed brown).

const COATS: Dictionary = {
	"brown": {"tint": Color(1.0, 1.0, 1.0), "gain": 1.0, "keep_hue": true},
	"white": {"tint": Color(0.97, 0.96, 0.93), "gain": 2.7, "keep_hue": false},
	"black": {"tint": Color(0.62, 0.62, 0.66), "gain": 0.34, "keep_hue": false},
	"palomino": {"tint": Color(1.0, 0.82, 0.52), "gain": 2.3, "keep_hue": false},
}
## The order a yard hands them out (founder: white / brown / black or a mix), so every coat is on show at once.
const YARD_ORDER: Array = ["brown", "white", "black", "palomino", "black", "white", "brown", "palomino"]

const _SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float gain = 1.0;
uniform float keep_hue = 1.0;
uniform float rough = 0.85;
void fragment() {
	vec3 src = texture(albedo_tex, UV).rgb * base_color.rgb;
	float lum = dot(src, vec3(0.299, 0.587, 0.114));
	vec3 recoloured = vec3(lum) * tint.rgb * gain;
	ALBEDO = mix(recoloured, src * tint.rgb * gain, keep_hue);
	ROUGHNESS = rough;
}
"""
static var _shader: Shader = null


static func names() -> Array:
	return COATS.keys()


## Recolour `horse` (any node holding its meshes) to `coat`. Unknown names read as brown. Returns how many surfaces were recoloured.
static func apply(horse: Node, coat: String) -> int:
	if horse == null:
		return 0
	var spec: Dictionary = COATS.get(coat, COATS["brown"])
	if coat == "brown" or not COATS.has(coat):
		horse.set_meta("coat", "brown")        # the supplied look is the brown one: left exactly as it is
		return 0
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _SHADER
	var n: int = 0
	for mi in horse.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = mi
		if mesh_node.mesh == null:
			continue
		for s in mesh_node.mesh.get_surface_count():
			var src: Material = mesh_node.get_active_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = _shader
			var base := Color(1, 1, 1, 1)
			if src is BaseMaterial3D:
				var bm: BaseMaterial3D = src
				base = bm.albedo_color
				if bm.albedo_texture != null:
					mat.set_shader_parameter("albedo_tex", bm.albedo_texture)
				mat.set_shader_parameter("rough", bm.roughness)
			mat.set_shader_parameter("base_color", base)
			mat.set_shader_parameter("tint", spec["tint"])
			mat.set_shader_parameter("gain", float(spec["gain"]))
			mat.set_shader_parameter("keep_hue", 1.0 if bool(spec["keep_hue"]) else 0.0)
			mesh_node.set_surface_override_material(s, mat)
			n += 1
	horse.set_meta("coat", coat)
	return n


static func coat_of(horse: Node) -> String:
	return str(horse.get_meta("coat", "brown")) if horse != null else "brown"
