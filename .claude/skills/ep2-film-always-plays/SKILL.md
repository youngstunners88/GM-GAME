---
name: ep2-film-always-plays
description: A founder film (60 s Episode 2 film, the boss-defeat films) must ALWAYS play to the end unless the player deliberately skips it - no silent self-skips, no stalls. TRIGGER on "the video isn't playing / doesn't play / glitches / skips itself / goes straight to the hideout", any new film or cutscene player, any edit to ep2_video_film.gd, stage*_boss_defeat_cutscene.gd, cliff_jump_cinematic.gd, or the hideout pre-build.
user-invocable: true
allowed-tools: Bash, Read, Edit, Grep
---

# Why films vanish (every cause found so far, 2026-10-05)
1. **Held JUMP skips the film.** Space is both JUMP and the film's skip key. The player is still holding/mashing it when the cart runs out or the boss dies, so a hold-to-skip timer (0.6-1.0 s) fires at frame 0: the film "never plays". Fixed in `ep2_video_film.gd` and `stage3_boss_defeat_cutscene.gd`; `cliff_jump_cinematic.gd` already had it. **Rule: every skip needs the key RELEASED once first (`_skip_armed`), and a deliberate new hold afterwards.**
2. **A synchronous build mid-film.** The hideout (Bull rig, hero, ~80 props) was built in one ~0.9 s block at film second 3 -> frozen picture + crackling audio ("glitches"). Now sliced one step per frame (`_prebuild_room`, `await process_frame`), gated by `tests/ep2_transition_prebuild_test.gd` (worst frame < 450 ms; it was ~213 ms).
3. **Silent fallback.** A missing/undecodable .ogv used to just `finish()`. Every skip path now prints a `[VIDEO] ... reason` line.

4. **The hidden 3D room starves the decoder (the real cause on weak hardware, measured 2026-10-06).** The film covers the screen, but the hideout built behind it was still RENDERED every frame (lights, shadows). On a software/weak GPU the Theora decoder got ~8 render fps: 134 picture updates in 16 s and a 1.4 s freeze = a slideshow that "isn't playing". `get_viewport().disable_3d = true` while the film plays (restored on finish / `_exit_tree`) -> 53 fps, 850 updates, worst gap 168 ms. Probe: `tools/ep2_shots/film_fps_probe.tscn -- force3d=1|0`; Jev rules on the numbers with `tools/ep2_sim/film_fps_jev.mjs` (SHIP). Gate: `tests/ep2_transition_prebuild_test.gd` (3D off during the film, on after).

# Proof on screen
After every film the hideout shows a bottom-left line for 10 s: `FILM end | picture reached 59.5 s of 61 | real 61.7 s | clock ...` (or skip_hold / stall / decoder_early / clock_guard / "in-engine fallback"). The founder can screenshot it; do not guess. The game clock lags the decoder on slow machines (clock 6.8 s while the picture ran 61 s) - that is expected, never a reason to call the film early.

# Gates (all must pass before saying a film works)
- `tests/ep2_transition_prebuild_test.tscn`: held JUMP does not skip, a NEW hold does, build never stalls a frame > 450 ms.
- `tools/ep2_shots/video_probe.tscn -- path=res://...ogv`: the file decodes and the clock advances.
- Real web build: `bash scripts/ep2-local-export.sh` (use a THROWAWAY access hash locally, never commit it), then `EP2_CODE=<throwaway> node scripts/ep2-film-web-probe.mjs .farm/filmweb` - open the first screenshots: they must show film frames, then the hideout.
- Any NEW film player: copy the arming pattern; never read `Input.is_action_pressed("jump")` for a skip without it.

# Added 2026-10-06: watchdog + reasons
`ep2_video_film.gd` now logs `[VIDEO] Ep2 film: finished ... / ended EARLY ... / STALLED ...` and, if the picture has not moved after 5 REAL seconds (the stall check uses wall time, never the test-driven film clock), shows "VIDEO COULD NOT PLAY IN THIS BROWSER - continuing" and carries on after 2.5 s instead of freezing. If the founder says the video still does not play, ask for that banner / the `[VIDEO]` console line first - it names the cause (stall vs early end vs missing file vs skipped).
