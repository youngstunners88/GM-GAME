---
name: ep2-lake-world
description: Build Logan’s wooded Western shoreline, staging dock, readable still-water and narrow day-88 outflow at Godot web budgets.
---

# ep2-lake-world

Use gm-blender-godot plus blender-hardsurface-modeling, blender-pbr-materials and blender-lighting-lookdev. Read design/ep2/lake/IMPLEMENTATION.md and the supplied lake-bank image. Translate the source mood into the actual first-person camera, not a separate glamour render.

Use tools/ep2_blender/build_logan_dock.py for metre-scale dock timber, fitted mooring rope and piles. Keep plank tops flush with walking height. Runtime lives in src/episode2/chamber/logans_lake.gd. Water is a broad basin that visibly narrows into a river; shore terrain must have a recessed bed, not cover the lake with an opaque ground plane. The overlook is high ground reached by a continuous slope.

Reuse the forest kit with its explicit bark and alpha foliage materials. The kit's bare material makes pale card-shaped trees; do not mistake those cards for the final leaves. Instance shared meshes/materials; keep trunks and rocks out of the walking path and outflow sightline. Check lower resolution, shadows, signs and dock contact in Compatibility mode. No new global colour grade or edits to unrelated town/horses.

Use existing water shader or a measured local adaptation, not Blender fluid caches/volumes in the web pack. Blender shader nodes do not become runtime Godot shaders. Keep readable deep water, warm timber, neutral shore and distant terrain. New textures require recorded colour space, size and import settings; full fresh PCK remains <=190 MiB.

Do not enlarge this task into train/stable construction or the town Stockpile. Bound water and world edges consistently with actual geometry. Verify a player can walk arrival→Logan→cargo→overlook using ordinary movement.
