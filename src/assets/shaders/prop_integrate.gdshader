shader_type canvas_item;
// Colour-grades a painted prop toward its room's light so it reads as part of the
// painting instead of a game icon pasted on top. cell_v is the prop's v-range in the
// atlas so the ground-darken gradient follows the prop, not the whole sheet.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform vec2 cell_v = vec2(0.0, 0.5);
uniform float ground_darken = 0.28;
uniform float top_light = 0.10;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(lum), c.rgb, saturation);
	c.rgb = (c.rgb - 0.5) * contrast + 0.5;
	c.rgb *= tint.rgb;
	float t = clamp((UV.y - cell_v.x) / (cell_v.y - cell_v.x), 0.0, 1.0);
	c.rgb *= 1.0 - ground_darken * smoothstep(0.60, 0.95, t);
	c.rgb += top_light * (1.0 - smoothstep(0.10, 0.55, t)) * tint.rgb;
	COLOR = c;
}
