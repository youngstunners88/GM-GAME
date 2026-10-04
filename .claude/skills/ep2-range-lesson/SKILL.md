---
name: ep2-range-lesson
description: Inferno Bull's target-practice lesson in the hideout - he LEADS the player to the range, DEMONSTRATES load, aim and fire, then the player does each step; the rifle is locked until he has taught it. TRIGGER on "target practice", "range", "Inferno should lead / demo / teach", "the rifle shouldn't fire until...", any edit to the Lesson enum or _tick_lesson / _begin_lesson / _demo_* in smelting_facility.gd, FacilityShow.demo_steps, range_dressing.gd, or the vo_bull_range_* lines.
---
# The lesson (founder 2026-10-04)
"Inferno must lead you there, conduct a demo and then have the player play. The rifle doesn't fire until Inferno teaches Lil Blunt to load it, aim and fire."
State machine (`SmeltingFacilityChamber.Lesson`): LEAD -> DEMO -> LOAD -> AIM -> FIRE -> PRACTICE -> DONE (-> beat TERMS).
1. LEAD: Inferno says "follow me" while he walks (3.4 m/s) to `BULL_DEMO`; the view eases round to him for 2.2 s; a pulsing ring marks the firing line; the player is FREE. He nags (`vo_bull_range_nag`) every 14 s if you dawdle. Arrival within 2.6 m of `RangeDressing.LINE` starts the demo.
2. DEMO (player held, camera frames Bull + plates): intro, then the LOAD line with shell clicks at 2.2/3.3/4.4/5.5 s and the rifle raised at 0.2 s, the AIM line, the FIRE line with the shot at 1.7 s (report + plate clang 0.3 s later), "your turn". The plate he hits is reset afterwards. Events are tied to moments of the voice line (`say` steps take `events: [[t, Callable]]`), so picture = words.
3. LOAD: prompt "PRESS R TO LOAD" with a live count; shells go in one by one (0.5 s each) until the tube is full -> his praise -> AIM.
4. AIM: hold RMB steadily for 0.7 s -> "Steady..." -> the rifle UNLOCKS -> FIRE.
5. FIRE: first hit -> praise -> PRACTICE; 3 plates, R to reload, dry-fire click + his reminder when empty -> DONE -> his closing line -> story continues.
Locked rifle behaviour: click = "WAIT FOR INFERNO" toast + (rate-limited) `vo_bull_range_hold`; R before the demo = "WATCH INFERNO FIRST".
# Contract with the range's visual owner
`range_dressing.gd` owns how the range looks; gameplay reads only: `LINE`, `BULL_LINE`, `LANE_X`, `TARGET_SPOTS`, `PLATE_RADIUS`, `build() -> {targets, blockers, line}` and `set_target_state(plate, broken)`. A plate node's origin is its visual centre (hit test). Nothing may be built in the lane strip x in [LANE_X-0.6, LANE_X+0.6], z in [LINE.z, 7.5].
# Voice + sound
Bull lines are ElevenLabs (voice `uWE48TmsTuIjyh2ifoNL`, speed 1.2) in `assets/audio-manifest.json` (`vo_bull_range_*`); sfx `ep2_winchester_shell_load`, `ep2_winchester_dry`, `ep2_plate_clang`. Generate ONLY the new ids with a small script that calls `generate_audio.post()` (the full generator re-creates the missing film voices into src), then measure peaks.
# Gate
`tests/ep2_range_lesson_test.tscn` plays the whole lesson with only player verbs (follow, watch, R, hold RMB, LMB) and checks order of lines, locks, reserve accounting, dry-fire, TERMS hand-off. `debug_skip_lesson()` is the hook other tests use; never ship code that calls it.
# Never
Let a click fire before AIM completes; start the demo while the player is far away; teach out of order; let the lesson dead-end (the nag + the floor ring are the guard); change a plate's origin.
