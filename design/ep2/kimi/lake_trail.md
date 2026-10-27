# Kimi packet: the ride to Logan's Lake - Lil Blunt on Dude's horse, bandits on the way, arrival at the lake

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter, web export, **Compatibility
renderer**). Claude reviews every hunk, runs the gates and commits; write production code, not sketches.

## Founder's words (2026-10-27, the locked story order)
"Dude tells Lil Blunt to 1st go to Logan's lake so that his horse can get refreshed in the heat. Logan's lake is on the map. Then
Lil Blunt goes there and fends off bandits on his way. He meets Logan who teaches him about the value of liquidity ..."
Step 12-14 of the fix pack: Dude sends him to the lake first -> "The ride to the lake; bandits on the way must be fended off" ->
Logan (liquidity, the day-88 river shipment). The horse is transport only (no staking, LP or "horse protocol").

## What exists (verified by Claude - read the included files)
- **The town** (`src/episode2/chamber/gold_town.gd`): the story ends at `Beat.GEARED` (it emits `prebuild_requested.emit("logans_lake")`)
  and `Beat.DONE` resolves `{"next_chamber": "logans_lake", ...}`. Dude's ranch (`Ep2StableYard`, being finished in a parallel packet)
  sells the horse and says "Logan's Lake first"; assume the town hands over `"horse": true` when Lil Blunt bought it.
- **Rooms**: every story room extends `Ep2Interlude` (`src/episode2/chamber/interlude_base.gd`: build steps, `_on_setup`, handoff,
  first-person camera + viewmodel, `shoot()`, `_on_player_shot()`, HUD hearts via `_shows_health()` / `get_health()`, `_resolve`).
  The next room is built behind the current one (`prebuild_requested`, `Ep2SessionRoot`) and swapped in one frame - no blackouts.
  Rooms register in `Ep2SessionRoot.CHAMBER_SCENES` (`src/episode2/session/ep2_session_root.gd`).
- **A ride with shooting already exists**: the woods' quad ride (`src/episode2/chamber/woods_quad.gd`: `_ride_pts` from a
  Catmull-Rom spline, `_ride_sample`, passenger shooting at road bears, `_fail()` / retry, the 3-heart `_health`). Model the horse
  ride on it (same feel, same camera rules), but a horse: the horse model under the camera, Lil Blunt in the saddle.
- **The horse**: `res://src/episode2/assets/town/horse.glb` (head +X, clips horse_stand / horse_graze / horse_walk; see
  `Ep2TownLife._horse`). There is no gallop clip: play horse_walk with speed_scale matched to the ground speed (a brisk trot ~5-6 m/s).
- **Bandits**: `Ep2JackHammer` (`src/episode2/story/ep2_jack_hammer.gd`) already has bandit barks (`jh_bandit_*`) for Jack Hammer's
  men; reuse those lines. Use `Ep2TownFolk` (`src/episode2/actors/ep2_town_folk.gd`) puppets with the stranger's model
  (`res://src/episode2/assets/town/cowboy.glb`, child meshes "Idle" / "Draw" swapped with `set_pose`) for the bandits; vary them
  with a hat/bandana tint so the group does not read as copies. Their awareness/telegraph pattern can follow `Ep2BearBrain`
  (`src/episode2/actors/ep2_bear_brain.gd`).
- **Logan's Lake** (`src/episode2/chamber/logans_lake.gd`) is being reworked in a parallel session: do NOT edit it. Its `SPAWN` is
  where the player arrives; hand it your result in the handoff only.

## Build
1. **New room** `src/episode2/chamber/lake_trail.gd` (`class_name LakeTrailChamber`, extends `Ep2Interlude`) + `lake_trail.tscn`
   (same shape as the other room scenes), registered as `"lake_trail"` in `CHAMBER_SCENES`:
   - a desert-to-lakeside trail ~450-600 m long (a smoothed spline over a few hand-placed points; low rocks, scrub, a few trees as it
     nears the water), lit like the town's desert (`Ep2GoldTown.apply_desert_grade`); the lake glints at the end;
   - Lil Blunt rides Dude's horse in first person: the horse's head and neck in front of the camera, the horse walking/trotting along
     the spline at ~5.5 m/s (horse_walk clip speed-matched), W/S to ease up or push (4-7 m/s), A/D steer a lane offset of +-2.2 m,
     mouse look free with a +-110 deg yaw limit from the travel direction, the armory still usable (shoot, reload, switch);
   - THE BANDITS: 2 ambush points along the trail with 2-3 bandits each (behind rocks / on a ridge), plus 1 rider who chases for a
     stretch. A bandit TELEGRAPHS before every shot (rises from cover, raises the gun into the "Draw" pose, a short bark from
     `jh_bandit_*`, a glint) for 0.8-1.2 s, then fires; a hit takes one heart (3-heart cap, the HUD shows them) or wounds the horse
     (horse_hp 3). Lil Blunt's hits drop a bandit (fall_dead; blood via `res://src/episode2/fx/ep2_blood_fx.gd` when it exists, load
     it dynamically). A bandit can also be outrun (the ambush is behind once you pass it);
   - the horse goes down at horse_hp 0: the UNHORSE event (a stumble, a short camera drop and roll to the ground, no blackout) and
     Lil Blunt finishes on foot at walking speed; no game over for losing the horse;
   - out of hearts: the attempt ends the way the woods' `_fail()` does and restarts at the trail start, the horse fresh;
   - the end: the trail reaches the lake shore; the horse lowers its head to drink (horse_graze) when it is alive; then resolve
     `{"next_chamber": "logans_lake", "arrived_mounted": bool, "trail_seconds": float, "bandits_down": int}`. The lake is prebuilt
     behind the trail (request `"logans_lake"` early in the ride) and swapped in one frame.
2. **Town hook** (small hunks in `gold_town.gd` only): `Beat.GEARED` requests `"lake_trail"` instead of `"logans_lake"`, and
   `Beat.DONE` resolves to `"lake_trail"` (keep every other field it hands over, add `"horse": true`). Nothing else in the town.
3. **Lines**: Lil Blunt's short reactions (2-4, e.g. on the first ambush, on the horse going down, at the lake) and the bandit barks you
   need, in `assets/town-audio.json` `lines` (`{"id", "speaker", "text"}`; speakers `lil_blunt` and `bandit`; add `voices.bandit` with
   `"voice_id": ""` and a note - Claude assigns a premade voice). Captions go through the HUD toast like the other rooms do.
4. **Gate** `tests/ep2_lake_trail_test.gd` + `.tscn` (root Node, script attached; print `EP2_LAKE_TRAIL: ALL PASS` or `EP2_LAKE_TRAIL: N
   FAILURE(S)`; `get_tree().quit(failures)`):
   - the town's GEARED requests the trail and DONE hands over to it (build the town as `tests/ep2_gold_town_test.gd` does);
   - riding moves Lil Blunt along the route at 4-7 m/s with the horse under him; steering stays within the lane;
   - a bandit never fires without a visible tell of at least 0.6 s before it; a hit costs exactly one heart; never more than 3 hearts;
   - shooting a telegraphing bandit drops him;
   - horse_hp 0 -> the unhorse event -> he continues on foot and still reaches the end (arrived_mounted false);
   - 0 hearts -> retry from the trail start with a fresh horse;
   - riding to the end resolves to logans_lake with arrived_mounted true, and the lake was prebuilt before the end (no build at the cut).
5. Keep `tests/ep2_gold_town_test.gd`, `tests/seamless_chain_test.gd`, `tests/ep2_logans_lake_test.gd` passing unchanged.

## Rules
GDScript for Godot 4.3: typed variables, `##` doc comments on public functions, no new autoloads, no project.godot edits, nothing that
needs Forward+. Restrained blood. Bandits are people (Jack Hammer's men), never weed-themed. Weed content stays positive. Never change
existing dialogue text, line ids or voice ids. Keep every existing public signature; keep each file's indentation (tabs). Change
existing files only with exact SEARCH/REPLACE edits; new files as whole FILE blocks. Then a short NOTES line: what you built, what the
gate covers, anything you could not do.

@include src/episode2/chamber/interlude_base.gd
@include src/episode2/chamber/woods_quad.gd
@include src/episode2/chamber/gold_town.gd
@include src/episode2/session/ep2_session_root.gd
@include src/episode2/chamber/logans_lake.gd
@include src/episode2/chamber/ep2_town_life.gd
@include src/episode2/actors/ep2_town_folk.gd
@include src/episode2/actors/ep2_bear_brain.gd
@include src/episode2/story/ep2_jack_hammer.gd
@include tests/ep2_gold_town_test.gd
@include tests/ep2_logans_lake_test.gd
