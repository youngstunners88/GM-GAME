---
name: ep2-logan-performance
description: Prepare, animate and validate the founder-supplied Logan model for his lake encounter without replacing his appearance or destroying the supplied skin.
---

# ep2-logan-performance

Use gm-blender-godot, blender-character-rigging, blender-animation and blender-export-pipelines. Source identity/provenance: design/ep2/lake/SOURCE_RECEIPT.json and references/Logan.JPG. The supplied GLB already has 65 joints and normalized four-weight skin, 52028 triangles, 60285 split vertices and no animations. Inspect before considering paid generation, Rigify or retopology.

Rebuild with Blender 5.2.2:
`blender -b --factory-startup --python-exit-code 1 -P tools/ep2_blender/prepare_logan.py -- SOURCE.glb src/episode2/assets/lake/logan.glb design/ep2/lake/source/logan.blend`

Preserve face, hat, plaid, waders, satchel and rope. Map rotations through each source bone's rest axes. Author restrained Idle/Greet/Point/Approve gestures; the boots stay planted. Do not rotate foreign Mixamo quaternions onto mismatched rest matrices. Preserve the source skin and UVs. Repair only measured winding conflicts, collapsed faces, coplanar overlaps and detached gear on a separate copy with tools/ep2_blender/logan_mesh_repair.py; interpolate and revalidate weights/UVs on clipped faces. Use that copy for image resizing. No generic auto-fix of asymmetric clothing or the hips root.

Run rig_check and mesh QA on the actual asset. Review full clips, feet, shoulders, elbows and fingers at start/mid/end from front and side in engine. All-bones-present is not deformation proof. If he holds a prop in a later task, validate independent world-space hand/prop sockets throughout the clip; no parenting-only grip claim. This encounter uses empty-hand gestures and does not depict fishing.

Godot import: 1.82 m character, 4 authored clips, idle loops, gestures return to idle, no extra injected Icosphere. Compare founder reference next to a real player-view crop. Report retained warnings and texture/pack measurements. The source blend is dev-only; use plain GLB at runtime.
