<!-- dispatched: openai/gpt-6-astra
     prompt: prompts/astra-ep2-art-direction.md
     files inlined: 0
     images attached: 3 (artifacts/founder-art/references/ep2_runner_ref_1_boulder_bandits.jpg, artifacts/founder-art/references/ep2_runner_ref_2_zipline.jpg, artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg)
     tokens: 7848 in / 2142 out
     cost: $0.1856
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**These are visually estimated starting settings—not measured source materials.** Lit images cannot uniquely determine albedo, metallic, roughness, emission, or light energy. Lighting/readability adjustments below are proposals, not additional founder-approved direction.

## 1. Palette table

Hex = **sRGB colour entered in the Inspector**. Emission strength = energy multiplier; **0 means disabled**.

| Surface | Albedo | Metallic | Roughness | Emission colour / strength |
|---|---|---:|---:|---|
| Cave rock | `#302D29` | 0.00 | 0.78 | — / 0 |
| Embedded gold | `#E5B84F` | 1.00 | 0.28 | — / 0¹ |
| Weathered wood | `#51321C` | 0.00 | 0.85 | — / 0 |
| Brass/bronze fittings, helmet | `#9A7039` | 0.90 | 0.42 | — / 0 |
| Iron rail | `#626367` | 0.95 | 0.38 | — / 0 |
| Lantern luminous core | `#FFD58A` | 0.00 | 0.50 | `#FFD080` / 4.0 |
| Granite boulder | `#777773` | 0.00 | 0.82 | — / 0 |
| Loose gold / gold pile | `#EDC35F` | 1.00 | 0.23 | — / 0¹ |
| Steel zipline cable | `#777C83` | 1.00 | 0.32 | — / 0 |
| Arrow shaft / fletching | `#95683C` | 0.00 | 0.78 | — / 0 |
| Arrowhead | `#77797C` | 0.95 | 0.40 | — / 0 |

¹ Gold is visibly bright, but **self-emission is not established**. Start reflective; do not make every gold patch a lamp.

**Danger colour:** natural brown shafts and grey metal tips. **No reference-supported red/orange hazard code.** Spark orange is not an exclusive danger signal.

For texture authoring: keep rock crevices around `#17191B`; reserve lower rock roughness, approximately **0.35**, for sparse glossy patches—not entire walls.

## 2. Value structure

| Check | Starting target |
|---|---|
| Rock : embedded-gold **linear albedo luminance** from the table | Approximately **1:17** |
| Typical displayed rock brightness, grayscale 0–1 | **0.08–0.18** |
| Displayed broad gold areas, excluding glints | **0.45–0.70** |
| Practical displayed rock : gold brightness | Approximately **1:4–1:6** |
| Near-white values, **0.90–1.00** | Small lamp cores, sparks, gold glints only |

The albedo ratio is **not** the final lighting ratio: metallic gold depends heavily on reflected illumination.

Start ambient energy at **0.15**, exposure at **1.0**. Do not brighten the entire cave to rescue dark gold; correct its lighting/reflections first.

## 3. Readability at speed

Material-only fixes first; lighting alternatives require a separate change.

| At-risk pair | Cheapest material-only adjustment | If still unreadable |
|---|---|---|
| Boulder / cave wall | Maintain `#777773` boulder versus `#302D29` wall; avoid gold-coloured mottling on boulder | Cool upper/side rim from the key light |
| Arrow / wood supports | Shaft `#AD8050`; tip roughness **0.28** for a distinct highlight | Cool grazing light; material changes alone may not rescue a tiny projectile |
| Rail / cable / dark rock | Keep steel neutral-cool; roughness **0.30–0.38** | Grazing cool light rather than warm emission |
| Cart / timber background | Separate wood **0.85** roughness from fittings **0.42** | Side light across cart bands |
| Loose gold / decorative veins | Keep loose gold roughness **0.23**, veins **0.35** | If these mean different gameplay things, founder must approve an additional cue |

**Avoid emissive hazard outlines:** not established by these references. Silhouette changes are outside this commit.

No sub-second guarantee is possible without **gameplay camera, resolution, speed and hazard screen size**.

## 4. Lighting recipe

**Proposed calibration baseline:** Forward+ renderer, physical light units disabled, **1 world unit = 1 metre**. Keep this separate from the materials-only commit.

### Environment and key light

| Inspector setting | Start value |
|---|---|
| Ambient Light → Source | Color |
| Ambient Light → Color | `#899CB5` |
| Ambient Light → Energy | **0.15** |
| Ambient Light → Sky Contribution | **0.0** |
| Tonemap → Mode | Filmic |
| Tonemap → Exposure | **1.0** |
| Tonemap → White | **6.0** |
| Directional light → Color | `#B9CDE3` |
| Directional light → Energy | **0.65** |
| Directional light → Shadows | Enabled |
| Key direction | **55° downward**, **30° off camera-forward** |

That direction is a proposed camera-relative starting angle, **not an extracted world rotation**. Scene/camera transforms are missing.

### Atmosphere and glow

| Inspector setting | Start value |
|---|---|
| Regular Fog | Disabled |
| Volumetric Fog → Enabled | On |
| Volumetric Fog → Density | **0.008** |
| Volumetric Fog → Albedo | `#8B929A` |
| Volumetric Fog → Emission | Black / **0** |
| Volumetric Fog → Length | **64 m** |
| Volumetric Fog → Ambient Inject | **0.20** |
| Glow → Enabled | On |
| Glow → Blend Mode | Screen |
| Glow → Intensity | **0.35** |
| Glow → Strength | **1.0** |
| Glow → Bloom | **0.0** |
| Glow → HDR Threshold | **1.3** |

Bloom **0** avoids lifting ordinary surfaces; HDR lamp cores still produce glow. Increase lantern emission before lowering the glow threshold.

### Lantern point lights

| Setting | Start value |
|---|---|
| Colour | `#FFBE70` |
| Energy | **2.0** |
| Range | **5 m** |
| Attenuation | **1.5** |
| Placement | At visible lantern cores, on side supports—not lane centres |
| Initial spacing, if scene scale permits | **8–12 m**, avoiding continuous overlapping warm fill |

**Missing dependency:** a reflection source for the metals. No sky/reflection resource or scene setup was provided. Ambient colour alone will not reproduce the gold glints.

## 5. What the references do NOT cover

| Missing guidance/input | Question or requirement |
|---|---|
| Dedicated on-foot chamber treatment | Same lighting hierarchy, or a distinct encounter look? |
| Gameplay colour semantics | How do damage, pickups, safe routes and interactables differ? |
| Gold semantics | Are loose gold and wall veins both collectible? |
| Small green/cyan distant lights | What do they represent? Do not assume checkpoints or safety. |
| Unshown hazards and telegraphs | Approved materials/colours for each additional hazard type? |
| Runner visibility limits | Camera, FOV, speed, resolution, minimum hazard pixel size? |
| Texture production inputs | UV layouts, texture density, material slots and masks were not supplied. |
| Engine calibration | Renderer, world scale, current environment and reflection setup? |

**Materials-only limit:** grain, rock relief, gold distribution and cable strands need texture maps. Uniform hex values on unchanged boxes cannot reproduce those reference features.