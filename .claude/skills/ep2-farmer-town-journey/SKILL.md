---
name: ep2-farmer-town-journey
description: Continue the existing farmer, skinned donkey and independently rotating cart from the desert greeting into town for a purposeful business stop, preserving identity and progress across retained rooms.
---

# The same farmer arrives

Use ep2-world-presence-and-consumables, ep2-road-donkey-cart where installed, ep2-town-shopping and ep2-town-proof. Preserve the articulated Ep2RoadCart assets, grounded donkey, axle speed, seated driver, reins and greeting order.

- Trace who owns the cart after the quad overtakes it and after woods is parked. An inactive retained viewport freezes scripts; do not claim continued travel from a final `_cart_s` value or create an unrelated second farmer.
- Carry the actual cart instance, route distance, wheel/gait phase and schedule into the active town through one owner. Advance simulation once per active tick, independent of player teleporting or looking away; preserve pause, retry, backtracking and snapshot behavior.
- Follow the authored road into a clear town lane, park clear of the duel/witness and all doorways, and perform an intelligible business errand at an existing shop. Use existing founder models and local rig authoring; no paid regeneration is needed. Keep cart, donkey, driver/props in consistent contact. Do not make a compulsory new quest or replay rewards/greetings.
- Test the original warning→greeting→pass behavior, actual cross-room identity, movement while town is active, grounded wheels/hooves, purposeful arrival/dwell/departure, pause and restoration. Capture the journey and business action over time from player height.

## Verified repair lesson

The session owns the actual cart exactly once; the ambient crowd must exclude reserved workers from ordinary choices, social partners and celebrations while still owning their flee/shelter safety. Yield to duel/quiet contexts and require actual goal distance before transferring goods. Test a real set_context(duel), resume and killed carrier. Check is_instance_valid before any `is` type test on retained room references during teardown.
