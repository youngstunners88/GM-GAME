shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float foam_strength = 0.15;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float trail=1.0-UV.y;
 float edge=abs(abs(p.x)-(0.12+trail*.75));
 float streak=exp(-edge*edge*650.0);
 float broken=.55+.45*sin(UV.y*60.0-TIME*3.5+p.x*17.0);
 ALBEDO=vec3(.49,.59,.53);
 ALPHA=streak*broken*foam_strength*smoothstep(0.0,.2,UV.y)*smoothstep(1.0,.70,UV.y);
}
