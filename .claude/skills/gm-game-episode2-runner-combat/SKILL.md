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
