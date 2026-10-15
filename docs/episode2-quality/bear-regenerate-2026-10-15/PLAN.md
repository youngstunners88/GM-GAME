# Episode 2 bears - Hunyuan3D-2.1 regenerate plan (2026-10-15)

Same recipe as the Bull (`docs/episode2-quality/bull-hunyuan-2026-10-15/README.md`): reference -> Hunyuan3D-2.1 shape
(RTX 5090) -> decimate -> paint/bake -> skin onto the EXISTING skeleton -> `ep2-reference-match-loop`.
Nothing here has been run; no paid call was made while writing this plan.

## 1. Inventory (src/episode2/assets, sizes on disk; verts/tris from GLB accessors)
| File | Size | Verts / tris | Rig | Clips | Loaded by |
|---|---|---|---|---|---|
| `bear_rigged.glb` (+`_0.jpg` 372 KB, `.rig.json`) | 4.7 MB | 60,881 / 46,748 | 24 joints (Meshy rig) | Idle, Archery_Shot, Archery_Aim_with_Lateral_Scan, Shot_and_Fall_Backward, Hit_Reaction_with_Bow, Angry_Ground_Stomp, Leap_and_Punch | `actors/ep2_bear_kit.gd` (RIG), `runner/runner_motion.gd` (BEAR_RIG) |
| `mine_bear_archer.glb` (+`_0.png` 509 KB) | 3.4 MB | 55,132 / 43,976 | none (static, bow drawn) | none | `runner/runner_view.gd` (statue), `chamber/woods_quad.gd` (BEAR_ARCHER_MODEL) |
| `hideout/bear_standing.glb` | 0.22 MB | 3,653 / 4,279 | none | none | `range_dressing.gd`, `hideout_dressing.gd` (prop) |
| `hideout/bear_head.glb` | 0.25 MB | 3,911 / 4,253 | none | none | `hideout_dressing.gd` (trophy) |

`ep2_bear_kit.gd` also registers the Bull's `inferno_bull_walking_clip.glb`, `_running_clip.glb`, `_sit_clips.glb` onto
the bear, so those clips drive the bear by BONE NAME. Bear arms-down modifier lives in `ep2_bear_arms_down.gd`.
Pack: 189.2 / 190 MiB (STATUS.md) -> every replacement must be same size or smaller.

## 2. References (only what exists; nothing invented)
| Variant | Best reference | Shows | Caveat |
|---|---|---|---|
| Archer (in-game rigged bear, runner + woods) | `artifacts/episode2-gold-mine/references/STILL_bear-archer_apose_v2.png` (1024x1024) | front A-pose, helmet+lamp, red bandana, quiver x2, leather vest | Best for rigging: arms out, neutral. NOT balaclava, no bow |
| Archer (founder target look) | `.../REF_balaclava-bear-archer_turnaround.jpg` (1374x1145) | balaclava, lamp, bandana, quiver, drawn bow, rivet cuffs, belt with pick emblem | Action pose, bow drawn: do NOT rig from it; use for texture/colour match and the static statue only |
| Archer statue (static) | same REF_balaclava | as above | Statue may regenerate straight from it (no rig) |
| Shovel / boarder / woods readers, sleepers | `founder_2026-10-10b/bear_realism_1.jpg`, `bear_scene_2.jpg`, `bear_scene_3.jpg` (2752x1536 scenes) | bears in woods scenes | Scenes, not isolated characters: crop one bear per image before use; not yet inspected closely |
| Gameplay shots | `IMG_2492_*`, `IMG_2497_*`, `KEYART_zipline-revolver-pickaxe_bears.jpg` | bears in runner action | Context only |
| Shovel bear (isolated) | NONE | | The shovel is procedural in `_build_shovel_bears`; the bear body is the shared rigged mine bear. No reference exists, so no regenerate: reuse the archer body |
| Tax-collector bear | NONE | | No such bear in the skills or references |
| Hideout `bear_standing` / `bear_head` | NONE separate | | Props from the old Tripo pass (`docs/episode2-quality/tripo-bears-2026-10-10/board.jpg`); low priority, 0.5 MB total |

## 3. Per-variant plan
### A. `bear_rigged.glb` (priority 1: every moving bear)
- Image: `STILL_bear-archer_apose_v2.png`. If the founder wants the balaclava look, run it as a second seed/job and let
  him choose; keep both shapes. Hunyuan needs a clean single subject: background already white.
- Settings: `gen_batch.py` defaults (50 steps, octree 384, seeds 7 and 11). Expect ~600-700k faces, ~70 s each.
- Decimate: `tools/ep2_runpod/hunyuan/decim.py` style quadric to 60k, then paint at 512 (as Bull), then
  `tools/ep2_forge/decimate_textured.py --faces 20000 --tex 1024`.
- Budget: <= 25k faces (currently 46.7k), ONE 1024 JPEG q~0.85 (<= 372 KB), GLB <= 3 MB (saves >= 1.7 MB).
- Rig: do NOT re-rig. Copy `retarget_bull.py` to `retarget_bear.py`: read the current bear skeleton + 7 clips, scale/align the
  new mesh to the bind pose (height 1.9 m per `.rig.json`; kit rescales by `height`), give each vertex the blended
  joints/weights of its 4 nearest old vertices, write new mesh + old skeleton + old clips. Node names/hierarchy unchanged ->
  Bull clip GLBs and `ep2_bear_arms_down.gd` keep working. Strip any bow/quiver fused into the mesh if the old rig had
  none (arrows/bow are separate nodes in the kit).
- Gates: `ep2_bear_*` tests, the whole-interval skinned-contact tests from design/ep2/motion/jobs/2026-10-14-runtime,
  `ep2_bear_awareness`-style routine capture (walk/run/sit/fall), Chromium web-export run, pck size <= 190 MiB.

### B. `mine_bear_archer.glb` static statue (priority 2: saves the most pack)
- Cheapest win: retire it and show the rigged bear (A) in Archery_Aim pose in `runner_view.gd`/`woods_quad.gd`
  (frees 3.4 MB + 0.5 MB texture). Needs a pose-hold call, a code change, so confirm with the founder first.
- Otherwise regenerate from REF_balaclava (bow drawn is fine for a static mesh): decimate to 25k, 1024 tex, <= 2 MB.

### C. Hideout props (priority 3, optional)
`bear_standing` / `bear_head`: already tiny (4k tris). Only redo if the founder complains; no reference.

## 4. Pod session
1. `up.py`/`install.sh` as for the Bull (py3.12, torch 2.8+cu128, pins in README). Arm `watchdog.sh` (50 min).
2. Upload refs, `jobs.json`, then `python3 gen_batch.py jobs.json`. Download `/workspace/*_hy_shape.glb`.
3. Paint only the chosen shape per variant (Paint failed unattended for the Bull; run `paint_install.sh` then `paint.py`
   interactively, or fall back to Blender reference projection / bake from the current bear texture).
```json
[{"name":"bear_apose","image":"/workspace/STILL_bear-archer_apose_v2.png","seed":7},
 {"name":"bear_apose_s11","image":"/workspace/STILL_bear-archer_apose_v2.png","seed":11},
 {"name":"bear_balaclava","image":"/workspace/REF_balaclava-bear-archer_turnaround.jpg","seed":7}]
```

## 5. Risks
- Hunyuan2.1 Paint never confirmed working (Bull stopped at shape). Fallback texture path above.
- Fur: 20k faces cannot hold fur silhouettes; rely on the texture and a normal map capped at 256 (pack rule).
- Skin transfer on thick fur/bandana overlap can tear the neck/shoulders (the Bull coat tore on the quad reach); check Idle,
  Leap_and_Punch and Shot_and_Fall_Backward.
- Two bear looks (plain vs balaclava) exist; founder must pick one or the pack/art disagree between statue and rig.
- Pack: 189.2/190 MiB; do not land A without retiring the old files (`git rm`, move to `.farm/retired/`).
- Do not merge before `scripts/ship-to-master.sh` gates and the front-page lock check.
