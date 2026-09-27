# ADR-0004: Episode 2 runner — cart attrition, speed ramp, and a separate motion/emotion layer

- **Status:** Accepted (2026-09-27)
- **Design doc:** `design/episode2_runner_wirespec_design.md`
- **Skills:** `ep2-layered-production`, `ep2-runner-level-grammar`, `ep2-motion-emotion`

## Context
The founder rejected the runner as "way too slow", "cheap", "too simple": three always-available
carts meant a lane switch never cost anything, and statue-like characters slid on rails.

## Decision
1. **Cart attrition lives in the sim** (`runner_graybox.gd`): per-rail `_cart_alive`, boulders and
   `rail_events` ("end") destroy carts, "spawn" events restore them, hops reach only adjacent live
   carts, losing the cart under you costs a hit and bails you, no cart = derailed. New signals:
   `cart_wrecked`, `cart_spawned`, `hop_blocked`, `rider_bailed`, `gold_collected`.
   Layout options are passed through `setup(..., opts)` by the session root — the session root
   stores no new state.
2. **Speed ramps** per leg (`speed.base → speed.max` over 900 m) instead of a flat 12 m/s.
3. **Solvability is a test, not a hope**: `RunnerAutopilot` (shared by the test and `?ep2bot=1`)
   must clear every leg with zero hits; a do-nothing run must fail.
4. **Motion/emotion is its own layer** (`runner_motion.gd`): pure functions pick skeletal clips
   from sim state and event timers; the view only plays them. Meshy-rigged GLBs replace the static
   characters, with the static models as fallbacks.

## Consequences
- Track design now has resource strategy (split convoy, bait, only-cart stretches).
- The view grew a cart life cycle (wreck/dead/spawn preview), gold, streaks and a HUD cart strip.
- Web builds must keep `threaded_cull_minimum_instances` raised (docs/research/3d/001): richer
  scenes crossed Godot 4.3's 1000-instance non-threaded culling bug.
- Rigged characters lose PBR normal maps (Meshy rig output is base-colour only).
