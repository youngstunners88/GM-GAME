shader_type spatial;
// The open ground past Logan's Lake on the road to the auction (founder 2026-11-22: no teleport - one world). Where the lake's own terrain
// ends the land is still the lake's grass; it dries to the road's earth further out. The planes are built in the LAKE's frame (their mesh
// is offset, the node sits at the frame's origin), so the same material reads right in the road room and in the lake's look ahead.
uniform sampler2D dry : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D forest : source_color, repeat_enable, filter_linear_mipmap;
uniform bool has_dry = false;
uniform vec4 dry_tint : source_color = vec4(0.62, 0.50, 0.34, 1.0);
uniform float dry_tile = 8.0;
uniform float green_to = 150.0;     // metres from the lake's centre: grass to here
uniform float dry_from = 290.0;     // ...the road's dry earth from here
varying vec3 lake;
void vertex() { lake = VERTEX; }
void fragment() {
	float k = smoothstep(green_to, dry_from, length(lake.xz - vec2(51.0, 20.0)));
	vec3 grass = texture(forest, lake.xz * 0.24).rgb * vec3(0.46, 0.92, 0.30) * 0.86;
	vec3 earth = has_dry ? texture(dry, lake.xz / dry_tile).rgb * dry_tint.rgb : dry_tint.rgb;
	ALBEDO = mix(grass, earth, k);
	ROUGHNESS = 0.97;
	SPECULAR = mix(0.06, 0.4, k);
}
