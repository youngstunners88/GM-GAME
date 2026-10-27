shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color=vec4(.82,.94,.78,1);
uniform float bend_height=12.0;
uniform float sway=.10;
varying vec4 instance_tone;
void vertex(){
 vec3 root=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
 float h=clamp(VERTEX.y/bend_height,0.0,1.0);
 float phase=root.x*.23+root.z*.13;
 VERTEX.x+=sin(TIME*.8+phase)*sway*h*h;
 VERTEX.z+=cos(TIME*.67+phase)*sway*.65*h*h;
 instance_tone=COLOR;
}
void fragment(){
 vec4 c=texture(albedo_tex,UV);
 ALBEDO=c.rgb*tint.rgb*instance_tone.rgb;
 ALPHA=c.a;ALPHA_SCISSOR_THRESHOLD=.30;
 ROUGHNESS=.92;
 BACKLIGHT=c.rgb*.12;
}
