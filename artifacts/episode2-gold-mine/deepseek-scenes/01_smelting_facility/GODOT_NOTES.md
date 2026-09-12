<!-- dispatched: deepseek/deepseek-v4-flash-vision-exp
     prompt: prompts/deepseek-ep2-scene-01-smelting.md
     files inlined: 3
     images attached: 4 (artifacts/episode2-gold-mine/references/inferno_bull_smelting.jpeg, artifacts/episode2-gold-mine/references/inferno_bull_armed.jpeg, artifacts/episode2-gold-mine/references/inferno_bull_whiskey.jpeg, artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg)
     tokens: 16038 in / 11622 out
     cost: $0.0112
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->

> **UNVALIDATED MODEL OUTPUT until checked.** Authored by DeepSeek via
> OpenRouter from the founder reference images and the shipped Godot
> implementation. Claude's verification notes are in `_VERIFICATION.md` in this
> folder — read that before treating any number here as fact.

**Suggested node hierarchy for the blockout.**

```
SmeltingFacilityChamber (Node3D)
├── WorldEnvironment (Environment, forge variant)
├── Sun (DirectionalLight3D, cool key, energy 0.7)
├── Visuals (Node3D)
│   ├── Geometry (Node3D) — CSG/Primitive meshes
│   │   ├── Floor
│   │   ├── Wall_L / Wall_R
│   │   ├── Ceiling
│   │   ├── Back_Wall
│   │   └── Timber_Posts/Beams
│   ├── Props (Node3D) — GLB or primitives
│   │   ├── Crucible_1/2/3
│   │   ├── Ingot_Rack_1/2
│   │   ├── Lantern_1/2/3
│   │   ├── Mold_Rack + Bench
│   │   └── Whiskey_Glass + Crate
│   ├── Characters (Node3D)
│   │   ├── InfernoBull (Node3D)
│   │   └── LilBlunt (Node3D)
│   └── Props_Dynamic (Node3D)
│       └── Winchester_1886 (Node3D)
├── Lights (Node3D)
│   ├── Crucible_Glow_1/2/3 (OmniLight3D)
│   ├── Lantern_Light_1/2/3 (OmniLight3D)
│   └── Bull_Key (OmniLight3D)
├── Camera3D
└── Collision (Node3D)
    ├── Floor_Static (StaticBody3D)
    ├── Wall_L/R_Static (StaticBody3D)
    ├── Ceiling_Static (StaticBody3D)
    ├── Back_Wall_Static (StaticBody3D)
    ├── Crucible_Static (StaticBody3D × 3)
    ├── Ingot_Rack_Static (StaticBody3D × 2)
    ├── Bench_Static (StaticBody3D)
    ├── Crate_Static (StaticBody3D)
    ├── Bull_Static (StaticBody3D)
    └── Exit_Area (Area3D)
```

**Collision intent.**  
- **Static bodies:** floor, side walls, ceiling, back wall, crucibles, ingot racks, bench, crate, and the Bull. These are physical blockers; the player cannot walk through them. The Bull is static because he is a companion anchor, not a physics object.  
- **Area3D:** the exit gate — triggers `_resolve()` when the player enters it after the parting line.  
- **No collision needed:** molds (they are hit targets, not physics objects — the current `shoot()` decrements a counter, no raycast), the whiskey glass (decorative), lanterns (decorative), the rifle (decorative prop that moves).  
- **Player:** currently a `Node3D` that moves only on Z. For the final pass, the player should be a `CharacterBody3D` if lateral movement is added; for the current linear rail, a `Node3D` is acceptable. No physics needed for the verb teach.

**Audio hook points (VARCO stem sections).**

| Stem | Beat / Moment |
|---|---|
| `ep2_smelt_furnace_roar_loop_01` | Ambient throughout. Fade in on `Beat.ARRIVAL`, hold steady. |
| `ep2_smelt_heat_haze_loop_01` | Ambient throughout, slightly louder near the crucibles (z > 4). |
| `ep2_smelt_pour_oneshot_01` | Fires on `Beat.ARRIVAL` (the cart brakes into the facility) and occasionally during the scene as background pours. |
| `ep2_smelt_whiskey_pour_01` | On `Beat.DRINK` — the shared drink. |
| `ep2_smelt_cigar_draw_01` | On `Beat.DRINK` — the Bull draws on the cigar. |
| `ep2_smelt_leather_chain_01` | On `Beat.HANDOFF` — the Bull shifts his gear to hand over the rifle, and on `Beat.EXIT` when he falls in as companion. |
| `ep2_smelt_workers_distant_loop_01` | Ambient background, lower volume than the furnace. |
| `ep2_smelt_score_hymn_loop_01` | Starts on `Beat.DRINK` and continues through `Beat.PROMISE` — the character beat. |

**What can stay CSG/primitives vs what needs a real GLB.**

- **Stays primitive:** the room shell (floor, walls, ceiling, back wall), timber framing, bench, crate, mold rack. These are simple industrial geometry; a later material pass on the same boxes will raise them. No organic or complex silhouette needed.  
- **Needs real GLB:**  
  - **Inferno Bull** — placeholder box cannot convey the character. Must be a high-fidelity model with the locked hide/bandana/leather/gear.  
  - **Lil Blunt** — the player's placeholder must become the small green leafy miner.  
  - **Winchester 1886** — a real rifle model is needed for the hand-off to read.  
  - **Crucibles** — need a pouring animation (see REVIEW.md). The current static cylinders are not enough.  
  - **Ingot racks** — real gold ingots and rack geometry.  
  - **Whiskey glass** — a proper glass with liquid, so the drink beat reads.  
  - **Lanterns** — real lantern meshes with glass and flame, not just omni lights.  
  These GLBs should be authored with the locked palette values in mind, not separate art direction.

---
