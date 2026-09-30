shader_type spatial;
render_mode unshaded, cull_disabled;
// Molten gold running in a channel (Smelting Facility). Two scrolling value-noise layers: bright gold veins
// on a deep orange melt, with a slow crust. Unshaded + emissive-looking so it IS the room's light source.
// Compatibility-renderer safe (no screen/depth reads).

uniform vec3 hot = vec3(1.0, 0.82, 0.32);
uniform vec3 melt = vec3(0.95, 0.38, 0.06);
uniform vec3 crust = vec3(0.22, 0.07, 0.02);
uniform float speed = 0.35;
uniform float scale = 2.4;
uniform float energy = 2.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * vec2(scale * 6.0, scale);
	float t = TIME * speed;
	float n1 = vnoise(uv + vec2(t * 2.0, 0.0));
	float n2 = vnoise(uv * 2.3 - vec2(t * 3.1, t * 0.4));
	float veins = smoothstep(0.55, 0.95, n1 * 0.6 + n2 * 0.5);
	float crusted = smoothstep(0.62, 0.85, vnoise(uv * 0.7 + vec2(t * 0.6, 3.0)));
	vec3 c = mix(melt, hot, veins);
	c = mix(c, crust, crusted * 0.7);
	ALBEDO = c * energy;
}
