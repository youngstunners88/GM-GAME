---
name: ep2-gatling-wanted-billboard
description: Build the large shootable Jackhammer Wanted billboard / range banner in the Armory's Gatling yard (founder 2026-11-05) - a billboard-class target using the official poster art that registers Gatling rounds with holes and damage states, without blocking the firing lane or replacing the plates, bales or the gun. TRIGGER on "Gatling billboard", "big target by the Gatling", "Jackhammer banner", "shoot Jack Hammer's poster", "Gatling target practice board", or any new target kind in Ep2GatlingPost.
---

# Gatling yard: the Jackhammer billboard

Parent: `ep2-jackhammer-wall-boss`. Gun facts and locks: `ep2-armory-guns`. Hit proof: `tests/ep2_gatling_hits_test.gd`
(founder 2026-10-27: "the gatling gun doesnt hit any of the targets" - the billboard must pass the same player-path test).
Texture: the official `src/episode2/extras/town/posters/poster_jack_hammer.png` from `ep2-official-wanted-rebalance`
(the same file, or a crop of it - never a second likeness).

## How the yard works today (read these lines, not the whole file)
- `src/episode2/actors/ep2_gatling_post.gd` (`Ep2GatlingPost`, ~620 lines): `targets` = `[{kind, node, swing, ang, vel, hits}]`;
  `add_plate()` / `add_bale()` (~l.160-190) duplicate GLB templates and `_face_z` them toward the gun; `_trace()` (~l.380)
  is hitscan - **every kind is a disc of `PLATE_RADIUS` 0.27 m** around a centre, nearest hit wins, else ground, else air at
  `RANGE_M` 160; `_hit_target()` bumps `hits`, swings a plate (`plate_rang`) or counts `bale_hits` + `_puff()`.
  Aim limits: `ARC_YAW` +-0.87 rad around the rest heading, `PITCH_MIN` -0.12 / `PITCH_MAX` 0.36. Drum 150, finite.
- `src/episode2/chamber/gold_town.gd` `_build_guns()` (~l.640): post at `xf * Ep2GoldTown.GATLING_POST` (building-local
  (9.6, 0, 1.6); the Armory faces -z so local +x = world west, open ground), plates/bales from `Ep2GoldTown.GATLING_PLATES`
  (local x 17-31) and `GATLING_BALES` ((36,0,1.6) sits **on the bore axis**, (19,0,5.6)), collision via
  `_town_col["props"].append([Vector2, radius])`. Hit feedback/score hooks: `_on_gatling_round`, `_on_gatling_trace`.

## Build
1. **New kind, not a fake plate.** Add `add_billboard(world_pos, face_toward, size: Vector2, tex: Texture2D) -> int` and
   `kind = "billboard"`. A disc test is wrong for a 4 m board: in `_trace()` intersect the board plane and accept the hit when
   the point's board-local `|x| <= w/2` and `|y - centre_y| <= h/2`. Keep the "nearest hit wins" order so plates in front
   still take their rounds.
2. **Size and place by measurement.** Billboard-class: ~4 m wide (square art -> ~4 m tall) on two posts, bottom edge
   >= 1.4 m. Put it behind the plate line (local x ~40-45, z ~1.6) so it is the primary target from the stand, raise its
   centre (~3.5 m) clear of the axis bale's 0.27 m disc, and prove in the test that its centre and four corners are inside
   `ARC_YAW`/pitch from `eye_position()` and that a ray to the centre is not first blocked by a plate or bale. Before
   choosing x, check the world beyond the yard is open (buildings, the grazing horse at (-27, 1462.5), lane walks):
   `python3 tools/ep2_town/armory_offmain_probe.py` style measurement, never a guess. Add the two posts to
   `_town_col["props"]` so the player cannot walk through them, and do not put anything in the corridor between the stand
   and the plates.
3. **Feedback that matches the yard.** Per hit: a small dark hole decal on the canvas (pooled quads or a shader hole mask;
   cap ~200, reuse oldest), a paper/dust puff (`_puff`), a short canvas shiver (optional, only if hit registration stays
   exact). Damage states by `hits`: clean -> holed (~25) -> shredded (~90: an alpha-scissor noise mask threshold rises so
   the paper tears; the frame and posts remain). New signal `billboard_hit(index)` + counter `billboard_hits`; existing
   counters/signals unchanged. A full drum on the board must not free nodes or spike frame time (pool, no per-hit `new()`).
4. **Material**: unshaded is wrong outdoors - lit StandardMaterial3D, alpha scissor for the torn edge, roughness ~0.9, no
   emission (no neon blowout), mipmaps on so the face reads from 40 m; a wooden frame/backing so it is not a floating sheet.
5. Everything streamed: absent extras -> no billboard, nothing breaks (same guard as the Gatling itself).

## Gate (extend `tests/ep2_gatling_hits_test.gd`, new section)
Using the **player path** already in that test (take the crank, `_mouse_centre` on the camera ray, `shoot()`), not
`aim_toward()`: centre the billboard, fire a burst, assert `billboard_hits > 0`, decals > 0 and the state advances after
enough rounds; assert the plates are still all hittable afterwards (the board added a target, it removed nothing); assert
the corridor stand->plates is clear and the billboard is inside the arc. Mutation-check: shrink the hit rectangle to zero
and see the section fail. Also run `tests/ep2_armory_guns_test.tscn`.

## Proof
Capture from the mounted view: before firing, mid-burst (tracers + holes), after a drum (shredded). Walk-up capture from
the Armory porch showing it does not dominate the street. Look at them yourself (`see-it-yourself`) before calling it done.
