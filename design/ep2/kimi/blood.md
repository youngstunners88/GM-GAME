# Kimi packet: blood that reads - a restrained spurt, a stain on the body, a pool under the dead (the draw opponent and the bears)

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter, web export, **Compatibility
renderer**). Claude reviews every hunk, runs the gates and commits; write production code, not sketches.

## Founder's words (2026-10-27)
"The man must also have blood on him and the same goes for the bears that get shot. We need to see blood spurting. Obviously
not too dramatically. The same should happen if a horse or person in the town is shot."
Fix-pack item: "Draw: ... blood on the body"; "Visual changes (... blood) need before/after captures."

## What exists (verified by Claude - read the included files)
- The Compatibility renderer has **no Decals**. CPUParticles3D, MeshInstance3D, StandardMaterial3D (alpha), ImageTexture work.
- **The draw opponent** - `src/episode2/chamber/gold_town.gd`: `_on_player_shot()` decides the draw with
  `aim_hits_opponent(eye, dir)` (ray vs the body's axis, `OPP_HIT_R`) and calls `_opp.fall_dead()`; `_opp` is an
  `Ep2TownFolk` (`src/episode2/actors/ep2_town_folk.gd`: `fall_dead()` tips the model over backwards in ~0.4 s, `model`,
  `height_m`; rigged folk have a `Skeleton3D` under `model`).
- **Bears** - `src/episode2/chamber/woods_quad.gd`: the player's rifle shot `_bear_on_ray(eye, dir)` then
  `hit.take_hit(eye)`; the player's arrows (`_tick_player_arrows`, `take_hit(before)`); Bull's shots (`br.take_hit(_bull.position)`);
  deaths arrive in `_on_bear_died(br)`; corpses stay in the woods and stay searchable (`_nearby_corpse`). Bear brains:
  `src/episode2/actors/ep2_bear_brain.gd` (`take_hit(from) -> bool` killed, `actor` the bear's Node3D, `died` signal). Bears
  are big (2+ m): scale the effect with the body.

## Build
1. **New module** `src/episode2/fx/ep2_blood_fx.gd`, `class_name Ep2BloodFx` (static helpers; no autoload, no `_process` of
   its own - use one-shot particles, Tweens on the created nodes, or a tiny child Node with its own `_process` that frees
   itself):
   - `static func spurt(parent: Node3D, at: Vector3, dir: Vector3, size: float = 1.0) -> Node3D` - a ONE-SHOT, restrained
     spurt at the wound along the shot's exit direction: 10-24 small dark-red droplets (CPUParticles3D, sphere or quad mesh
     ~1-2 cm x size, gravity, 0.35-0.7 s life, slight spread), plus a faint short red mist. No chunks, no screen splatter, no
     sprays longer than ~0.6 m for a man. Frees itself when done.
   - `static func stain(body: Node3D, at: Vector3, normal: Vector3, size: float = 1.0) -> Node3D` - a dark, slightly glossy
     irregular stain (~0.12-0.18 m x size) on the body at the wound, following the body when it falls: attach to the nearest
     torso bone through a `BoneAttachment3D` when the body has a `Skeleton3D` (Spine/Spine01/Spine02/Chest-like names; find
     the closest bone to `at`), else to `body` itself. Built from a small procedural texture (a 64x64 radial-noise splat made
     once with `Image` and cached in a static var - no new image files) on a QuadMesh facing along `normal`, alpha blended,
     pushed 3-5 mm off the surface so it never z-fights.
   - `static func pool(parent: Node3D, at_ground: Vector3, radius: float, grow_s: float = 6.0) -> Node3D` - a flat pool on the
     ground under a body that grows from ~0.08 m to `radius` over `grow_s` (ease-out), dark red, glossy (low roughness), soft
     edge from the same cached splat texture, 1-2 cm above the ground; never on a wall.
   - Colours: arterial red only where it is fresh (spurt); stains and pools dry toward a dark maroon over ~20 s. Nothing glows
     (unshaded is fine only if it keeps the dark value; it must not look neon in the sun or in the dark woods).
2. **Hooks** (small hunks only):
   - the draw opponent: on the winning shot, `spurt` at the hit point on his body (the point on his axis closest to the ray -
     `aim_hits_opponent` already computes it; add a helper that returns it), a `stain` on him at that point, and a `pool`
     under his torso once he is down (radius ~0.55 m).
   - bears: on every hit (player rifle, player arrow, Bull's rifle) a `spurt` sized for the bear at the hit point (extend the
     ray helper to give the point; for arrows the arrow's position; for Bull the point on the bear facing Bull) and one
     `stain` per hit (cap 4 per bear); on death a `pool` under the corpse (radius ~0.9 m).
3. **Gate** `tests/ep2_blood_test.gd` + `.tscn` (root Node, script attached; print `EP2_BLOOD: ALL PASS` or `EP2_BLOOD: N FAILURE(S)`;
   `get_tree().quit(failures)`):
   - `spurt` makes a one-shot emitter with 10-24 particles, short life, that frees itself within 2 s;
   - `stain` on a rigged townsperson (use a real `Ep2TownFolk` setup the way `tests/ep2_gold_town_test.gd` builds the opponent)
     is parented under a `BoneAttachment3D` of that skeleton and follows the body through `fall_dead()` (its world position
     moves with the falling torso);
   - `pool` grows from small to the requested radius in `grow_s` and lies flat (normal up) just above the ground;
   - the real draw (build the town chamber as `tests/ep2_gold_town_test.gd` does and win the draw the way it does) leaves a
     stain on the opponent and, after he falls, a pool under him; a lost draw leaves neither;
   - a woods bear shot by the player (build the woods as `tests/ep2_bear_attacks_test.gd` does) gets a spurt + stain on the
     hit and a pool after it dies;
   - every created material is supported by the Compatibility renderer (no Decal nodes anywhere in the tree).
4. Keep `tests/ep2_gold_town_test.gd`, `tests/ep2_bear_attacks_test.gd`, `tests/seamless_chain_test.gd` passing unchanged.

## Rules
GDScript for Godot 4.3: typed variables, `##` doc comments on public functions, no new autoloads, no project.godot edits,
nothing that needs Forward+. Restrained, not gory (the house style is chill; this is a Western, not a horror game). Keep
every existing public signature; never change dialogue text or line ids; keep each file's indentation (tabs). Change existing
files only with exact SEARCH/REPLACE edits; new files as whole files. Then a short NOTES line: what changed per file and what
the gate covers.

@include src/episode2/chamber/gold_town.gd
@include src/episode2/actors/ep2_town_folk.gd
@include src/episode2/actors/ep2_bear_brain.gd
@include src/episode2/chamber/woods_quad.gd
@include tests/ep2_gold_town_test.gd
@include tests/ep2_bear_attacks_test.gd
