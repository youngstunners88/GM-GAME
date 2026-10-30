shader_type spatial;
uniform sampler2D sand : source_color,repeat_enable;
uniform mat4 lake_inverse;
uniform bool lake_visible=false;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 p=(lake_inverse*vec4(world,1.)).xyz;
 if(lake_visible && p.x>=-130. && p.x<=170. && p.z>=-100. && p.z<=210.)discard;
 ALBEDO=texture(sand,world.xz*.22).rgb*vec3(.92,.82,.66);ROUGHNESS=.97;
}
