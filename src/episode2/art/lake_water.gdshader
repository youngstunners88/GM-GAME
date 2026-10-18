shader_type spatial;
render_mode unshaded, cull_disabled;
// The surface-approach lake (Ep2SurfaceSet): a flat sheet that reads as water by colour alone.
// Deep blue-teal looking down, lifting toward a cool sky blue at grazing angles (a lake's fresnel, capped so it never washes out
// to grey), with slow warm sun glints and soft broad light/dark bands for depth.
// Unshaded on purpose: the web Compatibility renderer has no reflections, and the desert grade already sets the mood.
// The plane's UV edge fades out so the shore is soft over the sand plane under it.

uniform vec3 deep_col : source_color = vec3(0.05, 0.22, 0.34);
uniform vec3 sky_col : source_color = vec3(0.40, 0.60, 0.70);
uniform vec3 glint_col : source_color = vec3(1.0, 0.90, 0.66);
uniform float shore_fade : hint_range(0.001, 0.2) = 0.045;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float ripple = sin(wpos.x * 0.42 + TIME * 0.7) * sin(wpos.z * 0.55 - TIME * 0.5);
	float far_k = 1.0 - smoothstep(70.0, 260.0, length(VERTEX));
	float g = pow(max(0.0, ripple), 14.0) * (0.3 + 0.7 * f) * far_k;
	vec3 c = mix(deep_col, sky_col, clamp(f * 0.6 + 0.10, 0.0, 0.62));
	c *= 0.9 + 0.1 * sin(wpos.x * 0.07 + sin(wpos.z * 0.045) * 2.2 + TIME * 0.15);
	c += glint_col * g * 0.7;
	ALBEDO = c;
	float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	ALPHA = smoothstep(0.0, shore_fade, e);
}
