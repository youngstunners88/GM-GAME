shader_type spatial;
render_mode cull_disabled;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 float edge = 0.68 + 0.12 * sin(atan(p.y, p.x) * 7.0);
 ALBEDO = mix(vec3(0.025, 0.015, 0.008), vec3(0.21, 0.12, 0.045), smoothstep(0.38, edge, r));
 ROUGHNESS = 1.0;
 ALPHA = 1.0 - step(edge, r);
 ALPHA_SCISSOR_THRESHOLD = 0.5;
}
