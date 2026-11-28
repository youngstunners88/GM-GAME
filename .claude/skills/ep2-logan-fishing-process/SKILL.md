---
name: ep2-logan-fishing-process
description: Logan's boat-to-fishing process at Logan's Lake (founder 2026-11-28) - oars lift, ship along the gunwales and stay in view, hands go from oar grips to the rod lying in the boat, rod comes up, line is cast out; the reverse chain before he rows again; and Logan already fishing (never reset to rowing or the shore) when Lil Blunt comes back from the ridge after day-88. TRIGGER on "oars teleport", "oars vanish", "rod pops in", "goldfish mode", "Logan fishing", "Logan's boat", "Logan rowing", "return from the ridge / Hammer's men and Logan", or any edit to src/episode2/actors/ep2_logan_skiff.gd.
---

# Logan's fishing process (no teleports)

Brief: `PROMPT_EPISODE2_LOGAN_FISHING_RETURN_HUGE_FISH_2026-11-28` (founder). Lock still holds: `design/ep2/lake/LOGANS_LAKE_LOCK.md` -
Logan fishing is **ambient flavour**; Lil Blunt investigates liquidity and never casts, catches or carries a fish.
The comedy beat on top of this is `ep2-lake-fish-gag`.

## Where it lives
- `src/episode2/actors/ep2_logan_skiff.gd` (`Ep2LoganSkiff`) - the whole routine. States
  `MOORED -> WALK_TO_BOAT -> BOARD -> ROW -> SETTLE -> FISH -> UNSETTLE -> ROW ...`. **Enum order is load-bearing**: append, never insert.
- `src/episode2/chamber/logans_lake.gd` - `_reset_skiff()` (moored on the first visit, `start_fishing_now()` when `after_day88`),
  `_skiff.advance(delta, may_depart)` in `_tick`.

## The chain (one timeline, `_apply_settle(t)`, played forwards for SETTLE and backwards for UNSETTLE)
| t (s) | step | what must be readable |
|---|---|---|
| 0 - 0.7 | `SETTLE_LIFT_END` | blades come up out of the water, palms still on the oar grips |
| 0.7 - 1.9 | `SETTLE_SHIP_END` | oars swing in (`SHIP_YAW`) and lie along the gunwales - **they stay visible** |
| 1.9 - 2.9 | `SETTLE_HANDS_END` | palms travel from oar grips to the rod grips (`_hand_blend`) |
| 2.9 - 4.1 | `SETTLE_RAISE_END` | rod comes up from the floor (`_rod_stow` -> identity, pivot at the butt) |
| 4.1 - 6.0 | `SETTLE_SECONDS` | cast: small rod flick, bobber flies an arc to the water (`_cast`), line visible only now |
The boat coasts to a stop over `DRIFT_SECONDS`. The rod is **always** in the boat (stowed on the floor by his right boot while rowing):
it is picked up, never conjured. Hands follow the prop through the rest-aware IK; nothing is hidden/shown to fake a change.

## Return from the ridge
`after_day88` handoff -> `start_fishing_now()`: boat at `FISH_SPOT` / `FISH_YAW` (open water, three-quarter view from the shore path),
oars shipped, rod up, bobber on the water, `hold_fishing = true` so he never rows off mid-visit. A reload keeps it.
Talk during the visit happens from the boat. If you add a lake beat that needs Logan on the shore, add a reverse chain + walk, never a pop.

## Rules
1. Never `hide()` an oar or the rod, never `show()` the rod/line in a single frame. Any new pose is another window on the timeline.
2. Oars only come back out via UNSETTLE (reverse chain). Once fishing, no oar blink.
3. No fishing gameplay, no fish item, no LP numbers at the lake (out of scope by lock).
4. Keep palms on props measured, not asserted: `palm_position()` vs `grips` / `_fish_grips`.

## Proof
- Gate: `tests/ep2_logan_fishing_test.tscn` (`LOGAN_FISHING: ALL PASS`, in CI) - per-frame rod-tip/oar/palm step limits, order of steps,
  cast > 1.5 s, blades out of the water, reverse chain, return-from-ridge state held 70 s, plus the fish gag. `tests/ep2_lake_art_test.tscn`
  still measures rowing contact.
- Captures: `xvfb-run -a .godot-cache/Godot_v4.3-stable_linux.x86_64 --rendering-driver opengl3 --resolution 1280x720 --path . res://tools/ep2_shots/logan_fishing_shot.tscn -- out=<dir> settle`
  (s0..s6 one per step) and without `settle` for the return + fish gag. Look at them before calling it done (`see-it-yourself`).
