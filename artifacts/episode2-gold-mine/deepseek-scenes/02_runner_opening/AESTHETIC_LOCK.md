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

**Palette table** (grounded in ref 1, 2, 3; answers findings 1, 2, 5)

| Surface | Hex | Metallic | Roughness | Emission | Ref | Finding |
|---|---|---|---|---|---|---|
| rock | `#2C2E33` | 0.0 | 0.78 | — | 1,2,3 | #2 |
| rock_deep | `#1F2126` | 0.0 | 0.92 | — | 1,2,3 | #2 |
| gold_vein | `#D9AC48` | 0.65 | 0.34 | `#FFC24D` 0.12 | 1,2,3 | #5 |
| gold_seam (clustered) | `#E8BC55` | 0.70 | 0.28 | `#FFC85A` 0.18 | 2,3 | #5 |
| wood (supports) | `#51321C` | 0.0 | 0.85 | — | 1,2,3 | #2 |
| wood_light (sleepers, cart fallback) | `#6B4A2F` | 0.0 | 0.80 | — | 3 | #1 |
| crate | `#7A5227` | 0.0 | 0.80 | — | 1 | #1 |
| brass | `#9A7039` | 0.75 | 0.42 | — | 3 | — |
| iron (rails) | `#A8ADB5` | 0.30 | 0.35 | `#FFFFFF` 0.05 | 3 | #3 |
| steel_cable | `#777C83` | 0.80 | 0.32 | — | 2 | — |
| gold | `#EDC35F` | 0.80 | 0.23 | `#FFC85A` 0.50 | 3 | #5 |
| lantern | `#FFC170` | 0.0 | 0.50 | `#FFB55E` 1.1 | 1,2,3 | — |
| spark | `#FFB259` | 0.0 | 0.45 | `#FF9A3C` 2.2 | 1,2 | — |
| boulder | `#777773` | 0.0 | 0.82 | — | 1 | #1 |
| arrow | `#AD8050` | 0.0 | 0.70 | `#FFB070` 0.55 | 1 | #1 |
| arrow_head | `#77797C` | 0.80 | 0.40 | — | 1 | — |
| gate | `#4EC97A` | 0.0 | 0.55 | `#5BE68C` 0.9 | 3 (leaf) | — |
| leaf_green | `#4E8F35` | 0.0 | 0.60 | — | 1,2,3 | — |
| bandit | `#2B2A28` | 0.0 | 0.75 | — | 1 | — |
| bandit_cloth | `#6E6350` | 0.0 | 0.85 | — | 1 | — |

**Surface language**

- **Rock**: cool charcoal, matte, rough. The dark ground everything reads against. Never warm — warm rock is what made the scene read as "brown timber" (finding #2). The cool comes from albedo (`#2C2E33`), the brightness comes from the lighting rig (ambient 0.42, key 0.7), not from lifting the albedo.
- **Wood**: warm brown, matte. The supports and sleepers. Never competes with gold. The sleepers are wood_light (`#6B4A2F`) so they read against the dark floor, but they're still darker than the rails.
- **Gold**: the brightest thing in frame. Clustered seams, not isolated tiles (finding #5). Slight emission for sparkle. The gold_vein is `#D9AC48` with emission `#FFC24D` 0.12; the gold_seam (clustered) is `#E8BC55` with emission `#FFC85A` 0.18. Gold piles are `#EDC35F` with emission `#FFC85A` 0.50.
- **Iron**: cool grey, low metallic (0.30) because Compatibility backend has no reflections. Slight emission (`#FFFFFF` 0.05) to catch lantern light. The rails are the bright line that leads the eye (finding #3).
- **Lanterns**: warm, emissive. The light source. Every reference hangs lamps on timber.
- **Hazards**: distinct value steps. Boulders are pale (`#777773`) — the palest large objects in frame (ref 1). Arrows are brown (`#AD8050`) with grey tips (`#77797C`) — no red hazard color (ref 1). Crates are lighter wood (`#7A5227`) — distinct from the supports.

**Value hierarchy for finding #1**

Floor (`#1F2126`) < Sleepers (`#51321C`) < Cart (`#6B4A2F`) < Crate (`#7A5227`) < Boulder/Arrow (`#777773` / `#AD8050`). Each playable element occupies its own value step so nothing collapses into shadow.

**Which reference each decision came from**

- Cool charcoal rock: ref 1, 2, 3 (all three show cool stone)
- Warm timber: ref 1, 2, 3 (all three show warm wood)
- Gold veins clustered: ref 2, 3 (both show veins running through rock)
- Iron rails: ref 3 (the minecart ride shows rail iron)
- Steel cable: ref 2 (the zipline shows braided steel)
- Lanterns: ref 1, 2, 3 (all three show warm lamps)
- Boulder pale granite: ref 1 (the boulder bandits show pale boulders)
- Arrow brown shaft, grey tip: ref 1 (the bandits show brown arrows)
- Brass banding: ref 3 (the cart shows brass banding)
- Gold nugget piles: ref 3 (the minecart ride shows gold heaps)

**What is explicitly OUT of style**

- No red/orange hazard color code (ref 1 shows brown arrows, not red)
- No weed theming on enemies (global rule — balaclava bears, not weed-themed)
- No volumetric fog (Compatibility backend doesn't support it)
- No SSR/SSAO/SDFGI (Compatibility backend doesn't support them)
- No metallic > 0.8 without a reflection source (renders near-black)
- No pure white lanterns (emission energy 4.0 clipped to white discs)
- No flat yellow rectangles for gold (reads as decals, not ore)
- No smooth, uniform tunnel walls (references show uneven, layered rock)
- No isolated gold tiles (references show clustered seams)
- No warm rock (references separate cool stone from warm wood)
- No red arrows (references show brown arrows)

---
