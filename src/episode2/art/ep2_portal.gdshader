// THE OPEN DOOR (founder 2026-10-24: "the door should be open and we should be able to see the elevator from within the smelting
// facility"). The hideout's doorway is a window into the mine lift room, which the session root already builds behind the hideout in
// its own world. That world's camera mirrors the player's camera (shifted by the fixed hideout -> lift offset), renders at screen size,
// and this quad shows the matching pixel of that image at every screen position - so the doorway shows exactly what stepping through
// will show. Unshaded and fog-free: the image is already lit and graded by the lift's own environment.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D portal_tex : source_color, filter_linear;
// Correction for the hideout's own grading that the Compatibility renderer applies to every material (measured, tools/ep2_shots/door_portal_shot.tscn).
uniform float gain = 1.0;

void fragment() {
	ALBEDO = texture(portal_tex, SCREEN_UV).rgb * gain;
}
