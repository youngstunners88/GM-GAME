---
name: ep2-environment-legibility
description: Make the Episode 2 hideout dressing READ against the deliberately-dark forge environment - fix emissive props that blow out to white discs in the Compatibility backend, keep gold from going black, and add warm fill/rim light so crates/gold/trophies/gun wall are visible without touching the facility shell. TRIGGER when the founder says the hideout is "still shitty / bare / grey / dark", a prop reads as a flat pale plate, gold looks like plastic, or props vanish into the timber. Owns src/episode2/chamber/hideout_dressing.gd only.
---

# Why this exists
Founder 2026-10-04: "improve the environment of Inferno Bull MORE. It's still shitty." The room had the right
props but they did not READ: lanterns were pale plates, gold looked flat, and everything between the lanterns fell
into near-black. The fixes live entirely in `hideout_dressing.gd` (the dressing module); the facility shell,
environment, furnace and the range targets are owned by other files — do not edit them from here.

# The measured root causes (Compatibility / GL renderer = the web renderer)

1. **Emissive glass blows out to a flat white disc.** `lantern.glb` bakes its glass globe at full-white
   emission. In the Compatibility backend that clips to a pure-white octagon; from across the room the thin brass
   cage disappears and the globe reads as a pale plastic plate floating on the wall. **Measure:** render the GLB
   six-up (`node scripts/glb-shot.mjs <glb> out.png`) — the globe shows as flat white. **Fix:** after instancing,
   walk the MeshInstance3Ds and `material_override` the near-white surface (albedo r+g+b > 2.2) with a warm amber
   emissive (energy ~1.7, colour #FF9A3D) so it crosses the glow threshold but keeps its hue. See `_lantern()`.

2. **High-metallic gold renders near-black.** The palette's own iron/rail note: in Compatibility a metallic
   surface with no reflection source has almost nothing to reflect and goes dark. Pushing `_gold` to metallic 0.55
   made the bars read darker, not shinier. **Keep gold metallic <= 0.4**, bright albedo, a small emission (~0.16),
   and let warm fill lights do the glinting.

3. **The props vanish into the dark timber.** `Ep2Palette.make_environment()` is deliberately dark (ambient 0.42
   cool) so gold stays the brightest thing — correct, and NOT ours to change. Lift the DRESSING instead with a
   handful of steady warm `OmniLight3D` fills (`_fill_lights()`): over the gold stacks and ore cart, the gun wall,
   the taxidermy bears, the Fort Knox back wall, and a camera-side approach fill. Energies 1.0–3.0, warm colour,
   `light_specular` ~0.6. They are NOT appended to `_flames` (no flicker). This is the "stronger molten-gold spill"
   the reference leads with, done with light, not new textures.

# Traps that cost time here (2026-10-04)

- **The big dark box dead-centre in the forward/look-back player views is the RANGE FIRING BENCH**
  (`range_dressing.gd`, at `LINE.z - 0.55 = z≈-2.55`), not a hideout crate. It is another agent's prop. Do not
  spotlight it from directly above (it reads as a black silhouette); a camera-side approach fill lights its front
  face instead. Never edit range_dressing.gd from the dressing module.
- **The `pv0_arrival` frame renders dark brown with a teardrop overlay — this is a scene-transition / harness
  flake, NOT the dressing.** Proven by `git stash`-ing hideout_dressing.gd and re-rendering: the ORIGINAL file
  gives the identical dark pv0 through the same `player_view_shot`. The beat is still APPROACH (it only hands to
  control once the player walks), and the scene-transition autoload overlay is on top. Don't chase it from here.
- **Untextured particle quads are hard squares in Compatibility.** Every ember/haze material uses the soft radial
  `_soft_blob()` GradientTexture2D, ADD blend, billboard. Keep `amount` low (embers 20, haze 6) for web perf.
- **CPUParticles3D has no `amount_ratio`** (GPUParticles only) — it throws every frame.

# Verify (look, don't guess)
Real web renderer (Mesa GL Compatibility), player's eyes through the game's own follow camera:
```
xvfb-run -a -s "-screen 0 960x540x24" .godot-cache/Godot_v4.3-stable_linux.x86_64 \
  --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 960x540 \
  res://tools/ep2_shots/player_view_shot.tscn -- out=.farm/hideout_env
```
Read pv1_forward, pv2_midroom, pv4_look_right, pv6_look_up with the Read tool. Every one must show, in warm colour:
gun wall + rifles, gold bars + heaped ore cart, bears/trophy heads, whiskey table, cowhide rug, Fort Knox door +
skull, poster, crates/ammo, warm caged lanterns (NOT white plates). To localise a mystery mesh, probe mesh global
positions by parent (a 30-line headless scene that builds the facility and prints `find_children("*",
"MeshInstance3D")` near the suspect xz). To prove a regression is or isn't yours, `git stash` the one file and
re-render.

# Done means
`tests/ep2_smelting_facility_test.tscn` is ALL PASS (the build() contract: flames, gatling, poster, blockers,
rack_rifle, WHISKEY_TABLE_POS), and the player-eye captures read rich and warm like `.farm/range_refs/scene_view.png`.
Net package growth ~0: procedural geometry + CPU particles + emissive materials + warm lights, no new assets.
