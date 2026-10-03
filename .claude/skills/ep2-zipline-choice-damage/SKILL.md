---
name: ep2-zipline-choice-damage
description: Episode 2 runner - a zipline choice must have ONE safe path and ONE visible punish, never a hidden penalty. TRIGGER on any complaint that Lil Blunt "loses a life" on a zipline, any new zip segment, any new hazard that overlaps a zip, or any change to _update_zipline / _is_cleared in runner_graybox.gd.
---
# Rule (founder 2026-10-02)
"Even if he doesn't take the zipline he still loses a life... I don't see the obstacle responsible."
1. **Skipping a zip costs nothing by itself.** `_update_zipline` emits `zip_missed` and NEVER calls `_take_hit()`.
2. **The punish is a visible hazard on the rails under the zip**: a `pit` (void box, hazard stripes, lamps, telegraph
   "NO TRACK - JUMP TO THE ZIPLINE!") or a shovel bear. `_is_cleared("pit")` is true only while `_ziplining`.
3. **No shared volume**: every hazard is its own obstacle row in `tracks/episode2_tracks.gd`; one damage source per row.
4. Every Descent zip must be covered by a pit or shovel hazard within start-40 .. end+30 (test asserts it).
# Proof
`tests/ep2_runner_graybox_test.tscn`: skipped chain = 0 HP; pit on rails = -1; pit via cable = 0.
Capture both choices (rails vs cable) before saying fixed.

# Update 2026-10-03 (founder: "he loses health on the zipline, that is wrong")
While `_ziplining` NOTHING costs health: not boxes, arrows (he cannot duck up there), boulders, boarders, and not letting go of a chained cable (it used to `_take_hit()`). The only punish is the visible pit he then falls into. Tests: "a clean zipline over every hazard type costs 0 HP", "a dropped chain costs NOTHING".
# Hearts
Three `"type": "heart"` rows on the Descent (z 600 lane 0, 1014 lane 1, 1746 lane 1): claimed by passing through (rails or cable), +1 life up to START_HEALTH, gone for the run; `heart_collected(health)`; red glowing pickup in `runner_view._heart_pickup_node`.
