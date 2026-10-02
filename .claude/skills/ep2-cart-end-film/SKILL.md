---
name: ep2-cart-end-film
description: Episode 2 cart-end beat - the track visibly runs out, Lil Blunt panics, then the cliff-jump film match-cuts in with no dead pause. TRIGGER on "the video of Lil Blunt flying out the cart is late/cheap", any edit to cliff_jump_cinematic.gd, CLIFF_HANDOFF, PANIC_AT, the cliff mouth/boards in runner_view.gd, or chamber entry timing.
---
# Order of events (all in sync, nothing timer-driven)
1. **Telegraph** (runner_view `_build_cliff_mouth`): boards at -150/-70/-25 m, rails thin to a snapped trestle.
2. **Panic** (`RunnerGraybox.cliff_panic(level)` at PANIC_AT = 150/110/70/35 m): rising camera tremble + FOV widen
   (`get_panic()`), `panic` voice barks (`vo_lb_panic_1..4`).
3. **Warm** : level 1 triggers `Ep2SessionRoot._warm_chamber_assets` (threaded GLB load) so the cut never hitches.
4. **Match-cut**: the runner hands over `CLIFF_HANDOFF` (14 m) short of the mouth; the film's cart starts at
   `CART_START_Z = -14` at `CART_SPEED = 28`. Keep these two in step - never restore a 2 s replay of the approach.
5. Film: launch -> bullet time -> far ledge -> head hit -> blackout (unchanged).
# Gate
Cliff film test + runner test green; capture a runner frame at -35 m and the first film frame.
