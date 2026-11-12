shader_type spatial;
uniform sampler2D sand : source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D forest : source_color,repeat_enable;
uniform mat4 lake_inverse;
uniform bool lake_visible=false;
uniform bool has_forest=false;
uniform sampler2D relief:hint_normal,repeat_enable;
uniform bool has_relief=false;
uniform vec2 approach_dir=vec2(0.,0.);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 p=(lake_inverse*vec4(world,1.)).xyz;
 if(lake_visible && p.x>=-130. && p.x<=170. && p.z>=-100. && p.z<=210.)discard;
 vec3 dry=texture(sand,world.xz*.22).rgb*vec3(.92,.82,.66);
 vec2 from_lake=p.xz-vec2(51.,20.);
 float toward_desert=dot(normalize(from_lake+vec2(.0001)),approach_dir);
 float reach=mix(1100.,340.,smoothstep(.25,.8,toward_desert));
 float green=has_forest?1.-smoothstep(reach-220.,reach,length(from_lake)):0.;
 vec3 grass=has_forest?texture(forest,world.xz*.20).rgb*vec3(.62,.86,.45):dry;
 ALBEDO=mix(dry,grass,green);ROUGHNESS=.97;
 if(has_relief)NORMAL_MAP=mix(texture(relief,world.xz*.22).rgb,vec3(.5,.5,1.),green);
 SPECULAR=mix(.5,.06,green);
}
