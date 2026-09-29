shader_type canvas_item;
// Soft projected shadow: the prop's own alpha, blurred, drawn black. No texture sheet
// of shadows is needed and it follows each prop's exact silhouette.
uniform float strength = 0.35;
uniform float blur = 5.0;

void fragment() {
	float a = 0.0;
	float w = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float k = 1.0 - length(vec2(float(x), float(y))) / 3.2;
			a += texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * blur * 0.5).a * k;
			w += k;
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, (a / w) * strength);
}
