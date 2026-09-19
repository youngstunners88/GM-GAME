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

**Palette.** Grounded in the four attached references. For the smelting facility, the forge environment overrides the base ambient — the surfaces themselves remain from `Ep2Palette`. The Bull's gear is added as new locked values (not in the current palette), sampled from the armed/whiskey references.

| Surface | Hex | Metallic | Roughness | Emission | Source |
|---|---|---|---|---|---|
| Rock (walls) | `#2C2E33` | 0.0 | 0.78 | – | ref 4 (cool charcoal stone) |
| Rock (deep/floor) | `#1F2126` | 0.0 | 0.92 | – | ref 4 (shadowed stone) |
| Gold (molten/pours) | `#EDC35F` | 0.80 | 0.23 | `#FFC85A` @ 0.50 | ref 1 & 4 (molten gold, nugget carts) |
| Gold vein (in rock) | `#D9AC48` | 0.65 | 0.34 | `#FFC24D` @ 0.12 | ref 4 (ore embedded in wall) |
| Timber (posts/beams) | `#51321C` | 0.0 | 0.85 | – | ref 4 (cart wood, mine supports) |
| Wood (bench/crate) | `#7A5227` | 0.0 | 0.80 | – | ref 4 (lighter crate wood) |
| Brass (buckles, banding) | `#9A7039` | 0.75 | 0.42 | – | ref 4 (brass banding on cart) |
| Iron (rails, molds) | `#9BA0A8` | 0.30 | 0.38 | – | ref 4 (rail iron; kept low-metallic for Compatibility) |
| Lantern (emissive) | `#FFC170` | 0.0 | 0.50 | `#FFB55E` @ 1.1 | ref 1 & 4 (warm lamp cores) |
| Forge glow (crucibles) | `#FF8A3C` | 0.0 | 0.50 | `#FFB55E` @ 1.8 | ref 1 (molten pour light) |
| Bull hide | `#2B2A28` | 0.0 | 0.75 | – | ref 2 & 3 (black bull) — *but see REVIEW.md* |
| Bull bandana | `#A52A2A` | 0.0 | 0.80 | – | ref 2 (red bandana) |
| Bull leather straps | `#6E6350` | 0.0 | 0.85 | – | ref 2 & 3 (leather harness) |
| Winchester wood | `#51321C` | 0.0 | 0.70 | – | ref 2 (rifle stock) |
| Winchester metal | `#77797C` | 0.80 | 0.40 | – | ref 2 (rifle barrel) |
| Whiskey glass | `#EDC35F` (liquid) | 0.0 | 0.10 | – | ref 1 (amber whiskey) |
| Cigar ember | `#FF9A3C` | 0.0 | 0.45 | `#FF9A3C` @ 2.2 | ref 1 (lit cigar tip) |

**Surface language.** Wet rock (cool charcoal, high roughness, not glossy). Iron (moderate metallic, light grey — never near-black due to no reflections in Compatibility). Timber (warm brown, high roughness, reads as aged mine wood). Gold dust (high metallic, low roughness, small emission — gold carries through albedo + roughness, not reflection). Heat (warm ambient, warm fog, glow on true HDR sources only). The Bull's hide is near-black but always lit by a dedicated warm key so he never collapses into a silhouette.

**Reference provenance.**  
- Ref 1 (`inferno_bull_smelting.jpeg`): staging, forge glow, whiskey, cigar, molten gold.  
- Ref 2 (`inferno_bull_armed.jpeg`): Bull's black hide, red bandana, leather straps, Winchester.  
- Ref 3 (`inferno_bull_whiskey.jpeg`): overalls, pickaxe, relaxed posture — confirms the Bull's build and hide colour.  
- Ref 4 (`ep2_runner_ref_3_minecart_ride.jpg`): rock, timber, brass, gold nuggets, lantern light — the room must belong to this world.

**Explicitly OUT of style.**  
- **No volumetric fog, SSR, SSAO, or SDFGI.** Compatibility backend does not support them; they would silently no-op and cost performance.  
- **No metallic > 0.80.** A metallic surface with no reflection source renders near-black in Compatibility. Keep metals modest and carry colour via albedo + roughness + emission.  
- **No pure white or blown-out surfaces.** The forge environment is warm and bright, but the anti-blowout rule stands: rock must remain visibly cool and dark, and gold must be the brightest thing in frame.  
- **No cartoon or clean sci-fi.** This is hyper-real industrial gold-mine weight.  
- **No generic fantasy dungeon.** No torches with blue flames, no stone arches, no moss.  
- **No red/orange hazard colour code on gameplay markers.** The gate stays green (Lil Blunt's colour). The only red in the room is the Bull's bandana.  
- **No blue-grey haze.** Fog is warm (`#6B3D1C`); a cool haze would make the scene read as a night cave, not a furnace.  
- **No bloom on ordinary surfaces.** Glow is HDR-thresholded (1.1 in forge) so only lantern cores, crucible pours, and gold glints bloom.  
- **No gold veins that look like decals.** Emission is capped at 0.12; gold in rock must read as embedded, not painted on.

---
