---
name: ep2-gauntlet-loop
description: The founder-demanded loop for getting an Episode 2 feature "down to a T" - build, run the gates, capture the REAL render, measure it, have Jev rule on the numbers, look at the pictures yourself, fix, repeat until a defined stop. TRIGGER on "run a gauntlet loop", "get this down to a T", "Jev simulation", "keep iterating until it's right", or before calling any Episode 2 gameplay/visual feature done.
---
# One command
`bash scripts/ep2-range-gauntlet.sh` (target practice + first-person rifle). It runs, in order, and stops on the first red:
1. headless gates: `ep2_range_lesson_test`, `ep2_smelting_facility_test`, `ep2_hideout_corrections_test`, `ep2_runner_audio_test`;
2. the bot simulation (`tools/ep2_sim/fps_feel_sim.mjs`) so the tuning numbers are still the ranked ones;
3. the real-render rig (`tools/ep2_shots/range_lesson_shot.tscn`): 15 lesson stages + METRIC lines (hip rifle position, ADS sight offset from the crosshair);
4. `tools/ep2_sim/range_gauntlet_jev.mjs`: turns the metrics into a numbers-only `state` and asks Jev boolean questions (is the ADS sight within 3 % of the screen centre? does the hip rifle sit low-right? did every lesson stage run?) plus ship / block; exit 0 ship, 1 block, 2 uncertain;
5. it prints the capture folder: LOOK at the pictures (Read tool shows images). Jev cannot see them. The numbers say where things are; only the picture says it reads.
# Stop rules (so the loop ends)
Ship only when: all four test suites green, Jev ships with every `has_*` question "no" (UNCERTAIN = not shipped, re-measure), and YOU looked at the stage frames for the changed area. Maximum 5 loops per feature per session; after the 3rd red on the same metric stop tuning and change the approach (skill ep2-3d-strategy-research / bring in Opus).
# Honest limits
Jev is text-only and judges numbers you give it; DeepSeek V4.1 Flash (vision) or GPT-6 Astra can grade a screenshot, but their verdicts are leads, not facts (CLAUDE.md MODEL ROLE SPLIT). A gauntlet pass is not "live": say live only after master's CI deploy lands (skill always-ship-live).
