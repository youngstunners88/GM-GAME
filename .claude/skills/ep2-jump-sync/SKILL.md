---
name: ep2-jump-sync
description: Cart-end jump and zipline jump share one rule - the gap is visible, the rider reacts (look down, grab, hunch), then the consequence fires from the position, never from a timer. TRIGGER on "the jump is late/delayed/out of sync", edits to PANIC_AT, CLIFF_HANDOFF, cliff_jump_cinematic.gd CART_START_Z/CART_SPEED, zip start/end, or hero_pose panic.
---
# Order
1. Edge visible (boards + thinning rails from `PANIC_AT[0]` = 120 m).
2. `RunnerGraybox.get_panic()` 0..1 -> `Motion.hero_pose(panic)`: pitch down, sink, tremble; gun hand released so both hands sit on the cart rim; camera tremble + FOV; barks.
3. Hand-over at `chamber_z - CLIFF_HANDOFF` at the SAME speed the film cart starts with (`CART_SPEED`). No replay of the approach.
4. Zipline: the hook is the jump input while the cable is in reach; the punish (pit) is a position check.
# Never
A hidden timer that fires after the animation, or shake standing in for a reaction.
