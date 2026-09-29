shader_type spatial;
render_mode cull_disabled;
// Episode 2 gold crystals: the mesh's vertex colour runs dark root -> bright tip. Albedo keeps
// the root dark; emission is the colour SQUARED, so only the tips really glow (founder target
// 2026-09-29: crystals lit from inside, not flat yellow decals).
uniform float glow : hint_range(0.0, 4.0) = 1.7;
varying vec3 vcol;
void vertex() { vcol = COLOR.rgb; }
void fragment() {
	ALBEDO = vcol * 0.55;
	EMISSION = vcol * vcol * glow;
	ROUGHNESS = 0.22;
	METALLIC = 0.3;
}
