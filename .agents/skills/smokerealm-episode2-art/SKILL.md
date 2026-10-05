---
name: smokerealm-episode2-art
description: Improve Inferno Bull and his Episode 2 Fort Knox hideout in GM-GAME using the supplied references and actual gameplay-camera evidence. Use for character appearance, materials, game optimization, hideout dressing, and reference fidelity.
---

# Episode 2 character and hideout

Work in `youngstunners88/GM-GAME`, not an isolated Blender deliverable. Read current repository instructions and `.claude/skills/gm-game-ep2-hideout-art/SKILL.md` with its contract; use the existing player-view and hand-prop capture tools.

User-provided sources (2026-10-04):
- Bull GLB: Drive file `1uQpVFv7TIFOO_CTFP7XAYQS5j8mDT2Ef`.
- Armory reference: `1BNvaRExNjm8puGdpUYi4xIZKWauLvfLz`.
- Bull teaching Lil Blunt: `1Alq_TCqo1Jj2GIcxNWy6vbaM7AXHmv8f`.
- Golden vault: `1EbxNg6P4t1XraQ-cUqWQLpteXM8WPVD5`.

Retrieve and inspect the references rather than inferring them from filenames. Their art direction is a richly furnished Western armory: dark fur and worn leather, red bandana, brass accents, heavy timber, stone arches, gun racks, warm lantern pools and molten-gold light. Keep the characters and gameplay readable against the dense surroundings.

## Diagnose in the game

Capture the current arrival and natural walking/look views before editing. Compare the same cameras afterwards. Separate composition, occlusion, lighting/material defects, asset quality, and performance. A Blender studio render or lower polygon count alone does not demonstrate improved game appearance.

Relevant runtime files are `src/episode2/chamber/hideout_dressing.gd`, `smelting_facility.gd`, `src/episode2/actors/ep2_actor.gd`, and the assets they actually load; verify these paths on current master. Respect the existing Bull rig, idle correction, rifle/glass grips, equipment hand-over, video resume, navigation, targets, and progression.

## Produce and verify

Keep editable sources and original assets recoverable. Export standard game-compatible PBR materials; Blender adjustment nodes must be baked or deliberately reproduced in Godot. Preserve UVs, skin weights, bone names, and animation compatibility. Compare imported rest/animated poses and hand props, not just mesh statistics. Do not replace a runtime asset with an unverified decimated variant.

The user explicitly authorized Blender on their PC for this work. Use Blender to inspect and repair character geometry, normals, UVs, materials, and authored environment meshes when needed; keep the editable `.blend` and a reproducible game export. Do not substitute only a scene tint or studio lighting for a requested model repair.

Use Jev when a difficult tradeoff would benefit from a structured decision over measured evidence. First check an available connector or presence of configured OpenRouter credentials without revealing values. Jev is text-only: provide numeric visual/performance/test findings and the concrete options, not image bytes or invented fidelity scores. Verify the current decisions API before calling it. Its advice does not replace pixel inspection or authorize actions. If unavailable, record that and continue independent work; never claim a Jev verdict without a returned result.

Fix prop orientation, support contact, scale, and camera visibility before adding content. Use authored assets for distinctive props; structural geometry can remain procedural. Keep walkways and interaction zones clear. Favor shared meshes/materials and bounded lights over hundreds of individual draw calls. Judge Compatibility renderer pixels rather than assuming Forward+ effects work on web.

Record same-camera comparisons, triangle/texture changes, relevant tests, import/export errors, and remaining fidelity limitations. Complete the game integration, then follow `smokerealm-ship`; the user has requested commit, push, and verified itch.io release as part of completion.
