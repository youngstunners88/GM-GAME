shader_type spatial;
uniform sampler2D sand : source_color,repeat_enable;
uniform sampler2D forest : source_color,repeat_enable;
uniform mat4 lake_inverse;
uniform bool lake_visible=false;
uniform bool has_forest=false;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 p=(lake_inverse*vec4(world,1.)).xyz;
 if(lake_visible && p.x>=-130. && p.x<=170. && p.z>=-100. && p.z<=210.)discard;
 vec3 dry=texture(sand,world.xz*.22).rgb*vec3(.92,.82,.66);
 // Founder 2026-11-01 ("there is still desert sand" at the lake): the desert sheds into grassland across the last few hundred
 // metres, measured from the lake's own centre, so water, banks and Logan's camp sit in green before the hand-over.
 float green=has_forest?1.-smoothstep(120.,340.,length(p.xz-vec2(51.,20.))):0.;
 vec3 grass=has_forest?texture(forest,world.xz*.20).rgb*vec3(.62,.86,.45):dry;
 ALBEDO=mix(dry,grass,green);ROUGHNESS=.97;
}
