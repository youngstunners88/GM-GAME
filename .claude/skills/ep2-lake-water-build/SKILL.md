---
name: ep2-lake-water-build
description: Build the physical Logan's Lake for Episode 2 - still-water body, shore, simple dock and staging post, an outflow channel that visibly becomes the existing river - reusing the shipped water shaders and kit pieces, pack-safe, readable at eye height, proven in the engine. TRIGGER on "the lake", "still water", "dock", "shore", "outflow", "lake feeds the river", "water shader", "make the lake readable", or scenery for Logan's Lake.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Logan's Lake: the place

Story and rules live in `ep2-logans-lake`; Logan himself in `ep2-logan-character`. This skill is the water, shore, dock and outflow. Lock wording to honour: "readable body of water (lake that clearly can narrow or outflow into a river). Not a grey void and not Episode 1 Level 3 scenery... shore, simple dock or staging markers, possible distant train/stable presence already requested... do not expand those here."

## Start from what exists (do not rebuild)
- **Master:** river ribbon at z 1522 (22 m, `RIVER_Z`/`RIVER_W`, shader `src/episode2/art/water_river.gdshader`, banks + boulders) and railway z 1546 built by `Ep2TownLife`, both inside the shared `Ep2GoldTown.build`. Walkable town ends z 1495: they are scenery.
- **`feat/ep2-surface-set` (`d6891958`, unshipped):** `Ep2SurfaceSet` with a scenery lake (`LAKE_RECT` x 42-184, z 1030-1380 beside the ride road, `src/episode2/art/lake_water.gdshader`), rail line, stable. It is also the only lake the quad ride passes. Ship order matters: the texture fix is live; this branch still needs its own ship. If Logan's Lake reuses this water, depend on it explicitly and merge-test (both touch `Ep2GoldTown.build`).
- Kit pieces that already ship in `town_kit.glb`: `River_Crate`, `River_Skiff`, `Arm_PowderKeg`, `LampPost`, `Boardwalk4m`, `HitchRail`. A plank dock and staging post can be `Boardwalk4m` + posts: **zero new GLB bytes**.

## Geometry decision (needs the founder, see `ep2-logans-lake` #2/#3)
The two existing waters are not connected: the scenery lake sits beside the road at z 1030-1380 and the river crosses at z 1522 behind the town. "The lake feeds the day-88 river" must be *visible*. Options: (a) Logan's Lake chamber builds its own bowl behind/beside the town whose outflow channel runs into the existing z 1522 river (shortest, one set of coordinates, matches "after the town"); (b) extend the scenery lake's south-east corner with a channel along the east edge into the river (longer, more earth-moving). Prefer (a) unless the chain slot changes. Whatever is chosen, the channel must narrow (wide still water -> narrow flow), change shader (still -> flowing), and show motion direction (floating debris, reeds leaning, a ripple line) so the handoff reads without a sign.

## Readability rules (the founder's "not a grey void")
1. **Still water reads as depth:** dark, mirrored sky (planar/fake reflection in the shader), shore reeds, a visible waterline on the staging post. Never show numbers, bars, timers or a percentage anywhere (rule 5 of the lock). "Depth" is shown as water level against a marker post and as a calm surface.
2. **One staging point** with a simple post/dock, the staged crate, and a lamp; no menu, no inventory. Logan stands there on arrival so the eye lands on him and the water together.
3. **Shore and horizon:** Western desert surface (mesas, scrub, the town and Fort Knox hill in the distance), mist optional. The Logan reference is a bayou; if the founder wants that, it is a deliberate look change, not an accident.
4. No fish gameplay props. A single bank flavour shape is allowed only if it cannot be picked up, targeted or counted.
5. No Level 3 assets: never import `src/level/distant_lake.gd`, `stable_horses.gd` or `distant_train.gd` into this scene.

## Build and budget
- Water: reuse the two shaders; any new parameter is a uniform, not a new file. Only add a new texture with a measured pack number.
- Shore, dock, posts: kit pieces + primitives; if a new prop is needed, author it headless in `tools/ep2_blender/` with the blender-skills (`blender-hardsurface-modeling` mid-poly, `blender-scene-setup` names/origins, `blender-asset-qa`, `blender-geometry-nodes` for reeds/pilings as instances) and `blender-game-optimization` budgets. Reeds: MultiMesh/instances, not realized geometry.
- Pack gate is hard (margin ~467 KB). Web frame time: run `tools/ep2_shots/build_time_probe.tscn` / `chain_build_probe.tscn` before and after (the loco GLB already has 287 mesh nodes).
- Collision: shoreline and water edge must stop the player cleanly (no wading into the void); outflow is scenery, not walkable. Bounds like `GoldTownChamber._collide` clamp; define the lake's own.
- Hand-over from `gold_town`: build behind the town while the last beat plays (`prebuild_requested`), one cut, no black.

## Proof
Engine captures at eye height from the Episode 2 camera (arrival view, Logan + water, stage post, outflow leaving), before/after if a scene was edited, looked at by eye, filed under `docs/episode2-quality/logans-lake-<date>/` with the SHA. Blender look-dev renders (`blender-lighting-lookdev`, `blender-time-of-day --mood desert`/golden) are references only; the shipped look is the Godot capture (`see-it-yourself`, `ep2-reference-match-loop`). Fresh-clone pack gate and `ship-visual-proof` for anything touching export filters.
