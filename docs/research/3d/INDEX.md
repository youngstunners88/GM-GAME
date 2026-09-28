# Episode 2 — 3D strategy research log

Findings from the `ep2-3d-strategy-research` skill. One file per finding. Every row
is either **VERIFIED** (reproduced or fixed in this repo, with the proof named) or
**LEAD** (sourced, not yet reproduced here — do not build on it without checking).

| # | Finding | Status | Layer | Proof / where it landed |
|---|---|---|---|---|
| 001 | [Godot 4.3 non-threaded web draws NO 3D above 1000 instances](001_web_1000_instance_blank.md) | VERIFIED | 3D / engine | `project.godot` `threaded_cull_minimum_instances=1000000`; `?ep2off=stress` (1500 extra meshes) renders in Chromium |
| 002 | [Meshy rigging + animation API: one GLB with up to 10 library clips](002_meshy_rig_animation_api.md) | VERIFIED | 5 motion | `tools/meshy/meshy_rig.py`; `lil_blunt_rigged.glb`, `bear_rigged.glb`; `ep2_runner_motion_test` |
| 003 | [Meshy rigs can carry a 0.01 Armature scale — measure skinned AABBs directly](003_rig_armature_scale.md) | VERIFIED | 4→5 | `RunnerView._measure_rig`; motion-test "rig scale sane" |
| 004 | [Gemini hears WAVs — use it as the "listen" step before promoting audio takes](004_gemini_audio_grading.md) | VERIFIED | audio | `scripts/varco-grade.mjs`, `takes/*/grade.json` |
| 005 | [Reference-guided stills (Nano Banana Pro / GPT image via OpenRouter) beat Flux for characters](005_reference_guided_stills.md) | VERIFIED | 1 illustration | `scripts/ref-image.mjs`; STILL_*_v2.png → lil_blunt_v2 / bear_archer_v2 Meshy thumbnails |
| 006 | [Godot 4.3 exposes a SkeletonModifier3D's pose only during `skeleton_updated`](006_modifier_pose_timing.md) | VERIFIED | 5 motion | `RunnerAimModifier`; motion test "gun arm points" dot 1.00 |
| 007 | [Founder Meshy share links resolve to task ids our API key can read, remesh and download](007_founder_meshy_share_links.md) | VERIFIED | 4 3D | `founder_meshy_sources.json`; 4 models pulled, remeshed (5 cr each), cut/split |
