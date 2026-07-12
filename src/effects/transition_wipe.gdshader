shader_type canvas_item;
// Full-screen scene-transition wipe. progress 0 = clear, 1 = fully covered.
// pattern 0 = smoke dissolve (green/purple noise, the Smoke Realm signature);
// pattern 1 = diamond dissolve (crystalline grid, for boss victories).

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int pattern = 0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

void fragment() {
	float mask;
	vec3 tint;
	if (pattern == 0) {
		// Smoke: layered noise dissolve, tinted between weed-green and purple.
		mask = vnoise(UV * 7.0) * 0.65 + vnoise(UV * 29.0) * 0.35;
		tint = mix(vec3(0.16, 0.34, 0.20), vec3(0.30, 0.16, 0.40),
				vnoise(UV * 4.0 + progress));
	} else {
		// Diamond: manhattan-distance grid reads as shattering facets.
		vec2 cell = fract(UV * vec2(14.0, 8.0)) - 0.5;
		mask = (abs(cell.x) + abs(cell.y)) + vnoise(floor(UV * vec2(14.0, 8.0))) * 0.5;
		mask = clamp(mask * 0.8, 0.0, 1.0);
		tint = mix(vec3(0.10, 0.16, 0.28), vec3(0.35, 0.75, 0.9), mask);
	}
	float a = smoothstep(mask - 0.12, mask + 0.12, progress * 1.24);
	COLOR = vec4(tint, a);
}
