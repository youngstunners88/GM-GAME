# Session 9 — S2 Distributor browser capture (HONEST RESULT)

Local non-threaded web export of source `fc1a82e` served + driven with Playwright
(`scripts/playtest-distributor.mjs`, 150s, chromium /opt/pw-browsers/chromium).

**Result: the game booted clean (booted:true, zero console errors), but the
blind traversal driver could NOT reach the Stage-2 Distributor.** The driver
holds Right + jumps + attacks on a cadence; it cannot beat Level 1's boss
(that needs real combat skill), so the run died on Level 1 and reset to the
main menu (see 03-*). No frames of the Distributor fight were obtained, so this
capture provides **no evidence about the S2 chase either way**.

Therefore the S2 chase is **NOT claimed fixed** this session. What shipped is
the lock-hysteresis engine fix (proven at the engine level by
tests/s9_lock_hysteresis_test.gd — fails on pre-fix, passes post-fix). A real
in-browser chase capture needs a debug boss-warp hook (no teleport hook exists
in the game today) OR a founder playtest — flagged for the next session.

Frames:
- 01-boot-menu.png — engine booted, menu rendered, offline mode.
- 02-level1-gameplay.png — driver playing Level 1 (~40s).
- 03-reset-to-menu-never-reached-s2.png — back on the menu by ~133s; the run
  never reached Crystal Caverns (Level 2) where the Distributor is.
