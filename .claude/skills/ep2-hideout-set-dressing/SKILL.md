---
name: ep2-hideout-set-dressing
description: Redesign an Episode 2 interior (Inferno Bull's hangout, later the Fort Knox vault, saloon, armory) to match a founder TARGET IMAGE - Flux concept per prop -> Meshy image-to-3d (spend the credits, founder-authorised) -> shrink -> place by measured native size; pin-up poster and cowhide from Flux; heat and flame; full colour, never grey primitives. TRIGGER when the founder sends a scene image and says "this is what it should look like", "polish the environment", "decorate / redesign the room", or asks for props (guns, trophies, posters, whiskey, flames) in an Episode 2 chamber.
---

# Why this exists
Founder 2026-10-01 sent a target image of Inferno Bull's hideout (`design/ep2/inferno_bull_hideout_target.jpg`):
timber alcove, bear trophies (mounted heads + a full taxidermy bear), a gun wall of 1800s rifles and revolvers, a
Colt Gatling, a pin-up poster, a whiskey table, cowhide rug, gold bars, braziers/forge flame, FORT KNOX door with a
longhorn skull. The old room was a 24 x 32 m empty cave with floating cream boxes. This skill is the recipe that fixed it.

# FOUNDER CORRECTION 2026-10-01 (read first)
The first pass built the room from code primitives + PIL drawings to "save credits". The founder rejected it:
"Of course you must spend what we have on Meshy! I don't like the greyscale. This looks nothing like what I gave
you. I want high quality!!!" **Never ask whether to spend Meshy credits on an Episode 2 set; spend them.**
Primitives are only for things Meshy cannot make (walls, beams, bridges, gold-bar stacks, light sources).

# The prop pipeline that worked (2026-10-01, ~90 credits for the Bull rig + 4 clips + 5 props)
1. `python3 tools/ep2_forge/hideout_concepts.py [id]` - Muapi Flux concept per prop, ISOLATED on white, in the
   target's style (warm firelight, saturated). Look at a contact sheet; regenerate a bad one (the first Gatling came
   out head-on and mangled - a "side profile view" prompt fixed it). Flux is cents; Meshy is credits: fix the image first.
2. Meshy `image_to_3d` with `model_type: smart-topology`, `ai_model: meshy-t2`, textured, glb (15 credits each).
3. `python3 tools/meshy/pull_hideout_props.py name=task ...` downloads, shrinks (1024 / 256 maps, ~0.3-0.4 MB each)
   and writes `src/episode2/assets/hideout/sources.json`.
4. `node scripts/glb-shot.mjs <glb> sheet.png` and LOOK (views: front = +Z camera, back, left, right, top, 3/4).
   Meshy normalises every model to a unit box centred on the origin; record [height, lowest y] in
   `HideoutDressing.NATIVE` (probe: `godot --headless -s tools/ep2_shots/glb_probe.gd -- res://...glb`) and place with
   `_prop(name, base, height, yaw)` - no runtime AABB (the headless dummy renderer returns empty mesh AABBs).
5. Facing from the sheet: bears and heads face +Z, the Gatling's muzzle is -X, the cart's long axis is X. A model
   facing +Z turned by yaw faces (sin yaw, 0, cos yaw).
6. Flat art (poster, rug texture) comes straight from Flux; give the rug a real hide silhouette (alpha-scissor PNG),
   not a rectangle.

# Earlier recipe notes (still true)
1. **Save the target** into `design/ep2/` first (ep2-founder-intake). Everything is judged against it (ep2-reference-match-loop).
2. **Read the orientation before placing anything.** In the facility the camera looks +Z with yaw 180, so
   **screen-LEFT is world +X** and screen-right is -X. The first build put the gun wall on the wrong side. Write the
   target's left/right layout as +X/-X in the design doc before touching code.
3. **Dress in a separate module** (`src/episode2/chamber/hideout_dressing.gd`, `HideoutDressing.build(visuals)`),
   never inline in the 1000-line chamber script. It returns handles (`flames`, `gatling`, `poster`) the chamber animates.
4. Every prop must still show something if its GLB fails to load (primitive fallback in `_prop` callers).
5. Light-grey palette metals (`Ep2Palette.make("iron")`) read as CREAM blocks under forge light - ladles, revolvers
   and chains need a dark iron (0.13-0.2 albedo). That was the "greyscale" look as much as the primitives were.
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
