shader_type canvas_item;
// Film frame dressing for Episode 2 cinematics (skill ep2-cinematic-cutscene): 2.39:1 letterbox, grade
// (saturation + warm/teal split), vignette, double vision, white flash, fade. One full-screen pass reading
// the screen texture - supported by the Compatibility (web) renderer.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float bars : hint_range(0.0, 1.0) = 0.0;       // 0 = none, 1 = full 2.39:1 letterbox
uniform float bar_h = 0.128;                            // bar height as a fraction of the frame (16:9 -> 2.39:1)
uniform float sat : hint_range(0.0, 2.0) = 1.0;
uniform float split_tone : hint_range(0.0, 1.0) = 0.35; // warm highlights / teal shadows (Modern Warfare grade)
uniform float vignette : hint_range(0.0, 1.5) = 0.25;
uniform float double_px = 0.0;                          // double-vision offset in pixels (concussion)
uniform float blur_px = 0.0;                            // cheap 4-tap blur radius in pixels
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;

vec3 tap(vec2 uv) {
	return texture(screen_tex, uv).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = tap(uv);
	if (blur_px > 0.0) {
		c = (c * 2.0 + tap(uv + vec2(blur_px, 0.0) * px) + tap(uv - vec2(blur_px, 0.0) * px)
			+ tap(uv + vec2(0.0, blur_px) * px) + tap(uv - vec2(0.0, blur_px) * px)) / 6.0;
	}
	if (double_px > 0.0) {
		c = mix(c, tap(uv + vec2(double_px, double_px * 0.35) * px), 0.42);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	vec3 warm = vec3(1.08, 0.98, 0.86);
	vec3 teal = vec3(0.86, 0.98, 1.06);
	c *= mix(vec3(1.0), mix(teal, warm, smoothstep(0.15, 0.6, l)), split_tone);
	vec2 d = uv - 0.5;
	c *= 1.0 - vignette * smoothstep(0.22, 0.85, length(d * vec2(1.35, 1.0)));
	c = mix(c, vec3(1.0), flash);
	c = mix(c, vec3(0.0), fade);
	float b = bar_h * bars;
	if (uv.y < b || uv.y > 1.0 - b) {
		c = vec3(0.0);
	}
	COLOR = vec4(c, 1.0);
}
