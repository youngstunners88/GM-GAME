---
name: ep2-road-donkey-cart
description: The farmer on his donkey cart on the desert road (founder's own Drive model, 2026-10-14) - the quad slows behind him so it does not spook the donkey, Inferno greets him, he answers, Lil Blunt answers, they pass and open up again. TRIGGER on "donkey", "cart", "farmer", "man on the cart", "drive past", "wave", "slow down and pass", any edit to _build_cart / _tick_cart / CART_* in woods_quad.gd, or src/episode2/assets/town/donkey_cart.glb.
---

# The donkey cart (founder 2026-10-14)

> "On the road they should drive past the man on the cart with the donkey. They should slow down and then pass him and wave."

- **Model**: the founder's `donkey cart 3d model.glb` (Drive folder 1KZNUdmE46lmgdMJJMeFdOLC9FXGAd69L): donkey + wagon + a bearded farmer in a hat, one Tripo mesh. **The GLB is
  rigged and skins to SHARDS in Blender and Godot - use the FBX from `donkey+cart+3d+model.zip`**, apply the rig at rest, drop it, decimate (UV borders kept, 14k faces)
  and shrink the textures to 1024: `python3 tools/ep2_blender/prep_founder_town_models.py cart <fbx> src/episode2/assets/town/donkey_cart.glb 14000` (see `ep2-founder-model-bake`).
  The model's nose is +X, ~1.0 x 0.59 x 0.88 units; the game scales it x3.8 (`CART_SCALE`) and turns it -90 degrees inside a holder so the holder's +Z is the way it travels.
- **Where**: `CART_S0 = 868` (arc length on the quad's road: past the last pines, in the desert - no bears there), 3.1 m to the right of the centre line, plodding at
  `CART_SPEED = 2.4` m/s toward town once the ride starts. A plod bob + sway (static model, no leg animation).
- **Pass** (`_tick_cart`, gate `tests/ep2_companion_cart_test.tscn`): within 70 m behind him the quad eases down to `CART_SPEED + 2.7` (~5 m/s) -> `vo_bull_cart1` (warns about the animal) ->
  within 13 m `vo_bull_cart2` (Inferno greets) -> `vo_cart_man` (the farmer answers, voice Clyde `2EiwWnXFnvU5JabPnv8n`) -> `vo_lb_cart` (Lil Blunt) -> 24 m past him the road opens up.
  The lines are queued so a late ride-start show cannot swallow the warning (`_cart_warned`).
- **The wave**: voice greetings carry it; the model has no separable arm and Inferno's arms must not be IK'd (tears the elbow). A real wave = a second baked arm pose of the driver
  (the `duo` trick in `ep2-founder-model-bake`) swapped twice; not built yet - say so rather than claim it.
- Retry (death in the woods) resets the cart (`_cart_s`, `_cart_state`, `_cart_warned`).
