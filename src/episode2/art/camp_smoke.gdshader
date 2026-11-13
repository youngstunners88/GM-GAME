shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.90, 0.90, 0.88, 0.72);

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 back = normalize(cross(side, up));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * sx, 0.0), vec4(up * sy, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float rise = 1.0 - UV.y;
	float sway = sin(rise * 5.5 + TIME * 0.6) * 0.16 * rise;
	float width = mix(0.16, 0.92, rise);
	float d = abs((UV.x * 2.0 - 1.0) - sway) / width;
	float body = 1.0 - smoothstep(0.30, 1.0, d);
	float puffs = 0.62 + 0.38 * sin(rise * 21.0 - TIME * 2.1 + UV.x * 3.0) * sin(rise * 9.0 - TIME * 1.3);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * body * puffs * smoothstep(0.0, 0.06, rise) * (1.0 - smoothstep(0.5, 1.0, rise));
}
