shader_type canvas_item;
// Constantly flowing smoke over the title-screen key art.
//
// Same hash / value-noise / FBM as smoke_lounge_ambient.gdshader, which is
// already proven on the non-threaded HTML5 export, but TRANSPARENT: that shader
// paints an opaque backdrop, this one only paints wisps and leaves clear gaps so
// the founder's key art shows through.
//
// Why a shader and not more particles: particles are separate dots that rise in
// lines; they never read as one continuous body of smoke however they are tuned.
// Domain-warped FBM (noise fed through noise) curls and folds like real smoke,
// never loops or repeats, costs a few bytes on disk, and runs every frame for as
// long as the menu is open.

uniform vec4 smoke_color : source_color = vec4(0.88, 0.94, 0.90, 1.0);
// Peak opacity of the thickest wisps. Gaps between wisps stay fully clear.
uniform float intensity : hint_range(0.0, 1.0) = 0.58;
// How fast the smoke rises and curls.
uniform float flow_speed : hint_range(0.0, 0.5) = 0.07;
// Size of the smoke structures; lower = bigger, softer billows.
uniform float scale : hint_range(0.5, 8.0) = 2.4;
// Screen aspect so billows are round, not stretched on 16:9.
uniform float aspect = 1.78;

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
	float t = TIME * flow_speed;
	vec2 uv = UV * vec2(scale * aspect, scale);

	// Domain warp, two levels deep: that is what makes the smoke curl and fold
	// instead of sliding past as a flat texture. The +t on y moves the pattern
	// UP the screen (UV.y grows downward), so the smoke rises.
	vec2 q = vec2(
		_fbm(uv + vec2(0.0, t * 2.0)),
		_fbm(uv + vec2(5.2, 1.3) + vec2(t * 0.6, t * 1.7)));
	vec2 r = vec2(
		_fbm(uv + 3.0 * q + vec2(1.7, 9.2) + vec2(t * 0.4, t * 1.3)),
		_fbm(uv + 3.0 * q + vec2(8.3, 2.8) + vec2(-t * 0.3, t * 1.5)));
	float f = _fbm(uv + 2.5 * r);

	// Only the upper band of the noise becomes smoke, so it forms wisps with
	// clear air between them rather than an even grey fog over the art.
	float wisp = smoothstep(0.36, 0.74, f);

	// Thicker near the floor, thinning as it rises: smoke coming up from below.
	float rise = mix(0.45, 1.0, UV.y);

	COLOR = vec4(smoke_color.rgb, wisp * rise * intensity);
}
