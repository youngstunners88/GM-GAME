---
name: ep2-lake-trail-residuals
description: The lake ride after the 2026-11-01 founder residuals - rushing vs hiding bandits, the seated chasing rider, the green readable lake approach with Logan's camp landmark, and Dude's horse that drinks through Logan's talk and stays mountable. TRIGGER on bandit behaviour, "standing on the horse", desert at the lake, "can't see Logan", the horse disappearing, remounting at the lake, or lake<->trail travel with the horse.
---

# Lake trail and Logan's Lake residuals

**Bandits** (`lake_trail.gd`): role per spec index (`RUSHER_SLOTS` -> 7 rushers of 18). Holdouts crouch `HOLDOUT_HIDE` (head
under the 1.1 m rock crest) and duck back after each shot. Rushers break cover in range, run (`RUSH_SPEED`) until the trail's edge
(lateral measured at *their* ambush point), `RUSH_STANDOFF` from him, or `RUSH_MAX_SECONDS`, then fight standing (`exposed`).
Every shot keeps the rise/Draw/glint tell. The coach gun's `hit_scale` widens the hit test within 30 m.

**Seated rider**: a rigged townsman (`RIDER_MODELS`) with `Ep2RanchPose.install_ride` (Dude's seat), hips measured in the solved
pose and set on the saddle. `_bandit_rest()` replays RanchRide - never `set_pose("idle")` on a rigged rider (it stands him up).

**Approach**: the desert floor shader greens by distance from the lake centre (`has_forest`), the ecotone greens earlier and wider,
`LAKE_REVEAL_DISTANCE` 130 m, a "LOGAN'S LAKE / LOGAN'S CAMP AHEAD" signpost 175 m out, and Logan's camp (fire, 28 m smoke column,
landing lantern) lives under the lake's `_visuals` so the trail's horizon copy shows it. The smoke shader animates by TIME only.

**The horse at the lake** (`logans_lake.gd`): the trail room is parked off screen at the hand-over, so the lake owns its own
`LakeHorse` (child of the room, NOT `_visuals`, so the preview never shows a second horse). Ridden in -> it walks from where he
slid off to `HORSE_DRINK` and drinks (`horse_graze`, trough sips) through the whole talk. E mounts within `HORSE_REACH` (not during
`INVESTIGATE`), horse and rider ease onto the bank path; E again dismounts and the horse stays. `world_routes.travel` keeps one
horse: lake->trail `set_return_mounted(is_riding_horse())`, trail->lake `arrive_from_trail(is_mounted())`.

Gate: `tests/ep2_founder_residuals_1101_test`, `ep2_lake_trail_test`, `ep2_logans_lake_test`, `ep2_world_routes_test`.
