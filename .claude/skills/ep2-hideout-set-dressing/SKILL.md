---
name: ep2-hideout-set-dressing
description: Redesign an Episode 2 interior (Inferno Bull's hangout, later the Fort Knox vault, saloon, armory) to match a founder TARGET IMAGE using code-built set dressing - trophies, 1800s armory, Gatling gun, pin-up poster, braziers, cowhide rug - without adding megabytes or new Meshy credits. TRIGGER when the founder sends a scene image and says "this is what it should look like", "polish the environment", "decorate / redesign the room", or asks for props (guns, trophies, posters, whiskey, flames) in an Episode 2 chamber.
---

# Why this exists
Founder 2026-10-01 sent a target image of Inferno Bull's hideout (`design/ep2/inferno_bull_hideout_target.jpg`):
timber alcove, bear trophies (mounted heads + a full taxidermy bear), a gun wall of 1800s rifles and revolvers, a
Colt Gatling, a pin-up poster, a whiskey table, cowhide rug, gold bars, braziers/forge flame, FORT KNOX door with a
longhorn skull. The old room was a 24 x 32 m empty cave with floating cream boxes. This skill is the recipe that fixed it.

# Recipe (in this order)
1. **Save the target** into `design/ep2/` first (ep2-founder-intake). Everything is judged against it (ep2-reference-match-loop).
2. **Read the orientation before placing anything.** In the facility the camera looks +Z with yaw 180, so
   **screen-LEFT is world +X** and screen-right is -X. The first build put the gun wall on the wrong side. Write the
   target's left/right layout as +X/-X in the design doc before touching code.
3. **Dress in a separate module** (`src/episode2/chamber/hideout_dressing.gd`, `HideoutDressing.build(visuals)`),
   never inline in the 1000-line chamber script. It returns handles (`flames`, `gatling`, `poster`) the chamber animates.
4. **Build from primitives + committed GLBs.** Zero new packages: Gatling, revolvers, braziers, skull, plinths, tables,
   cauldrons are box/cylinder/sphere meshes; rifles reuse `winchester_1886.glb`; bears reuse `mine_bear_archer.glb`.
   Every prop must still show something if its GLB fails to load.
5. **Trophy heads = a sliced GLB**, not a new Meshy model: `trimesh`, keep faces whose centroid is above the neck
   (`y > 0.30`), drop the bow (`|x| < 0.55`), shrink the baked texture to 512 px, export, then
   `godot --headless --import`. Check facing numerically/visually (the archer bear's base forward is +X; wall yaw =
   `90 + 90*sx`). Remember trimesh exports may be alpha-blended: bears looked ghostly until opaque.
6. **Painted textures from PIL** (`scripts/make_hideout_textures.py`): poster and cowhide. Deterministic, rerunnable.
   Ceiling: they read as stylised flat art. A better poster is a Meshy text-to-image job (credits: ask first).
7. **Heat and flame** (Inferno Bull's identity): braziers with additive soft-sprite flame particles + flickering
   OmniLights (`_animate_set`), forge-glow cauldrons with the flowing molten shader, ember particles off his shoulders.
8. **Lift the room's light, not the props'.** Forge env ambient 0.95, glow 0.85/0.95 threshold; keep `self_light` on
   organic GLBs LOW (0.1) - at 0.3-0.35 the bears and wall heads washed out grey-white.

# Compatibility-renderer traps (the web build is GL Compatibility)
- **Untextured particle quads render as hard squares.** Give every smoke/steam/flame/ember material a soft radial
  `GradientTexture2D`. This was the "pixelated steam" in every earlier facility capture.
- `CPUParticles3D` has no `amount_ratio` (GPUParticles only) - it threw a SCRIPT ERROR every frame.
- Metallic with no reflection source renders near black: keep metals at <= 0.55 and carry "gold" in albedo + small emission.
- A GLB crucible modelled as a flat cream slab reads as a table. If a prop reads wrong from the game camera, replace it.
- A flat unshaded colour (the furnace mouth) reads as a UI rectangle; use the flowing molten ShaderMaterial.
- Check the BAKED model before adding props: the Bull already wears a helmet, sunglasses and a cigar. A second cigar
  floated beside his face until it was removed.

# Capture budget
Software GL renders a full facility capture in ~7 minutes. Edit in batches, run ONE capture, read the PNGs, fix
everything the images show, then capture again. `tools/ep2_shots/facility_shot.tscn -- out=<dir>` writes the five beat
shots plus six close-ups (`cu_bull_face`, `cu_bull_hands`, `cu_gatling`, `cu_gunwall`, `cu_trophies`, `cu_door`).

# Done means
Facility test passes (`tests/ep2_smelting_facility_test.tscn`, section 11 covers the dressing), a real capture shows the
target's elements (trophies, guns, Gatling, poster, flames, whiskey, door skull) and nothing is blocky, ghostly or floating.
