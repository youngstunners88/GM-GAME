shader_type canvas_item;
// Procedural drifting-smoke backdrop for the Smoke Lounge — a "living
// background" alternative to a looping video: continuous (no loop seam to
// hide), a few bytes on disk instead of megabytes, and no video decoder
// overhead on the non-threaded HTML5 export. Two independently-drifting FBM
// layers plus a slow color breathe read as haze curling in real time behind
// the painted parallax layers, matching the Smoke Lounge's purple-grey palette
// (secret_realm.gd COLOR_SMOKE_NEAR / COLOR_SMOKE_MID / COLOR_PLATFORM_BODY).

uniform vec4 color_void : source_color = vec4(0.06, 0.04, 0.10, 1.0);
uniform vec4 color_mid : source_color = vec4(0.420, 0.357, 0.478, 1.0);
uniform vec4 color_near : source_color = vec4(0.176, 0.106, 0.306, 1.0);
uniform float drift_speed : hint_range(0.0, 0.5) = 0.05;

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = _hash(i);
	float b = _hash(i + vec2(1.0, 0.0));
	float c = _hash(i + vec2(0.0, 1.0));
	float d = _hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float _fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * _noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	float t = TIME * drift_speed;
	vec2 p1 = UV * 3.0 + vec2(t * 0.6, -t * 0.3);
	vec2 p2 = UV * 5.0 + vec2(-t * 0.4, t * 0.5);
	float smoke1 = _fbm(p1);
	float smoke2 = _fbm(p2);
	float mixed = clamp(smoke1 * 0.6 + smoke2 * 0.4, 0.0, 1.0);

	float breathe = 0.5 + 0.5 * sin(TIME * 0.15);
	vec4 base = mix(color_void, color_mid, mixed);
	base = mix(base, color_near, breathe * 0.25);

	COLOR = base;
}
