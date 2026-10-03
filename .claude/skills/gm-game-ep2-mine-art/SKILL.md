---
name: gm-game-ep2-mine-art
description: Improve GM-GAME Episode 2 mine-runner and cliff-exit visuals against founder references, using actual gameplay-camera captures and Godot Compatibility materials. Use for grey or dark scenery, repeated tunnel seams, timber/ore/lantern dressing, cliff-to-film continuity or mine readability. Preserve founder characters and gameplay.
---
# Episode 2 mine art
Read [source and runtime contract](references/contract.md). Build on repository `ep2-runner-camera-light` and `ep2-runner-grade`, not a new renderer.

1. Capture a baseline using `tools/ep2_shots/shoot.sh` with the pinned Godot and Xvfb. Cover near/mid mine, outer lanes, zipline, visible hearts/coins/hazards around 90 m, and the cliff approach. Save source SHA, viewport, leg, distance and flags. Native Compatibility captures help iteration; confirm the exact web export afterward. Include the real Episode2Entry host: the shot rig omits its progress/health HUD, so it cannot reveal overlap with RunnerView BTC/speed or the offline banner.
2. Inspect pixels beside the founder's mine-exit image. Diagnose coverage, repeated seams and silhouette before lifting ambient. Inspect shell mesh bounds, materials and the surface responsible. An imported textured mesh can still be flat black or have transparent material flags; a file-exists test proves neither appearance nor continuity.
3. Prioritize no more than three concrete visual defects. Use existing textured rocks, timber, lanterns and ore. Static repetitive detail uses MultiMesh/shared materials, not hundreds of new lights or new large GLBs. Keep lane centre, hero, warning boards and hazards readable. Avoid uniform tint, scattered glowing orbs, overly bright veins and particles obscuring the reticle.
4. Give the cliff a framed, warm exterior that bridges to the film's golden-hour woods. Preserve warning timing, rail termination, gap and film entry. Scenic geometry must remain beyond the playable route and cannot create fake traversable ground.
5. Change one material/light/geometry family, repeat identical captures, inspect neighbouring beats, and write a PASS/PARTIAL/FAIL reference rubric. Never equate realistic concept art with game footage. Preserve cart/rail/hero geometry; do not polish a character by replacing it.
6. Run art-direction, camera-framing, runner, carts, reachability, GLB and session tests. Measure the fresh web PCK. Ship with the contract's release proof and list remaining target gaps honestly.
