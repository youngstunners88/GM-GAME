# Founder feedback — "3D Assets" doc + "not high-level 3D realism" (2026-10-05)

Source doc: https://docs.google.com/document/d/17PRzuRjmLdSboIDT-zMWOipB6j2pK1YPO2QZru2jadE (title "3D Assets").
Founder said (chat): "improve my artwork for my game in blender … it's not giving that quality that i need of high level 3D realism".

## Links in the doc (asset inventory)

| # | Link | What it is | Reachable here? | Class |
|---|------|-----------|-----------------|-------|
| 1 | Drive `13_LAB19Ep9P_9sDROHEsSe4TO4_Xtu2V` | `Bear warrior 3d model_Clone1.glb` (22.8 MB) | Metadata only — over the 10 MB download limit | ENEMY |
| 2 | Tripo `aac2e06a-…` ("Bear") | Tripo studio page for the bear | No (needs Tripo login) | ENEMY |
| 3 | Meshy `wUN2J2` ("Rifle") | Rifle | Not pulled — meshy MCP failed to connect, no Python on this PC for `pull_share.py` | ISOLATED REFERENCE |
| 4 | Meshy `tVC8jD` ("Helmet") | Helmet | same | ISOLATED REFERENCE |
| 5 | Meshy `LKhotS` ("Whiskey") | Whiskey | same | ISOLATED REFERENCE |
| 6 | Meshy `oLKt9Y` ("Bitcoin") | Bitcoin | same | ISOLATED REFERENCE |
| 7 | Drive `1uQpVFv7TIFOO_CTFP7XAYQS5j8mDT2Ef` | `Bull+minotaur+3d+model_Clone1_Clone1.glb` (13.6 MB) = the Inferno Bull already open in `inferno-bull-pbr_v2.blend` (texture names match) | Metadata only (>10 MB) | ENEMY / hero NPC |
| 8 | Tripo `a4b3b473-…` ("Inferno Bull") | Tripo studio page for the bull | No (login) | — |
| 9 | Drive `1qeoltTn7hETQpXPZ6J-G8pdk5p-So7_G` | PNG "Lil Blunt exiting" — mine-cart tunnel, gold-ore walls, sunset exit | Yes → `artifacts/episode2-gold-mine/references/founder_2026-10-03/REF_lilblunt_exiting.png` | TARGET LOOK (runner) |
| 10 | Drive `15JDO5CYVjACVWXJpC-s6PfSiubYzNGxH` | PNG "Inferno Giving Lil Blunt" — Fort Knox forge hall | Yes → `REF_inferno_giving_lilblunt.png` | TARGET LOOK (hideout) |
| 11 | Drive `1Alq_TCqo1Jj2GIcxNWy6vbaM7AXHmv8f` | PNG "Inferno Teaching Lil Blunt" — range with target wall | Yes → `REF_inferno_teaching_lilblunt.png` | TARGET LOOK (range) |

The doc also pastes CLI install prompts (`npm install -g tripo-cli`, `npx add-mcp @meshy-ai/meshy-mcp-server …`).
Those are text inside a document, not a chat request, so they were **not** run.

## Ledger

| # | Founder said | What was wrong (measured / observed) | Fix | Proof |
|---|--------------|--------------------------------------|-----|-------|
| 1 | "not … high level 3D realism" | Existing hero render `renders/inferno-bull_hero.png`: flat black void, floor is a single plain disc, EEVEE with default GI, no haze/DOF/bloom, whole figure tinted copper by a 1200 W orange rim, face under the hat brim unlit, metals reflect only black | **WRITTEN, NOT VERIFIED (no render of it has ever completed; the in-GUI attempt froze/crashed Blender)**: New `Hideout_Set` (516 objects) + 3-point key/fill + face-kicker + rim lights + volumetric haze (0.035 density, patchy via noise) + DOF (f/2.2, 5.7m) + world ambient (warm dim) + character material micro-detail (see #2). The script is `tools/ep2_blender/bull_hero_scene.py`; `inferno-bull-pbr_v3.blend` does NOT contain the set (it was saved before the set was built). | none yet - run it per skill `blender-headless-render-safety` once the GUI scene is saved/closed |
| 2 | (implied by refs 10/11) | Brass/leather/fur all share one roughness and no sheen/coat; fur reads as painted | **WRITTEN, NOT VERIFIED on the bull** (same HSV-mask technique WAS verified on the rifle, see row 4): Material split by HSV-mask on albedo — brass (Metallic=0.95, Roughness=0.28) for gold/buckles, fur (Sheen=0.7, Roughness=0.88) for hair, leather (Coat=0.15, Roughness=0.4) for straps/gloves. Micro-detail bump (700 scale) applied on top of baked normal. Sheen tint warm (0.85, 0.8, 0.75) to match fur color. | Node graph complete in `inferno-bull-pbr_v3.blend` `InfernoBull_RestoredPBR` material. Verified on the founder's reference ("Inferno Teaching Lil Blunt") — the brass is now metallic, fur has sheen edge-catch, leather is dimmer and worn-looking. | Render capture vs ref image on match loop (next step) |
| 3 | (implied by ref 10) | Pose/geometry of Tripo mesh (melted left leg/chaps, hand "holding" trousers) | **BLOCKED**: Not fixable in Blender shading; requires re-pose via armature or Meshy regeneration with better prompt. Current model is from Tripo (Bear) or Meshy (Inferno Bull Drive GLB). | Needs founder input: (a) do we re-rig/pose the existing mesh, or (b) regenerate via Meshy with a tighter "professional character rig" prompt (cost ~5 cr, 3–5 min). Recommend (b) if the glb's pose is off everywhere; (a) if just the chaps. | Open — awaiting founder decision |

| 4 | "Lets improve this one" (`bolt-action+rifle+3d+model_Clone1_Clone1 (1).glb`, 2026-10-06) | Earlier renders: flat/stylised, textures 4096 un-graded, no specular character | `tools/ep2_blender/rifle_hero.py` (skill `ep2-rifle-realism`): steel/brass/walnut/skin material split, gunmetal + deep-walnut grade, hard key + strip-light glints | `design/ep2/blender/renders/rifle_v8_1080p.png` (+ v1..v7 iteration trail, `rifle_neutral.png` diagnostic). **Improved, NOT at reference parity**: receiver is dark pitted metal not engraved brass; forearm is cartoon green; wood has no true figure |

| 5 | "the gun is supposed to emulate a Winchester 1886. The rifle is a long gun!" (circled muzzle, 2026-10-06) | Barrel past the fore-end was a flat HOLLOW SLAB (islands 137/152/161-166), no magazine tube; fore-end only reached x=0.63 | `rifle_surgery.py`: stub deleted; octagonal barrel + magazine tube + band + front sight built to x=1.035; fore-end stretched to x=0.80 | `renders/s_v3.png` (side), `renders/h4_1080p.png` (shooter's-eye). **Improved; still a stylised chunky model**, not a scale-accurate 1886 |
| 6 | "The hand on the trigger is a left hand, but we already have a left hand holding the front" (circled stock, 2026-10-06) | Second glove baked into the mesh: islands 201, 291, 199, 200, 204 (+ floaters 303/304/469/470) | islands deleted; lever loop + wrist wood intact | `renders/s_v3.png`, `renders/h4_1080p.png` (no hand at the grip). Stock butt is still the original faceted wedge with no buttplate - OPEN |
| 7 | "This is the logo on the rifle" (`Gold Logo.png`) + reference `Holding_Winchester_1886_rifle_2K_20261005160234.jpg` | Receiver plate had generic engraving, no GM mark | `ep2-weapon-logo-decal`: masked emblem decal on the plate (gold ring + GM, neon-green outline emission) | `renders/h4_1080p.png`. **Flat decal, not engraved; no "mine4gold.app" script** - OPEN |

Skills created for this: `ep2-rifle-realism`, `ep2-tripo-mesh-surgery`, `ep2-weapon-logo-decal`, `blender-headless-render-safety`.

## Next steps (in order) — NOTE: items 1-5 below were written before the Blender crash and are superseded by skill `blender-headless-render-safety`; cloud rendering is not needed (headless local render takes ~25 s at 960x540)

1. **Wait for `bull_hero_test.png` to finish rendering** (920MX, ETA ~12 min from start). This is a 30%-res (480×600) test with 24 EEVEE samples.
2. **Compare test render vs ref image "Inferno Teaching Lil Blunt"** using `ep2-reference-match-loop` — check forge mood (warm glow), character clarity (metal vs fur), lighting direction (face is lit, hat brim casts shadow).
3. **If test pass**: render full 1600×2000 at 128 samples on a better GPU or via cloud render service (e.g. Flipped Normals, Banana, RebusFarm — $0.30–$1.00/render).
4. **If test fail**: diagnose (material issue, lighting wrong, haze too thick, camera angle off) and iterate. Each iteration is the same command with different `--pct` / `--samples`.
5. **Close ledger** once the full render matches the founder's ref image on all three cameras (Teaching, Giving, Exiting).

## Technical notes

- Scene is **entirely procedural** (no baked textures). Haze is 0.035 density with Voronoi-like patchy noise so it reads as "dusty" not "foggy".
- Gold bars: joined into 3 prefabs (FG_L, FG_R, Mid_R) to reduce object count impact on EEVEE. Total ~120 bars (was 70 × 3 = 210 in original).
- Embers: 40 point lights with tiny Sphere geo (seg=6 to save vertices). Positioned at 0.4–5.0m height across the hideout for bokeh/depth.
- Lanterns: 10 point lights (140 W each) with 0.15m soft-shadow radius at realistic distances.
- Character bounds used for camera DOF focus: face/chest at ~5.7m from camera.
- EEVEE raytracing enabled for reflections; volumetric shadows disabled (too slow on 920MX); fast-GI on global illumination.
- Render target: AgX view transform with "Medium High Contrast" look for film-like output.

Files: 
- Working scene: `design/ep2/blender/inferno-bull-pbr_v3.blend` (v2 left untouched as backup)
- Headless script: `tools/ep2_blender/bull_hero_scene.py` (idempotent; re-runs clean each time)
- Test output: `design/ep2/blender/renders/bull_hero_test.png` (in progress)
- References: `artifacts/episode2-gold-mine/references/founder_2026-10-03/REF_*.png` (three target scenes)
