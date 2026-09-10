class_name Ep2Palette
extends RefCounted
## Episode 2 (Gold Mine) — the single source of truth for surface look.
##
## WHY THIS FILE EXISTS
## Episode 2 shipped as a graybox: flat albedo colours written inline in two
## scenes and two scripts. "Everything is grey" was an accurate description of
## the build. Fixing that by editing four files independently would have made
## the drift permanent, so every Episode 2 material now comes from here.
##
## PROVENANCE — this is not invented art direction.
## Every entry traces to the founder's own reference art in
## `artifacts/founder-art/references/`:
##   ref 1  ep2_runner_ref_1_boulder_bandits.jpg  — boulders, bandits, arrows,
##          carts on rails, lanterns on the timber posts
##   ref 2  ep2_runner_ref_2_zipline.jpg          — steel zip cable, pulley
##          sparks, lantern spacing, gold-veined walls, depth haze
##   ref 3  ep2_runner_ref_3_minecart_ride.jpg    — cart wood + brass banding,
##          the gold cannabis-leaf emblem, rail iron, gold nugget piles
## Starting numbers were extracted by GPT-6 Astra from those three images
## (see `artifacts/episode2-gold-mine/art/astra_art_direction_2026-09-10.md`
## for the full response, its caveats, and the open questions it raised).
##
## WHERE THESE NUMBERS DEVIATE FROM ASTRA'S, AND WHY
## Astra assumed Forward+. **The web build does not run Forward+.** Godot 4.3
## renders the Web platform with the Compatibility (GL) backend, where:
##   * volumetric fog does not exist — its settings are silently ignored, so
##     depth haze uses plain distance fog instead;
##   * a metallic surface with no reflection source renders nearly BLACK.
##     Astra flagged the missing reflection source itself. Rather than add
##     reflection probes to a graybox, metallic values here are capped around
##     0.65-0.8 and "goldness" is carried by albedo + low roughness + a small
##     emission, which reads correctly in both backends.
## Deviating knowingly and writing down why is the point; silently copying
## numbers that no-op on the target platform is how a build looks wrong for
## weeks with every gate green.

## One surface definition. Kept as plain data so a test can assert over it.
class Surface extends RefCounted:
	var albedo: Color
	var metallic: float
	var roughness: float
	var emission: Color
	var emission_energy: float

	func _init(a: Color, m: float, r: float, e: Color = Color(0, 0, 0), ee: float = 0.0) -> void:
		albedo = a
		metallic = m
		roughness = r
		emission = e
		emission_energy = ee


## Helper so the table below reads as hex, the way the reference was sampled.
static func _hex(s: String) -> Color:
	return Color.html(s)


## THE PALETTE. Keys are used by name from the scenes and the visual builders —
## a typo returns null and `make()` pushes an error rather than silently
## handing back an untextured white box (the exact failure that made the last
## playtest read as blown-out white).
static func table() -> Dictionary:
	return {
		# --- rock: the dark ground everything else reads against (ref 1,2,3) ---
		# COOL charcoal, not warm brown. Two independent fidelity reviews of real
		# captures said the same thing: "the palette reads as brown timber
		# rather than gold-bearing rock", where the references separate cool
		# charcoal stone from warm wood and warm gold. Warming the rock made
		# every surface in frame the same hue family and flattened the scene.
		# Cool charcoal, but DARK cool charcoal. The first cool value (#3A3B3E)
		# tripped the gate's gold-to-rock ratio at 3.3 against a 4.0 floor —
		# which is Astra's OWN figure from the value study, so the two halves of
		# its advice were in tension. Resolved the physically correct way: the
		# hue comes from albedo, the brightness comes from the lighting rig
		# (ambient 0.42, key 0.7), not from lifting the albedo of the thing gold
		# is supposed to out-read.
		"rock": Surface.new(_hex("#2C2E33"), 0.0, 0.78),
		"rock_deep": Surface.new(_hex("#1F2126"), 0.0, 0.92),
		# Gold in the wall glitters in all three refs. Modest emission stands in
		# for the specular sparkle a flat box cannot produce.
		# Emission dropped from 0.35: at 0.35 the veins read as flat yellow
		# decals stuck ON the wall rather than ore embedded IN it. Ore is
		# reflective, not luminous.
		"gold_vein": Surface.new(_hex("#D9AC48"), 0.65, 0.34, _hex("#FFC24D"), 0.12),

		# --- structure: timber + brass, the cart and the mine supports (ref 3) ---
		"wood": Surface.new(_hex("#51321C"), 0.0, 0.85),
		"wood_light": Surface.new(_hex("#6B4A2F"), 0.0, 0.80),
		"brass": Surface.new(_hex("#9A7039"), 0.75, 0.42),
		# Metallic dropped 0.70 -> 0.35 and albedo lifted. In the Compatibility
		# backend there is no reflection source, so a 0.70-metallic rail had
		# almost nothing to reflect and rendered as a dark line: the fidelity
		# review's finding #3 was that the outer track boundaries were clearer
		# than the actual railway. Rails are the thing that explains the route.
		"iron": Surface.new(_hex("#9BA0A8"), 0.30, 0.38),
		"steel_cable": Surface.new(_hex("#777C83"), 0.80, 0.32),

		# --- value: what the player is here for (ref 3 nugget carts) ---
		"gold": Surface.new(_hex("#EDC35F"), 0.80, 0.23, _hex("#FFC85A"), 0.50),

		# --- light sources: the warm anchors of every reference ---
		# Emission energy 4.0 was the first try and it CLIPPED: in the real
		# browser build every lantern became a pure-white disc with no hue left
		# in it, which is the same over-bright failure this pass exists to fix,
		# just localised. 1.8 keeps the warm colour and still crosses the glow
		# HDR threshold.
		"lantern": Surface.new(_hex("#FFC170"), 0.0, 0.50, _hex("#FFB55E"), 1.1),
		# Pulley/wheel sparks (ref 1 and 2 both lead with them).
		"spark": Surface.new(_hex("#FFB259"), 0.0, 0.45, _hex("#FF9A3C"), 2.2),

		# --- hazards ------------------------------------------------------
		# Granite, distinctly LIGHTER than the wall so the silhouette carries
		# the read without a colour code (ref 1: the boulders are the palest
		# large objects in frame).
		"boulder": Surface.new(_hex("#777773"), 0.0, 0.82),
		# Crates are cart timber with brass banding in ref 1 — deliberately the
		# lighter wood so a crate does not vanish into a support beam.
		"crate": Surface.new(_hex("#7A5227"), 0.0, 0.80),
		# Arrows: ref 1 shows brown shafts with grey tips, NOT a red hazard
		# colour. Astra was explicit that no red/orange danger code is
		# reference-supported. The small emission here is a READABILITY
		# decision, not art direction: an arrow is the smallest, fastest hazard
		# in the game and it arrives at head height in a dark cave. It is
		# written as "the shaft catches lantern light", which is what ref 1
		# actually shows. Flagged to the founder as an open question.
		"arrow": Surface.new(_hex("#AD8050"), 0.0, 0.70, _hex("#FFB070"), 0.55),
		"arrow_head": Surface.new(_hex("#77797C"), 0.80, 0.40),

		# --- gameplay markers ---------------------------------------------
		# The chamber gate is a goal marker, not a mine surface. Kept the green
		# of Lil Blunt's own foliage (all three refs) so it reads as "yours".
		"gate": Surface.new(_hex("#4EC97A"), 0.0, 0.55, _hex("#5BE68C"), 0.9),
		# Lil Blunt's cart body carries his leaf green under the timber.
		"leaf_green": Surface.new(_hex("#4E8F35"), 0.0, 0.60),
		# Tax-collector bears in the chamber: the bandits of ref 1 are black
		# balaclavas over tan cloth. No weed theming on enemies (global rule).
		"bandit": Surface.new(_hex("#2B2A28"), 0.0, 0.75),
		"bandit_cloth": Surface.new(_hex("#6E6350"), 0.0, 0.85),
	}


static var _cache: Dictionary = {}


## Build (and cache) the StandardMaterial3D for a palette key.
## Returns a loud magenta error material rather than null so a bad key is
## visible on screen in one frame instead of reading as "art not done yet".
static func make(key: String) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var t: Dictionary = table()
	if not t.has(key):
		push_error("Ep2Palette: unknown surface key \"%s\"" % key)
		var bad := StandardMaterial3D.new()
		bad.albedo_color = Color(1, 0, 1)
		bad.emission_enabled = true
		bad.emission = Color(1, 0, 1)
		bad.emission_energy_multiplier = 2.0
		return bad
	var s: Surface = t[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = s.albedo
	m.metallic = s.metallic
	m.roughness = s.roughness
	if s.emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = s.emission
		m.emission_energy_multiplier = s.emission_energy
	_cache[key] = m
	return m


## An UNSHARED copy of a palette material.
##
## `make()` hands back a cached, SHARED StandardMaterial3D — correct for the
## dozens of static props that never change, and a trap for anything that
## animates its own colour. The chamber dims a bandit's albedo when it dies:
## with a shared material, killing one bandit would dim every bandit on screen
## (and every crate that happened to use the same key). Call this whenever the
## caller intends to mutate the material it gets back.
static func make_unique(key: String) -> StandardMaterial3D:
	return make(key).duplicate() as StandardMaterial3D


## Drop the cache. Only needed by tests that assert freshly-built materials.
static func clear_cache() -> void:
	_cache = {}


# --- environment --------------------------------------------------------------

## Cave atmosphere shared by the runner and the chamber.
##
## Deliberately DARK. The previous pass was blown out to near-white and the
## gold had nothing to be brighter than; Astra's value study put displayed rock
## at 0.08-0.18 and broad gold at 0.45-0.70, which only works if ambient stays
## low and the warm point lights do the lifting.
static func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _hex("#0B0908")

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Cool ambient against warm lantern key — the colour contrast every
	# reference is built on.
	# Warm, and lifted from 0.22. The second browser capture came back reading
	# as a black tunnel with lit patches: correct in structure, but the rock
	# itself was invisible between lanterns. The references are dark AND you can
	# always see the stone. 0.30 warm is where the rock reads brown without the
	# gold losing its job as the bright thing.
	# Cooled slightly and lifted to 0.34. The fidelity review's #1 finding was
	# "darkness erases the playable scene" and its #2 was that the lighting was
	# almost entirely brown, where the references contrast amber lantern pools
	# against a cool slate cavern. The ambient term is the cool half of that
	# contrast; the lanterns are the warm half.
	# Cool, and lifted again to 0.42. "The playable scene collapses into shadow"
	# was the #1 finding of BOTH fidelity reviews of real captures — the second
	# one after the first lift. The blowout this value used to guard against is
	# guarded better by the two assertions beside it in the gate (tonemap white,
	# and "no ordinary surface competes with gold"), which constrain the actual
	# cause: pale albedo with nowhere to clip.
	env.ambient_light_color = _hex("#7C8794")
	env.ambient_light_energy = 0.42

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.0

	# Plain distance fog, NOT volumetric: volumetric fog does not exist in the
	# Compatibility backend the web build uses, so it would be a setting that
	# looks right in the editor and does nothing on itch.io.
	env.fog_enabled = true
	# WARM, not cool. The first pass used a blue-grey haze (#2A2F38) and the
	# browser capture came back reading as a blue night scene, not a gold mine:
	# with no walls yet, fog colour IS the background for most of the frame.
	env.fog_light_color = _hex("#3A2E22")
	env.fog_light_energy = 1.0
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0

	# Bloom off, threshold high: only true HDR sources (lantern cores, sparks,
	# gold glints) bloom. Astra's warning — bloom > 0 lifts ordinary surfaces
	# and re-creates the washed-out look this pass exists to fix.
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	return env


## The cool, dim key light. A mine has no sun; this is the fill that keeps
## silhouettes legible, and the warm omnis below are the real light sources.
static func make_key_light() -> DirectionalLight3D:
	var d := DirectionalLight3D.new()
	# 0.35, not Astra's 0.65. Astra's figure assumed a sun-lit scene; here the
	# browser capture proved that a cool directional at 0.65 OUT-LIT the warm
	# lanterns and turned brown rock blue. In the references the lamps are the
	# light source and the cool component is only the shadow fill.
	d.light_color = _hex("#A8BCD2")
	# Back up from 0.35. It was cut to 0.35 when the runner had no walls and the
	# cool key was the ONLY thing lighting a bare floor, turning it blue. With
	# the tunnel enclosed and lanterns actually reaching the rails, this is the
	# cool fill the references have and the scene needs it to stop being black.
	d.light_energy = 0.7
	d.shadow_enabled = true
	d.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	return d


## A lantern. These are the readability fix AND on-model at the same time:
## every reference lights the mine with warm lamps hung on the timber posts.
static func make_lantern_light() -> OmniLight3D:
	var o := OmniLight3D.new()
	o.light_color = _hex("#FFB765")
	# Energy 2.0 / range 7.0 (the first pass) lit nothing: the lamps hang 4.6 m
	# off the rails at 2.8 m up, so a 7 m sphere never reached the track and the
	# capture came back almost black. These are the numbers that actually put
	# warm pools on the rails.
	o.light_energy = 3.6
	o.omni_range = 17.0
	o.omni_attenuation = 1.5
	o.shadow_enabled = false     # dozens of these; shadows would cost the web build
	return o
