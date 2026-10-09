---
name: ep2-rifle-hero-handoff
description: Use when improving the EP2 Winchester 1886 first-person rifle in Blender. Merges the realistic materials/lighting from rifle_hero_v2.blend with the clean geometry and real GM logo from rifle/bolt-action-rifle_work.blend, then verifies against the reference image.
---

# EP2 rifle: merge realism + coherence, then match the reference

Two Claude sessions worked on the same rifle. Each is strong where the other is weak. Your job is to combine them, not to start over.

## Files (all in `design/ep2/blender/`)
- `rifle_hero_v2.blend` : the realism pass (steel, walnut, leather, DOF, cinematic lighting). Renders in `renders/h4_1080p.png`, `renders/rifle_v8_1080p.png`. Strong: material depth, lighting, camera.
- `rifle/bolt-action-rifle_work.blend` : the coherence pass. Strong: the old garbled 3D emblem is deleted and replaced by a clean, correctly oriented, glowing GM logo medallion (object `GM_Logo_Medallion`); clean framing; backup of the old mesh kept hidden as `rifle_mesh_BACKUP_with_old_emblem`. Weak: materials look flat and the steel/wood read pink/orange.
- `rifle/textures/` : `logo_badge_base.png`, `logo_badge_orm.png`, `logo_badge_emissive.png`.
- `_handoff/refs/winchester_reference.jpg` : the target look. `_handoff/refs/gold_logo.png` : the real logo.
- Never overwrite these. Save results as new files, e.g. `rifle_hero_v3_merged.blend`.

## What is wrong in each (observed from the renders)
`rifle_hero_v2` / `h4_1080p`, `v8_1080p`:
1. The logo is tiny and faint (h4) or missing on the plate (v8). The plate shows noisy embossed texture where the logo should be. The garbled emblem was not removed as geometry, so a texture-only fix never reads.
2. Forearm is saturated lime with a bulb end-cap; cuff trim is pink; reference forearm is deeper, matte green with gold veining.
3. Fingertips/gloves are good; keep them.

`bolt-action-rifle_work`:
1. Receiver reads rose/pink under the ember rim light. Lower saturation and warm light energy; steel must be cool-brown/grey.
2. Walnut is too orange and flat, no clearcoat sheen.
3. Gloves look like plastic: no cracked grain, no edge wear.
4. A faint cream crescent from the old painted emblem recess is visible left of the medallion; paint it out of the base texture or scale the medallion up a little more.

## Procedure
1. Open `rifle/bolt-action-rifle_work.blend` as the base (it has the correct geometry and logo).
2. Append the materials and the light/camera rig from `rifle_hero_v2.blend` (File > Append, or `bpy.data.libraries.load`). Assign the realistic rifle material to `rifle_mesh`; keep `GM_Logo_Medallion`'s own material.
3. Check the medallion stays upright, not mirrored, G on the left, and glows green. If it looks dim, raise its Emission Strength (5 to 8) and make sure the world is not washing it out.
4. Render the SAME framing as the reference (first person: muzzle up and to the right, forearm entering bottom-left), 1920x1080, EEVEE, AgX, DOF on.
5. Compare to `_handoff/refs/winchester_reference.jpg` side by side. Write down 3 to 5 concrete gaps. Fix the biggest only. Re-render. Repeat up to 5 times.
6. Also render a logo close-up (85 mm, about 0.9 m from the receiver plate) to prove the logo is crisp.
7. Save as `rifle_hero_v3_merged.blend` and render PNGs into `renders/` with new names.

## Material targets (Principled BSDF)
- Steel: Metallic 0.9 to 1, Roughness 0.28 to 0.45 with variation, desaturated cool base. Not pink.
- Walnut: Roughness 0.35 to 0.5, Coat Weight 0.3, Coat Roughness 0.15, dark reddish-brown.
- Leather: Roughness 0.55 to 0.7, Sheen 0.3, normal strength 1.3 to 1.6, edge wear.
- Brass studs: Metallic 1, Roughness 0.25 to 0.35.
- Forearm: matte green, Roughness about 0.5, light subsurface.

## Blender MCP gotchas (Blender 5.2)
- `bpy.ops.import_scene.gltf` fails inside the MCP sandbox. Run it from `bpy.app.timers.register(...)`, then read the result from `bpy.app.driver_namespace` in a second call.
- `wm.read_factory_settings` is blocked; use `wm.read_homefile(use_factory_startup=True)`.
- Render to a file, then look at the file. Do not judge from the viewport.

## Rules
- Do not claim an improvement you have not rendered and looked at.
- If you cannot cleanly separate arms from rifle, say so; do not ship torn glove scraps.
- Report what changed AND what is still wrong.
