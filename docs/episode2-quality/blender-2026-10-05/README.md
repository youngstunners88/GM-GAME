# Episode 2 Blender integration — 2026-10-05

This pass repairs the materials on the actual animated Inferno Bull and adds authored architecture to his Fort Knox hideout. It preserves the separately shipped range lesson, first-person hands, voice ducking, narrative and environment work from master through `cdc4284`.

## Character

The game's 86,620-triangle body had only a 1K color atlas. Blender inspection of the owner's original Tripo GLB found compatible atlas islands: source/runtime color correlation 0.9910, mean absolute difference 0.0166 at 1K. Restored the original color at 2K and roughness/metalness/normal maps at 1K. Removed the low metallic haze on leather/fur; armor retains bounded metalness. Kept the runtime mesh, skeleton, bone names, weights and animation GLBs unchanged. Added mipmaps and explicit high-quality compressed imports to prevent distant texture shimmer and control web size.

The existing material override discarded roughness/metalness maps. It now applies the restored maps only to the Bull body; his separate rifle and glass keep their own materials. The regression gate verifies mapped body materials and mostly nonmetal texels, excluding hand-attached props.

## Hideout

Blender-authored kit: staggered beveled oak floorboards, a fitted rifle cabinet with cornice and brass inlay, low stone footing, segmented stone jambs and wedge-shaped vault stones. Five combined meshes, 33,048 triangles, 2,318,704-byte GLB. Replaces the flat floor and primitive overlapping vault frame. Vault lamps use master's corrected lantern materials. Existing interaction and navigation coordinates are retained.

The final comparison includes concurrent master improvements; do not attribute all newly visible dressing or range changes to this Blender pass. Master's gold material and extra warm fill lights were retained.

## Evidence and editable sources

- [Reference / same-camera room comparison](comparison.jpg)
- [Same-camera Bull material crop](bull-material-comparison.jpg)
- [Editable Bull](../../../design/ep2/blender/inferno-bull-pbr.blend)
- [Editable architecture](../../../design/ep2/blender/fort-knox-architecture.blend)
- Reproducible Blender scripts: `tools/ep2_forge/restore_bull_pbr.py` and `build_armory_architecture.py`.
- Source model: owner-supplied Drive `1uQpVFv7TIFOO_CTFP7XAYQS5j8mDT2Ef`; inspiration images `1BNvaRExNjm8puGdpUYi4xIZKWauLvfLz`, `1Alq_TCqo1Jj2GIcxNWy6vbaM7AXHmv8f`, `1EbxNg6P4t1XraQ-cUqWQLpteXM8WPVD5`.

Visual review: less speckled Bull highlights, readable dark leather/red bandana, distinct floorboard edges and fitted cabinet detail. The reference remains substantially more cinematic in geometry, framing and lighting; this is a verified game-art improvement, not a claim of photorealistic parity. Native Compatibility captures include walking, looking both ways, and post-film hand-prop views. Existing renderer teardown warnings also occur on the untouched baseline.

Local nonthreaded Web startup reaches the title and Episode 2 access-code screen. The protected Episode 2 browser playthrough was not completed; no access code was configured in this session. Native tests and real-render capture scripts exercise the changed room instead. Jev was unavailable in this PC session (no configured connector/OpenRouter credentials); no Jev verdict is claimed.

Both requested skills are installed personally and mirrored under `.agents/skills`; `AGENTS.md` records Blender authorization, optional evidence-based Jev use, and commit/push/verified itch shipping as the default completion workflow.

## Release validation

All eight integrated suites passed: script compile, smelting facility, range lesson, range v3, hideout corrections, voice ducking, narrative canon, and transition prebuild. Earlier art-direction, GLB-pipeline, reachability and camera suites also passed. The integrated nonthreaded web export completed successfully: **197,059,472 bytes (187.93 MiB)**, below the 190 MiB gate. Editable `.blend` sources are excluded from Godot scanning with `.gdignore` and from export by the existing design-folder exclusion. CI security, locked-front-page and butler deployment results must still be checked on the published source SHA.
