shader_type spatial;
uniform sampler2D sand : source_color,repeat_enable;
uniform sampler2D forest : source_color,repeat_enable;
uniform mat4 lake_inverse;
uniform bool lake_visible=false;
uniform bool has_forest=false;
uniform vec2 approach_dir=vec2(0.,0.);   // in the lake's axes: unit vector from the lake back up the trail
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 p=(lake_inverse*vec4(world,1.)).xyz;
 if(lake_visible && p.x>=-130. && p.x<=170. && p.z>=-100. && p.z<=210.)discard;
 vec3 dry=texture(sand,world.xz*.22).rgb*vec3(.92,.82,.66);
 // Founder 2026-11-01 ("there is still desert sand" at the lake): the desert sheds into grassland across the last few hundred
 // metres, measured from the lake's own centre, so water, banks and Logan's camp sit in green before the hand-over.
 // Founder 2026-11-04: only the way he has come is desert. Off to the sides and past the lake the green carries on, so no sand on the far horizon.
 vec2 from_lake=p.xz-vec2(51.,20.);
 float toward_desert=dot(normalize(from_lake+vec2(.0001)),approach_dir);
 float reach=mix(1100.,340.,smoothstep(.25,.8,toward_desert));
 float green=has_forest?1.-smoothstep(reach-220.,reach,length(from_lake)):0.;
 vec3 grass=has_forest?texture(forest,world.xz*.20).rgb*vec3(.62,.86,.45):dry;
 ALBEDO=mix(dry,grass,green);ROUGHNESS=.97;
 SPECULAR=mix(.5,.06,green);   // grass does not glare toward the low sun (lake_ground): the same green on both sides of the lake's edge
}
