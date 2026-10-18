shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// The Episode 2 river (founder 2026-10-18): slow flowing water that reflects the gold-rush sky. Unshaded and procedural so it
// costs nothing in the web Compatibility renderer: a Fresnel blend between deep green-blue and the warm sky, rippled
// normals and drifting glints. No textures.

uniform vec3 deep_color : source_color = vec3(0.03, 0.17, 0.24);
uniform vec3 sky_color : source_color = vec3(0.56, 0.70, 0.84);
uniform float flow_speed = 0.45;
uniform float ripple_scale = 0.32;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float wave(vec2 p, float t) {
	return sin(p.x * 1.7 + t * 1.3) * 0.5 + sin(p.y * 2.3 - t * 1.1 + p.x * 0.6) * 0.3 + sin((p.x + p.y) * 4.1 + t * 2.2) * 0.2;
}

void fragment() {
	float t = TIME * flow_speed;
	vec2 p = wpos.xz * ripple_scale + vec2(-t * 0.6, 0.0);            // the whole sheet drifts along the river (-x)
	float e = 0.05;
	float hx = wave(p + vec2(e, 0.0), t) - wave(p - vec2(e, 0.0), t);
	float hz = wave(p + vec2(0.0, e), t) - wave(p - vec2(0.0, e), t);
	vec3 n = normalize(vec3(-hx * 3.0, 1.0, -hz * 3.0));
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 v = normalize(cam - wpos);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	vec3 col = mix(deep_color, sky_color, clamp(fres * 1.1 + 0.06, 0.0, 0.62));
	float glint = smoothstep(0.84, 1.0, wave(p * 2.2, t * 1.7));
	col += vec3(1.0, 0.86, 0.55) * glint * 0.7;           // sun glints, warm against the blue
	float edge = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);   // foamy, lighter banks
	col = mix(col + vec3(0.12, 0.12, 0.10), col, edge);
	ALBEDO = col;
}
