# Inferno Bull hideout — environment legibility pass (2026-10-04)

Founder: "improve the environment of Inferno Bull MORE. It's still shitty."
Target: `.farm/range_refs/scene_view.png` (molten-gold forge hideout, warm/rich).
Owned file: `src/episode2/chamber/hideout_dressing.gd` only. Net package growth ~0 (code + lights + CPU
particles + emissive materials; no new assets).

## What changed
- **Lanterns fixed** — `lantern.glb`'s glass globe bakes full-white emission; in the GL Compatibility (web)
  backend it clipped to a pale plastic plate that read as a floating disc on every wall (see `_lantern()` /
  `_lantern_glass()`). Now recoloured to a warm amber emissive. This was the biggest single legibility win.
- **Gold reads as gold** — metallic pulled back from 0.55 to 0.40 (high-metallic goes near-black in Compatibility),
  bright albedo + small emission, lit by warm fills.
- **Warm fill / rim lights** (`_fill_lights()`) — steady, warm OmniLights over the gold stacks, ore cart, gun
  wall, taxidermy bears, Fort Knox back wall, and a camera-side approach fill. The "stronger molten-gold spill"
  done with light, not textures. Not flickered (not in `_flames`).
- **Layered set dressing** — banded timber crates, open ammo boxes packed with brass cartridges + spilled rounds
  (`_crates_and_ammo()`); bandoliers, horseshoes, tally-mark scratches, framed wanted posters (`_wall_props()`);
  a saloon bottle shelf (`_bottle_shelf()`); drifting ember motes + faint warm haze (`_atmosphere()`, soft-blob
  billboards, low amount for web perf). All new solid props add walk blockers; the central walk lane and the
  molten channel are kept clear. The build() contract is unchanged.

## Captures
- Before: `.farm/hideout_env_before/pv*.png`
- After:  `.farm/hideout_env/pv*.png`
  (`player_view_shot.tscn` — arrival / forward / midroom / look left,right,back,up, through the game's own
  follow camera and real walk input.)

## Verified
- `tests/ep2_smelting_facility_test.tscn` → EP2_SMELTING_FACILITY: ALL PASS (build() contract intact).
- pv2/pv4/pv6 read rich and warm, close to the reference: gold, ore cart, gun wall + rifles, bears, whiskey
  table, cowhide rug, Fort Knox + skull, poster, crates/ammo, warm caged lanterns.

## Honest remaining-cheap notes
- The taxidermy bear + mounted-head Meshy models still read a touch pale under warm light (their baked texture is
  light); improved by the warm fills but not perfect. The carrier is the model, not the dressing.
- The **range firing bench** sits in the forward/look-back views dead-centre (`range_dressing.gd`, z≈-2.55) — it
  belongs to the target-practice agent, not this module. Its front face is now lit camera-side so it reads as a
  bench rather than a black box; its material cannot be improved from here.
- `pv0_arrival` renders dark (scene-transition/harness flake at the APPROACH beat, **proven not to be the
  dressing** by re-rendering the stashed original — identical dark frame). The autoload overlay is off-limits.
- The reference's single dramatic LEFT furnace is the facility's center-back furnace here; the molten spill fills
  approximate its warm cast but the layout is the facility's, not the dressing's.
