shader_type canvas_item;
// Full-screen scene-transition wipe. progress 0 = clear, 1 = fully covered.
// pattern 0 = smoke dissolve (green/purple noise, the Smoke Realm signature);
// pattern 1 = diamond dissolve (crystalline grid, for boss victories and the
//             Crystal Caverns' own Blaze Rush — cyan matches its palette);
// pattern 2 = gold dissolve (warm ember/dust grid, for the Gold Rush realm).

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int pattern = 0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

void fragment() {
	float mask;
	vec3 tint;
	if (pattern == 0) {
		// Smoke: layered noise dissolve, tinted between weed-green and purple.
		mask = vnoise(UV * 7.0) * 0.65 + vnoise(UV * 29.0) * 0.35;
		tint = mix(vec3(0.16, 0.34, 0.20), vec3(0.30, 0.16, 0.40),
				vnoise(UV * 4.0 + progress));
	} else if (pattern == 1) {
		// Diamond: manhattan-distance grid reads as shattering facets.
		vec2 cell = fract(UV * vec2(14.0, 8.0)) - 0.5;
		mask = (abs(cell.x) + abs(cell.y)) + vnoise(floor(UV * vec2(14.0, 8.0))) * 0.5;
		mask = clamp(mask * 0.8, 0.0, 1.0);
		tint = mix(vec3(0.10, 0.16, 0.28), vec3(0.35, 0.75, 0.9), mask);
	} else {
		// Gold: same layered noise dissolve as smoke, tinted amber/ember
		// instead of green/purple — the Gold Rush realm's own palette
		// (bg_l3_goldrush's canyon, the gold coin trail, the FORT KNOX vault
		// gold lip already used throughout Stage 3). Founder, 2026-09-17:
		// entering/exiting Blaze Rush used the SMOKE pattern for every realm
		// regardless of theme, so a green/purple swamp-cloud wipe flashed
		// over the cyan Crystal Caverns and the amber Gold Rush canyon alike
		// — read as "green blemish shit" / "smudged" because it visually
		// clashes with the scene it's covering, not because anything is
		// stuck or leaking. Diamond (cyan) already existed and fits Crystal
		// Caverns; this adds the missing warm match for Gold Rush.
		mask = vnoise(UV * 7.0) * 0.65 + vnoise(UV * 29.0) * 0.35;
		tint = mix(vec3(0.32, 0.20, 0.06), vec3(0.85, 0.55, 0.15),
				vnoise(UV * 4.0 + progress));
	}
	float a = smoothstep(mask - 0.12, mask + 0.12, progress * 1.24);
	// IDLE MUST BE INVISIBLE. At progress = 0 the smoothstep above is NOT zero
	// wherever mask < 0.12 (edge0 goes negative), so the "clear" overlay painted
	// permanent dark green/purple smoke blobs at fixed screen positions, up to
	// 50% alpha, on EVERY screen - this node is an autoload CanvasLayer that sits
	// in front of the menu, every level and every Blaze Rush. The blob positions
	// come from a sin()-hash whose output is GPU-precision dependent, so they
	// landed in the founder's sky on his GPU and under the HUD on the capture
	// bot's software renderer - which is why a month of captures looked clean.
	// These were "the green smudges": founder 2026-08-20 .. 2026-09-23.
	a *= step(0.001, progress);
	COLOR = vec4(tint, a);
}
