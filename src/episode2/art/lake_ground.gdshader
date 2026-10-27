shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D forest_floor : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 world_pos;
varying float slope;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;slope=1.0-abs(NORMAL.y);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=world_pos.xz;
 vec3 floor_col=texture(forest_floor,p*0.24).rgb;
 vec3 stone=texture(gravel_tex,p*0.35).rgb;
 float path=(1.0-smoothstep(.8,1.9,abs(p.x+8.0+sin(p.y*0.12)*0.25)))*(1.0-smoothstep(65.0,70.0,p.y));
 float wet=1.0-smoothstep(-0.18,0.08,world_pos.y);
 float patches=noise(p*0.13)*0.25;
 vec3 earthy=mix(floor_col*vec3(0.80,0.84,0.70),stone*vec3(0.48,0.39,0.27),clamp(path*0.68+wet*.6+slope*.65+patches,0.0,1.0));
 // Preserve colour variation at hill distance after detail textures mip out.
 float moss=smoothstep(.26,.68,noise(p*.075+vec2(19.3,4.7)))*(1.0-path*.75)*(1.0-wet*.65);
 earthy=mix(earthy,earthy*vec3(.48,.67,.37),.78*moss);
 earthy*=mix(.66,.90,noise(p*.041));
 ALBEDO=earthy*mix(1.0,0.55,wet);
 ROUGHNESS=mix(0.94,0.65,wet);
 NORMAL_MAP=texture(gravel_normal,p*0.35).rgb;
 NORMAL_MAP_DEPTH=mix(.18,.38,path);
}
