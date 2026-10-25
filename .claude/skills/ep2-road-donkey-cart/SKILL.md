---
name: ep2-road-donkey-cart
description: The farmer on his donkey cart on the desert road (founder's own Drive model, 2026-10-14) - the quad slows behind him so it does not spook the donkey, Inferno greets him, he answers, Lil Blunt answers, they pass and open up again. TRIGGER on "donkey", "cart", "farmer", "man on the cart", "drive past", "wave", "slow down and pass", any edit to _build_cart / _tick_cart / CART_* in woods_quad.gd, or src/episode2/assets/town/donkey_cart.glb.
---

# The donkey cart (founder 2026-10-14)

> "On the road they should drive past the man on the cart with the donkey. They should slow down and then pass him and wave."

- **Animated rebuild (2026-10-26)**: `Ep2RoadCart` (`src/episode2/actors/ep2_road_cart.gd`) loads separately generated Meshy donkey/farmer and an authored cart from `src/episode2/extras/road_cart/`. The donkey has a 17-bone skinned quadruped walk (1.5 m per cycle); the farmer has his own 24-bone skin with `seated_drive` and `seated_greet`. Two `Wheel_*` pivots roll on local X at travel / 0.62 m. Bone-following leather reins connect the curled left hand to both bridle cheeks. See `design/ep2/road-cart/provenance.json` and reproducible builders/editable sources in `tools/ep2_cart/` and `design/ep2/road-cart/sources/`.
- **Original founder model**: `src/episode2/assets/town/donkey_cart.glb` remains unchanged as the streamed-art fallback. It is the fused static bake; do not try to retarget it or substitute it for the animated assembly during verification. Its nose is +X; fallback scale 3.8 and -90° yaw are local to that model. New parts use metres, ground y=0, nose +Z.
- **Where**: `CART_S0 = 868` (arc length on the quad's road: past the last pines, in the desert - no bears there), 3.1 m to the right of the centre line, plodding at
  `CART_SPEED = 2.4` m/s toward town once the ride starts. A distance-driven skeletal walk with grounded stance; no whole-assembly bob.
- **Pass** (`_tick_cart`, gate `tests/ep2_companion_cart_test.tscn`): within 70 m behind him the quad eases down to `CART_SPEED + 2.7` (~5 m/s) -> `vo_bull_cart1` (warns about the animal) ->
  within 13 m `vo_bull_cart2` (Inferno greets) -> `vo_cart_man` (the farmer answers, voice Clyde `2EiwWnXFnvU5JabPnv8n`) -> `vo_lb_cart` (Lil Blunt) -> 24 m past him the road opens up.
  The lines are queued so a late ride-start show cannot swallow the warning (`_cart_warned`).
- **The wave**: `vo_cart_man` starts the 3 s seated greeting; the right hand waves, while the left grip and seated hips remain fixed. Return to seated driving afterward. The cart keeps rolling after the quad passes. Preserve Inferno's existing performance; this is the farmer's independent skeleton.
- **Verification**: `tests/ep2_road_cart_motion_test.tscn` checks imported motion, world-space stance drift, hoof height, wheel sign/radius, independent hands/seat, rendered rein endpoints and retry. The companion/cart test preserves slowdown, passing and exact dialogue order. `tools/ep2_cart/encounter_review.tscn` captures the actual passenger camera; `pose_review.tscn` is only a closer isolated inspection.
- Retry (death in the woods) resets the cart (`_cart_s`, `_cart_state`, `_cart_warned`).
