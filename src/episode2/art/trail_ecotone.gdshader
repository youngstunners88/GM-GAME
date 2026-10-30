shader_type spatial;
uniform sampler2D sand : source_color, repeat_enable;
uniform sampler2D forest : source_color, repeat_enable;
uniform mat4 lake_inverse;
uniform bool lake_visible=false;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 p=(lake_inverse*vec4(world,1.)).xyz;
 if(lake_visible && p.x>=-130. && p.x<=170. && p.z>=-100. && p.z<=210.)discard;
 float blend=smoothstep(.28,.90,UV.y)*(1.-smoothstep(.55,1.,abs(UV.x*2.-1.)));
 vec3 dry=texture(sand,world.xz*.12).rgb*vec3(.74,.61,.43);
 vec3 green=texture(forest,world.xz*.20).rgb*vec3(.62,.86,.45);
 ALBEDO=mix(dry,green,blend);ROUGHNESS=.98;
}
