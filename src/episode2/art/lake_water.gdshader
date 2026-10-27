shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// Calm lake water for Compatibility: no screen-space reflection dependency.
// Reflected silhouettes use actual shoreline tree positions uploaded by the
// landscape builder. Fine normals replace the old broad white stripe pattern.
uniform vec3 sun_direction=vec3(.45,.6,.4);
uniform sampler2D branch_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 trees[16]; // world x,z,top height, crown radius
uniform int tree_count=0;
uniform bool boat_present=false;
uniform mat4 boat_inverse;
uniform float boat_half_width[18];
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float rim(float a){return 1.0+.038*sin(a*3.0+.4)+.020*sin(a*7.0-.6);}
void fragment(){
 if(boat_present){
  vec3 q=(boat_inverse*vec4(wp,1.0)).xyz;
  if(q.z> -1.7 && q.z<1.7){
   float section=(q.z+1.7)/.2;
   int i=clamp(int(floor(section)),0,16);
   float width=mix(boat_half_width[i],boat_half_width[i+1],fract(section));
   if(abs(q.x)<width){discard;}
  }
 }
 float t=TIME*.24;vec2 p=wp.xz;
 float sx=cos(p.x*.85+p.y*.22+t)*.022+cos(p.x*2.8-p.y*.65-t*1.8)*.007;
 float sz=cos(p.y*1.1-p.x*.27-t*.8)*.018+sin(p.y*3.7+p.x*.6+t*1.5)*.006;
 vec3 n=normalize(vec3(-sx,1.0,-sz));
 vec3 eye=(INV_VIEW_MATRIX*vec4(0,0,0,1)).xyz;vec3 v=normalize(eye-wp);vec3 r=reflect(-v,n);
 float fres=.035+.88*pow(1.0-clamp(dot(n,v),0.0,1.0),4.5);
 vec3 sky=mix(vec3(.32,.43,.43),vec3(.085,.19,.25),clamp(r.y*.85,0.0,1.0));
 float denom=max(.001,dot(r.xz,r.xz));
 for(int i=0;i<16;i++){
  if(i>=tree_count){break;}
  vec4 tr=trees[i];vec2 delta=tr.xy-wp.xz;float ray_t=dot(delta,r.xz)/denom;
  float y=wp.y+r.y*ray_t;float crown=clamp((tr.z-y)/(tr.z*.78),0.0,1.0)*tr.w;
  crown*=.83+.17*sin(y*8.0+tr.x*.4);
  float across=length(delta-r.xz*ray_t);
  if(ray_t>0.0&&y>.8&&y<tr.z&&across<crown){float mask=texture(branch_tex,vec2(clamp(across/max(crown,.01),0.0,1.0),1.0-clamp(y/tr.z,0.0,1.0))).a;sky=mix(sky,vec3(.026,.067,.049),.70*mask);}
 }
 vec2 q=vec2((p.x-24.0)/27.0,(p.y-20.0)/33.0);float rad=length(q)/rim(atan(q.y,q.x));
 float shallows=smoothstep(.76,1.07,rad);
 if(p.y>50.0){float mid=24.0+3.0*sin(max(0.0,p.y-51.0)*.05);float width=4.1+.5*sin(p.y*.09);shallows=smoothstep(width*.4,width,abs(p.x-mid));}
 vec3 depth=mix(vec3(.016,.073,.071),vec3(.075,.14,.106),shallows*.8);
 vec3 col=mix(depth,sky,clamp(fres,.0,.88));
 float shine=pow(max(0.0,dot(r,normalize(sun_direction))),420.0);
 col+=vec3(.78,.66,.43)*shine*.22;
 ALBEDO=col;
}
