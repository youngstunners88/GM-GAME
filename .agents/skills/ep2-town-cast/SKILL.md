---
name: ep2-town-cast
description: Expand the SmokeRealm town cast from all supplied references using editable Blender sources and verified Godot assets.
---

Read `design/ep2/town/people-rebuild-20261021/references/manifest.json` and `design/ep2/town/autonomy-20261022/reference-coverage.json`. Inspect the images; filenames can misstate ages or the number of figures. Map every supplied figure to an asset and runtime role. The grandparents image has two people; the boy-and-girl image depicts one youth. There are thirteen public ambient figures and a fourteenth, striped-shirt jail prisoner. The prisoner has a separate editable source and retains the existing cell, dialogue and story control; never add him to the public roster.

Use the creative-hub Blender executable with the installed `gm-blender-godot`, `blender-core`, animation and QA skills. Run one heavy background Blender job at a time on this 8 GB machine, with ALSOFT_DRIVERS=null; preserve the owner's open session. Keep original five assets recoverable and preserve authored sources, texture maps, reference IDs and rigs. Children require changed anatomical ratios, clothing and hair, not uniform adult resizing. Face projection from one image does not establish scan-quality likeness.

Run `tools/ep2_blender/build_extended_town_cast.py` for extended sources and `tools/ep2_blender/town_activity_clips.py` for in-place motion additions. Verify all used clips after Godot 4.3 import, inspect deformation over whole clips, check hand/prop contacts when props are used, and include gameplay captures. Stream new art through existing Episode 2 extras. Check both PCK presence and fresh-import main-pack size. Follow the normal ship skill; never label local renders as a public release.

Use rounded scalp-seated curls, not overlapping planar caps or detached rings. Garment inverse warps must classify cuffs with their sleeves. In the capture fixture, update the actual chamber camera after changing its aim and settle clip cross-fades before manual seeking. The bounded 605-frame proof covers all thirteen public figures and the prisoner through the player's real camera.

## Meshy cast (founder 2026-10-22: "the townsmen people all look the same")
The procedural Blender figures shared one body template and read as clones. Every public figure plus the prisoner is now
rebuilt by Meshy from their OWN T-pose photo: `python3 tools/meshy/townfolk_batch.py plan|run|finish` (manifest, task ids,
credits and measured walk speeds in `design/ep2/town/meshy-cast-20261022/manifest.json`; contact sheets in `sheets/`).
- Image-to-3D (latest, t-pose, 16k tris, PBR) 30 + rig 5 + 3 per library clip. The plan caps queued tasks (429
  NoMorePendingTasks): the batch keeps a rolling queue and is resumable. Get the founder's yes on the credit total first.
- Each person gets their own library Idle variant, walk style, talk, greeting; children/youth add `Play`. Clips are renamed
  to the game slots (Idle/Walk/Observe/Rest/Talk/Inspect/Alert/Greet/Play) - `Ep2TownFolk` binds by exact name.
- Meshy walks are in place; the stride speed is measured from foot FK (`foot_speed`) and set as `walk_speed` in
  `Ep2TownPeople.ROSTER` -> `Ep2TownFolk.walk_clip_speed` (no foot slide); `procedural_bob` is off for them.
- The animated GLB drops the normal/metal-rough maps; `graft_pbr` copies them back from the image-to-3D GLB (same UVs,
  checked by index count). Textures shrink to 1024 / 512.
- The grandparents photo is cropped into two people. The prisoner keeps his separate story control.
- Presence: the people are built by `woods_quad.gd` during the ride in (it is their town) and handed to the town chamber
  through `handoff["town_people"]`; they step aside for the quad (`Ep2TownPeople.make_way`).
