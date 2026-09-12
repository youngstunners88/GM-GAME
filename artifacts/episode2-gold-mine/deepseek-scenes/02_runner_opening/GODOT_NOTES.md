<!-- dispatched: deepseek/deepseek-v4-flash-vision-exp
     prompt: prompts/deepseek-ep2-scene-02-runner.md
     files inlined: 2
     images attached: 3 (artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg, artifacts/founder-art/references/ep2_runner_ref_1_boulder_bandits.jpg, artifacts/founder-art/references/ep2_runner_ref_2_zipline.jpg)
     tokens: 15527 in / 22652 out
     cost: $0.0184
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->

> **UNVALIDATED MODEL OUTPUT until checked.** Authored by DeepSeek via
> OpenRouter from the founder reference images and the shipped Godot
> implementation. Claude's verification notes are in `_VERIFICATION.md` in this
> folder — read that before treating any number here as fact.

**Node hierarchy for the blockout**

```
RunnerGraybox (Node3D)
├── WorldEnvironment
├── Sun (DirectionalLight3D)
├── Ground (MeshInstance3D)
├── Cart (Node3D)
│   ├── CartMesh (MeshInstance3D) — fallback box
│   ├── minecart.glb (Node3D) — real model
│   └── lil_blunt_placeholder.glb (Node3D) — rider
├── Visuals (Node3D)
│   ├── Walls (Node3D)
│   ├── Ceilings (Node3D)
│   ├── GoldVeins (Node3D)
│   ├── TimberFrames (Node3D)
│   ├── Rails (Node3D)
│   ├── Sleepers (Node3D)
│   ├── Hazards (Node3D)
│   ├── ZipCables (Node3D)
│   ├── Gate (Node3D)
│   ├── Lanterns (Node3D)
│   └── Props (Node3D) — gold piles, rock chunks, hanging baskets
└── Camera (Camera3D)
```

**Collision intent**

- Cart: no physics body. Position driven by logic (lane lerp, jump/gravity). The "collision" is obstacle hit detection (z-window 1.0, x-window 0.8).
- Walls: no collision. The cart is constrained to lanes by logic, not physics. The walls are scenery.
- Hazards: no physics bodies. They're data + visual meshes. Hit detection is data-driven.
- The high-fidelity pass should NOT add physics bodies to the cart or hazards. The data-driven hit detection is the game design. Physics bodies would introduce jitter and make the hit windows unreliable.

**Audio hook points (VARCO stems)**

| Stem | Trigger |
|---|---|
| `ep2_runner_bed_mine_loop_01` | Scene start, loop. Mine bed ambient — low rumble, distant drips. |
| `ep2_runner_cart_rails_loop_01` | Scene start, loop. Cart on rails — rhythmic clatter, tied to cart movement speed. |
| `ep2_runner_zipline_rush_01` | Entering a zip segment (edge-detect `_ziplining` false→true). The rush of the cable. |
| `ep2_runner_duck_01` | `duck_start()` when `_is_ducking_effective()` becomes true (after `DUCK_MIN_HOLD`). The duck sound. |
| `ep2_runner_jump_land_01` | `_cart_y` reaches 0 after being > 0 (landing). The cart landing sound. |
| `ep2_runner_arrow_flyby_01` | Arrow hazard within ~10 m ahead (distance check). The arrow whoosh. |
| `ep2_runner_boulder_roll_01` | Boulder hazard within ~10 m ahead. The boulder rumble. |
| `ep2_runner_bear_distant_01` | Approaching a pocket with bears, or at the chamber gate. The bear growl. |
| `ep2_runner_score_drone_loop_01` | Reserved for the score/collectible system that comes later. Not triggered in the graybox. |

**CSG/primitives vs real GLB later**

Current: BoxMesh, SphereMesh primitives for everything. ~600 MeshInstance3Ds. 14 fps in heavier chamber on software-rendered browser.

Where detail is worth cost:
- Gold veins (147 meshes): worth it, but should be instanced or merged. The glitter is the "gold mine" read.
- Timber frames (39 meshes): worth it. The sense of speed.
- Lanterns (17): worth it. Readability + on-model.
- Boulder/arrow silhouettes: worth it. Hazard readability.

Where detail is NOT worth cost:
- Sleepers (80 meshes): merge into a single mesh or use MultiMesh. The rhythm is enough, individual ties don't need to be separate meshes.
- Wall segments (39 meshes): flat boxes are fine. The pockets do the work.
- Gold piles (3): enough. Don't add more.

GLB later: minecart.glb, lantern.glb, boulder.glb, gold_pile.glb, rock_chunk.glb, lil_blunt_placeholder.glb. Each has a primitive fallback.

Optimization: use MultiMeshInstance3D for sleepers and gold veins. Merge wall segments into fewer meshes. This should get the mesh count down to ~200.

---
