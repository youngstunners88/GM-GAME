// FOLIAGE IN THE WIND (founder 2026-10-10: "trees moving with the wind"; skill ep2-set-piece-forge).
// Alpha-cut cards (fir branches, ferns) that sway in the VERTEX shader, so a thousand MultiMesh instances cost nothing on the CPU and
// work in the Compatibility (web) renderer. The bend grows with height (`bend_height`, local units): the trunk end of a branch card
// stays put, the tip moves. A slow gust envelope (one wave crossing the wood every ~25 s) rides on a faster sway and a needle flutter.
// Every instance gets its own phase from its world position, so the wood never moves in lockstep.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.45;
uniform float sway = 0.35;          // metres of tip movement at full height
uniform float speed = 1.1;
uniform float bend_height = 40.0;   // local height at which the bend is full
uniform float flutter = 0.04;
uniform float roughness = 0.85;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;      // the instance's root: one phase per tree / fern
	float h = clamp(VERTEX.y / bend_height, 0.0, 1.0);
	float bend = h * h;
	float ph = wp.x * 0.13 + wp.z * 0.09;
	float gust = 0.55 + 0.45 * sin(TIME * 0.25 - wp.x * 0.015 - wp.z * 0.01);
	float s = sin(TIME * speed + ph) + 0.35 * sin(TIME * speed * 2.3 + ph * 1.7);
	VERTEX.x += s * sway * bend * gust;
	VERTEX.z += cos(TIME * speed * 0.8 + ph) * sway * 0.55 * bend * gust;
	VERTEX.y += sin(TIME * 5.0 + VERTEX.x * 3.0 + VERTEX.z * 2.0) * flutter * h;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = roughness;
}
