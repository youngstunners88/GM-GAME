---
name: ep2-no-blackouts
description: Episode 2 story rooms hand over in ONE motion - no blackout, no freeze, no title-card "checkpoint" - from the hideout's lava river through the mine lift to the woods. The next chamber is built BEHIND the current one (off-screen SubViewport, a few ms per frame, GPU warmed) and swapped in the same frame. TRIGGER on "blackout", "stop start", "checkpoint", "flow", "seamless", "loading between rooms", any new chained chamber, edits to Ep2SessionRoot._enter_chamber_chained, Ep2Interlude.prebuild_*, _build_steps, handoff_ready.
---

# The rule (founder 2026-10-11)
From jumping the lava to the surface wood there is no blackout. The only long pause is Inferno telling Lil Blunt about the bears while the cage rises.

# Why it blacked out (measured, `tools/ep2_shots/chain_build_probe.tscn`, software GL)
Swapping chambers built the whole next room synchronously in front of the player: lift 0.6-6 s, wood 1-3 s, THEN a first-draw stall (shader compile + mesh upload; lift 5.5 s cold). A frozen last frame / black.

# How it works now
1. A chamber asks for the next one: `prebuild_requested(id)` (hideout: when the range lesson starts -> `mine_lift`; lift: in `_on_setup` -> `woods_quad`).
2. `Ep2SessionRoot._on_prebuild_requested` instantiates it inside an off-screen `SubViewport` with its OWN world (its camera, sky and lights cannot touch the chamber being played) and `Ep2Interlude.prebuild_begin()`.
3. Each frame `_process` calls `prebuild_step(7 ms)`: the chamber's `_build_steps()` (Callables - the set in slices, then Inferno, the player body, the first-person rig), then `_warm_views()` (one camera pose per frame) so the GPU compiles every shader / uploads every mesh now. `Ep2SessionRoot.step()` (tests) finishes it at once.
4. The active chamber holds its exit (`_handoff_ok()` / `handoff_ready`) until the next is built; the root then gives the build 40 ms/frame. A pause at the door at worst, never black.
5. `_enter_chamber_chained` -> `activate(root, gaze)`: the same instance moves into the main tree, camera current, `setup()` (about 5-8 ms), old chamber removed from the tree that frame. The player's look yaw/pitch carries (`get_handoff` / `_apply_handoff_gaze`, yaw 0 = +Z everywhere) and the held keys persist (the root polls input). `handoff_seamless = true` suppresses the title card (`ep2_entry._update_title_card`).
6. No prebuild (tests, a lone room, a mismatch): the old synchronous path still works.

# Adding a chained chamber
`_build_steps()` (split the set: any single step over ~100 ms makes a visible hitch), `_warm_views()` (what the player sees first), `prebuild_requested.emit(next)` at the earliest beat, `_wants_handoff()` + `_handoff_ok()` on the exit condition. Never build in `_on_setup` what could be a step (Inferno is `_step_bull`).

# Proof
Gates: `tests/ep2_interlude_test.tscn` (background build, hold, same-instance cut, gaze, hideout exit gate). Real render: `tools/ep2_shots/handoff_shot.tscn` (luminance of the last lift frame vs the first wood frames, frame times) and the probe above. 2026-10-11: cut call 13 ms, first wood frame luminance 0.149 (not black), first frame after the cut = steady-state frame time; the cost moved into ~12 background frames of 70-500 ms on software GL (a stutter in the old room, not a freeze).
