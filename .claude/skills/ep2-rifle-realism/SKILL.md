---
name: ep2-rifle-realism
description: Turn the founder's Tripo Winchester GLB (bolt-action+rifle+3d+model_Clone1_Clone1.glb) into a photoreal-PBR hero render - steel/brass/walnut/leather split by albedo masks, deep-walnut and gunmetal grading, hard key + strip-light glints - headlessly, in ~1 minute per render. TRIGGER on "improve the rifle", "rifle looks flat / plastic / pink / orange", "make the Winchester photoreal", "high level 3D realism" for a weapon or any Tripo/Meshy prop with a baked albedo, or before re-grading any Tripo material.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Rifle realism: baked Tripo GLB -> believable PBR (measured 2026-10-06)

Tool: `tools/ep2_blender/rifle_hero.py`. Reference target: `Holding_Winchester_1886_rifle_2K_*.jpg` in the founder's Downloads
(weathered brass receiver with engraving, dark steel with sharp glints, deep walnut, soft stitched leather glove).
First read `ep2-founder-weapon-glb` for what the file IS (lever-action, Lil Blunt's arms baked into the same mesh).

## Run it (never in the GUI - see `blender-headless-render-safety`)
```bash
BL="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$BL" -b --python tools/ep2_blender/rifle_hero.py -- --glb "<path>.glb" --out design/ep2/blender/renders/rifle_vN.png \
      --w 960 --h 540 --samples 32 [--save design/ep2/blender/rifle_hero_v1.blend] [--view 3q|side|top] [--neutral]
```
960x540 @ 32 samples = ~25 s; 1920x1080 @ 64 = ~4 min on the 920MX box. Log to a file and poll it (`render done` / `Traceback`).
`--neutral` = white lights + Standard transform: use it FIRST whenever a render looks wrong, to split "material is wrong" from "lighting is wrong".

## What the script does
1. Imports the GLB, drops the Mixamo armature + Icosphere, strips the Armature modifier (rest geometry), scales 4096 maps to 2048 in-process.
2. Splits the single Tripo material with HSV masks off the albedo: **steel** (low saturation, mid value), **brass** (hue .05-.19, S>.45, V>.45),
   **green skin** (hue .18-.45), **dielectric** = everything else (walnut + leather). Metallic/roughness/coat/subsurface are driven per mask.
3. Grades colour per mask: dielectric -> hue +0.035, sat .9, value .8 (orange Tripo walnut -> deep brown); steel -> sat .25, value .62 (cool gunmetal).
4. Stage: near-black glossy floor, world strength 0.12, DOF f/5.6, 85 mm; hard small key, ember rim BEHIND the subject, cool kicker, two thin emissive strip cards for glints.

## Traps that cost real iterations (each was measured, not guessed)
| Symptom | Real cause | Fix |
|---|---|---|
| Everything salmon / pink / copper, no contrast | The orange rim light sat on the **camera side** and front-lit the gun; metals reflect the light colour. Not the textures. | Place every light from the actual camera direction (`dcam`, `right_`); rim/kick go behind the subject |
| Washed, low-contrast even after dimming lights | AgX **"Medium High Contrast"** look + broad soft area lights + a bright floor bouncing fill | AgX look `None`, small hard key (size ~0.35 k), floor albedo ~0.006, world 0.12 |
| Wood goes maroon/purple after darkening | Darkening a red-orange albedo drifts hue | HueSat Hue .535 on the dielectric grade |
| Steel grade "does nothing" | Colour was dominated by the mis-placed orange light, not the albedo | Fix light placement first, then re-grade |
| Metal looks matte plastic | Nothing sharp to reflect | Thin emissive strip cards (`visible_camera=False`) beside/above the rifle |
| First headless render appeared to hang | Cold shader compile + the Tripo add-on starting a websocket (harmless) | Wait ~4 min the first time; later runs ~25 s |

## Geometry + logo (added 2026-10-06)
Use `bash tools/ep2_blender/run_rifle.sh <name> --view fps|oside|3q ...` - it adds `--align --flipx --pre rifle_surgery.py --logo <GM logo>`
(duplicate-hand removal, rebuilt barrel, GM decal). Skills: `ep2-tripo-mesh-surgery`, `ep2-weapon-logo-decal`.
`--view fps` is the shooter's-eye camera that matches the founder's reference; `--dm` scales camera distance.

## Known gaps vs the reference (do not claim parity)
- Stock butt is the original faceted wedge with no crescent buttplate.
- The receiver plate is dark pitted metal; the reference is **warm brass with "mine4gold.app" engraving**. The Tripo albedo has no clean brass there, so a brass receiver needs a hand-painted mask or an engraving decal on the plate UV island.
- The baked left forearm is cartoon-saturated green; it needs a leaf-skin treatment (subsurface + vein bump) or to be cut off (`ep2-founder-weapon-glb` section 5).
- Wood is a baked colour with no true figure; a procedural walnut (noise-stretched along the stock) masked onto the stock island would beat it.
- No floor/environment context yet; for in-engine proof use the range capture rig (`ep2-blender-props`).

## Gate before saying "improved"
Put the new render next to the founder reference on one board (`ep2-reference-match-loop`) and LOOK at it. A render that is "better than before"
is not "matches the reference". Record the file names and the open gaps in `docs/founder-feedback/<date>_*.md`.
