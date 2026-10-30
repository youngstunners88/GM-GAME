// THE OPEN DOOR (founder 2026-10-24: "the door should be open and we should be able to see the elevator from within the smelting
// facility"). The hideout's doorway is a window into the mine lift room, which the session root already builds behind the hideout in
// its own world. That world's camera mirrors the player's camera (shifted by the fixed hideout -> lift offset), renders at screen size,
// and this quad shows the matching pixel of that image at every screen position - so the doorway shows exactly what stepping through
// will show. Unshaded and fog-free: the image is already lit and graded by the lift's own environment.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;

uniform sampler2D portal_tex : source_color, filter_linear;
// The viewport already contains its destination's final sRGB grade. Invert
// the forge's GLES3 output transform before it grades this material again.
uniform bool undo_forge_grade = false;
uniform float forge_brightness = 1.0;
uniform float forge_contrast = 1.0;
uniform float forge_exposure = 1.0;
uniform float forge_white = 6.0;

vec3 undo_filmic(vec3 y) {
	float w = forge_white;
	float white_curve = ((w*(.88*w+.06)+.002)/(w*(.88*w+.6)+.06))-.01/.3;
	vec3 t = y*white_curve+vec3(.01/.3);
	vec3 a = .88*(vec3(1.0)-t);
	vec3 b = .6*(vec3(.1)-t);
	vec3 c = .2*(vec3(.01)-.3*t);
	return (-b+sqrt(max(b*b-4.0*a*c,vec3(0.0))))/(2.0*a);
}
uniform sampler2D weapon_mask : hint_default_transparent, repeat_disable, filter_nearest;
// Preserve only the camera-held weapon's opaque self-occlusion. Nearby world
// geometry must be replaced by the destination, even when it is close to the eye.
// Correction for the hideout's own grading that the Compatibility renderer applies to every material (measured, tools/ep2_shots/door_portal_shot.tscn).
uniform float gain = 1.0;

void fragment() {
	if (texture(weapon_mask,SCREEN_UV).a>.01) {
		discard;
	}
	vec3 color = texture(portal_tex, SCREEN_UV).rgb;
	if (undo_forge_grade) {
		// Godot 4.3 GLES3: filmic -> linear_to_srgb -> brightness -> contrast.
		color = ((color-vec3(.5))/forge_contrast+vec3(.5))/forge_brightness;
		vec3 linear_color = pow(max((color+vec3(.055))/1.055,vec3(0.0)),vec3(2.4));
		// Compatibility converts ALBEDO from sRGB to linear in scene.glsl.
		vec3 input_linear = max(undo_filmic(linear_color)/forge_exposure,vec3(0.0));
		ALBEDO = max(1.055*pow(input_linear,vec3(1.0/2.4))-vec3(.055),vec3(0.0));
	} else {
		ALBEDO = color*gain;
	}
	ALPHA = 1.0; // after the opaque scene, so the depth texture includes the held weapon
}
