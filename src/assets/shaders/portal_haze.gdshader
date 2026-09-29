shader_type canvas_item;
// Neutral drifting haze for the portal rooms. Domain-warped value-noise FBM, alpha
// only, so the painting shows through the gaps. Colours are set per room and are never
// green-dominant (blotch rule: no soft green washes over the art).
uniform vec4 haze_color : source_color = vec4(0.84, 0.80, 0.92, 1.0);
uniform float density = 0.30;
uniform vec2 drift = vec2(0.035, -0.006);
uniform float scale = 3.0;
uniform float aspect = 2.5;
uniform float low_cut = 0.40;
uniform float high_cut = 0.80;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 uv = UV * vec2(scale * aspect, scale);
	vec2 q = vec2(fbm(uv + TIME * drift * 9.0), fbm(uv + vec2(5.2, 1.3) - TIME * drift * 7.0));
	float f = fbm(uv + 2.0 * q + TIME * drift * 12.0);
	float wisp = smoothstep(low_cut, high_cut, f);
	COLOR = vec4(haze_color.rgb, wisp * density);
}
