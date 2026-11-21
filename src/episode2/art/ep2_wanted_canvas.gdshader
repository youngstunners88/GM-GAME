shader_type spatial;
render_mode cull_disabled;
uniform sampler2D poster : source_color, filter_linear_mipmap_anisotropic;
uniform float damage = 0.0;
void fragment() {
 vec4 bill = texture(poster, UV);
 vec2 cell = floor(UV * 42.0);
 float tear = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
 ALBEDO = bill.rgb;
 ROUGHNESS = 0.95;
 ALPHA = bill.a * step(damage, tear);
 ALPHA_SCISSOR_THRESHOLD = 0.5;
}
