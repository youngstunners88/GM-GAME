shader_type spatial;
render_mode blend_mix, depth_draw_never;
uniform sampler2D sand_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D gravel_tex : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 survey_position;
void vertex() {
	survey_position=VERTEX;
}
void fragment() {
	vec2 p=survey_position.xz;
	vec3 sand=texture(sand_tex,p*.09).rgb;
	vec3 gravel=texture(gravel_tex,p*.42).rgb;
	float grain=texture(gravel_tex,p*.19).r;
	float shoulder=min(UV.x,1.-UV.x);
	float worn=smoothstep(.015+grain*.045,.10+grain*.045,shoulder);
	float ends=smoothstep(0.,.008,UV.y)*smoothstep(0.,.008,1.-UV.y);
	float ruts=exp(-pow((UV.x-.35)*32.,2.))+exp(-pow((UV.x-.65)*32.,2.));
	ALBEDO=mix(sand,gravel*.6+vec3(.2),.18)*vec3(.80,.59,.36)*(1.-ruts*.06);
	ROUGHNESS=.98;
	ALPHA=worn*ends;
}
