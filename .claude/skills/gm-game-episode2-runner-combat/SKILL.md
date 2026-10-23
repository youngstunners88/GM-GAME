---
name: gm-game-episode2-runner-combat
description: Episode 2 3D gold-mine runner. TRIGGER on episode 2, runner, cart, bear, revolver, pickaxe, aim, reload, Meshy. Current graybox is rejected.
---

# Product (founder lock)

src/episode2/runner/ is a 3D over-the-shoulder minecart runner.
Lil Blunt sits in the cart with:
  - golden revolver (new; 3D mesh from Meshy using
    artifacts/founder-art/references/stage3_golden_revolver_reference.jpg)
  - miner pickaxe (already in the cart idea; 3D mesh, not a 2D sprite)

Combat on the rails:
  - mouse aims (look / reticle on the tunnel)
  - LMB fires the revolver
  - 6-round cylinder; empty auto-reload; R manual reload
  - reload has a visible break-open + audible click (ElevenLabs or SFX)
  - bears are shootable hazards (founder refs
    artifacts/episode2-gold-mine/references/IMG_2492_cart-jump_bears-arrows-boulders.jpg
    artifacts/episode2-gold-mine/references/IMG_2497_broken-cart_bears-arrows-boulder.jpg)
  - arrows and boulders remain dodge/jump/duck threats
  - pickaxe is a close swipe if a bear boards the cart (not the primary gun)

Do not ship a graybox tunnel with a silhouette hero.

# Code homes
  src/episode2/runner/runner_graybox.gd   → promote off graybox
  src/episode2/runner/runner_view.gd
  src/episode2/session/
  src/episode2/assets/                    ← GLBs land here
  src/shooter/                            ← 2D shooter; steal input ideas, do not parent 2D weapons into 3D
  tests/  add ep2_runner_revolver_test.gd

# Art path (use gm-game-tool-roster)
  1. Presence-check MESHY_API_KEY.
  2. Meshy image-to-3D from the founder stills:
       lil_blunt, golden_revolver, pickaxe, bear, cart
  3. Decimate. Import Godot. Skeleton3D / rigid body as appropriate.
  4. MuAPI only for concept / trim / gold-vein plates if Meshy needs a cleaner still.
  5. ElevenLabs for fire / reload / bear hit.
  6. Browser Use capture: mid-tunnel, reticle on a bear, muzzle flash, reload.

# Banned
  Touching Episode 1 stages, Protocol Portals, Vault, Knox.
  80M-poly imports.
  Printing API keys.
  Claiming the runner is done while runner_graybox is still the playable scene.
  Installing Keel / typesafe plugins.

# Done
  Player can aim with mouse, fire, empty the cylinder, reload, and kill a bear
  in a web export capture. Jev votes runner_is_shootable + hero_is_not_placeholder.

# TOUCH (phones and tablets; added 2026-10-23 - full detail in `ep2-mobile-touch`)
The cart combat above is the DESKTOP contract and is unchanged. On a touch device the runner uses profile `ep2_runner` (returned by `Ep2SessionRoot.touch_profile()` while `RUNNER` is running),
and every verb reaches `ep2_session_root.gd` as an ordinary InputMap action from the touch layer (`TouchActions`) - never a raw touch parser:

| Verb | Touch | Router (RUNNER mode) |
|---|---|---|
| hop a lane | swipe sideways >= 22 dp on the left pad (re-anchors: another 22 dp hops again) | `move_left` / `move_right` pulse -> `runner_switch_lane_left/right()` |
| jump | swipe up >= 20 dp (120 ms lockout, finger must come back down 10 dp) | `jump` pulse -> `runner_jump()` |
| duck | swipe down >= 24 dp, held while below anchor + 12 dp, minimum hold 150 ms | `move_down` press/release -> `runner_duck_start/end()` |
| revolver | the ATTACK button (bottom-right) | `attack` -> `runner_shoot()` = the existing AUTO-AIM shot at the nearest archer |
| aimed shot | a tap in a FREE area (outside every control) | emulated LMB (finger 0) -> `runner_fire_at_screen(pos)`; pads are STOP so they never fire |
| pickaxe | the PICKAXE button | touch-only action `ep2_touch_swipe` -> `runner_swipe()` |
| reload | none: the runner auto-reloads on empty and on a dry fire (`runner_graybox.gd` `_after_shot` / `_try_fire_round`) | `ep2_touch_reload` -> `runner_reload()` exists but has no runner button |
| pause / exit | top-right pause icon -> wordless card (PLAY / HOME); run over -> RETRY (`jump`) + HOME (`ui_cancel`) after 0.8 s | `Ep2Entry` |

Rules: no FirePad / aim assist / `ep2_fire` in v1 (the auto-aim ATTACK button replaces them; a steer thumb on the pad cannot also aim with a second finger because only finger 0 makes an emulated mouse event).
No resting reticle on touch (the initial `get_mouse_position()` is (0,0)): a ring appears at the last tap for 0.45 s and the rider's gun arm aims there for 0.6 s, then falls back to forward.
Telegraph labels (`DUCK / HOP! / JUMP / SWIPE! X / right-click`) and `R - reload` / `RELOADING` are replaced by flat glyphs on touch (`TouchUi.keys_shown()`); desktop words return when the flag is off.
Portrait pauses the sim behind the "turn your phone" cue. Gates: `tests/ep2_touch_controls_test.tscn` (sections `runner`, `lifecycle`, `portrait`, `words`). Router fixes F5/F6/F8: see `ep2-free-roam-controls`.

