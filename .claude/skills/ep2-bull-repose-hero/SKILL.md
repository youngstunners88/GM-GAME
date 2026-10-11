---
name: ep2-bull-repose-hero
description: Make the Tripo Inferno Bull (Bull+minotaur+3d+model_Clone1_Clone1.glb / inferno-bull-pbr_v3.blend) read as a hero character - re-pose through its 24-bone armature (lift the bowed head, bring the melted-looking arm in), neutral-grade the material, and render him in a lean forge set - all headless. TRIGGER on "Inferno Bull is trash", "face is hidden under the hat", "his arm looks melted / glitched", "Bull looks muddy / copper / dark", or before ANY Bull render in Blender.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit
---

# Inferno Bull: re-pose, de-mud, light (measured 2026-10-06)

Source model: Tripo (`tripo_node_*`, texture `Bull_minotaur_3d_model_Clone1_Clone1`), 67,927 verts, 24-bone Mixamo-style armature, action `Idle_02`.
Design reference: Drive `Inferno Bull with rifle.jpg` (`C:\Users\SAMSUNG\Downloads\Inferno Bull with rifle.jpg`) - visible face (gold aviators, nose ring, cigar), relaxed arm resting at the pouch, rifle in the other hand.
Run only headless (`blender-headless-render-safety`): the bull script builds ~500 objects.

## What was actually wrong (look before you fix)
| Looked like | Real cause | Fix |
|---|---|---|
| Whole figure copper/muddy | Not the model: 1.12 saturation boost node + a 1200 W orange rim + AgX "Medium High Contrast". Under neutral light the albedo is good (dark fur, worn denim, brass). | Saturation/Value 1.0, AgX look `None`, small hard key, rim BEHIND subject (same lesson as `ep2-rifle-realism`) |
| No face, "headless" | Head is bowed under the hat brim in `Idle_02` | `Head` bone **local X -25 deg** (+25 buries the face further) |
| Left-of-screen arm "melted into a sheet" | The (character-RIGHT) arm is bent up holding a long leather/cloth flap | `RightArm` **local Z -30..-35** brings the arm in; the flap then hangs like a relaxed arm. (`x +35` = hand on hip, also fine) |
| Flat black void + disc floor | No set | `Hideout_Set` (timber, furnace, lantern bokeh, gold bars, embers, haze) |

## Run
```bash
BL="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$BL" -b design/ep2/blender/inferno-bull-pbr_v3.blend --python tools/ep2_blender/bull_hero_scene.py -- \
   --out "$PWD/design/ep2/blender/renders/bull_hN.png" --pct 35 --samples 24 --rt 0 [--pose "Head:x:-25,RightArm:z:-30" | --pose none]
```
Pose experiments: `tools/ep2_blender/bull_pose_test.py -- --tests "Head:x:-25,RightArm:z:35"` (renders one image per test); inspection + bone list: `bull_inspect.py`.
Pose mechanics: the action drives the rig, so the script **bakes frame-1 `matrix_basis`, clears the action, then multiplies a local rotation** onto the pose bone. Bone axes on this rig are not intuitive - always test +/- on each axis and look.

## Status: NOT RESOLVED (founder verdict after v4 and v5: "still trash")
Pose + face visibility + material de-mud are real, verified gains (`bull_h3/h4/h5.png` vs the original `inferno-bull_hero.png`). The result is still NOT at the reference. Read this before iterating again:
- **Set is still wrong, and tweaking colours did not fix it.** Even with a near-black floor albedo, the floor reads pink and the furnace panels read pale peach in v5. The likely carrier is the haze volume (`HS_Haze`, 30 m cube) in-scattering the emissive/lantern light over the whole frame. Test by hiding `HS_Haze` before changing any more colours (measure, do not guess - same rule as the blotch bug).
- **Contrast**: a dark figure on a mid-tone orange wash has no separation. The reference is dark-on-dark with hot rim edges.
- **Mesh ceiling**: the Tripo sculpt is soft/waxy (smooth plastic fur, tiny face, blobby arm). No lighting makes it match the reference's fur and tooled leather. Needs a higher-resolution regenerate (Tripo HD/refine from `Inferno Bull with rifle.jpg`) - a decision and credentials that belong to the founder.
- Values tried and rejected: furnace emission 45 / 7 / 3.2 / 1.4 (all peach), haze 0.08 (veil), exposure -0.3 / -0.6.

## Still open
- The furnace planes read as flat coloured panels, not molten metal (needs a real emissive mesh with depth + glare).
- Pose is still the Tripo stance (feet pigeon-toed, no weapon); the reference has the rifle upright in the other hand - swap in the approved rifle (`ep2-rifle-realism`) via the hand bone.
- Fur is a baked texture; real hair curves would be the next realism step but cost RAM/time on this machine.
- This is a Blender hero render only; nothing here is wired into the Godot game (`inferno_bull_rigged.glb` is a different, Meshy-based asset).

## Game GLB: sheet stance in the engine (2026-10-11, inferno_bull_rigged.glb)
The game Bull IS the Tripo body on the 24-bone Meshy skeleton, and its **bind pose already is the character sheet**
(upright, head up, right fist on the flask pouch, left fist closed for a rifle). The "melted arm", bowed head and
stiff slouch all came from the Meshy clips driving a body they were not made for, plus nearest-vertex skin weights.
Fix, all on the GLB in place (skeleton, node names, clip GLBs untouched, so walk/run/sit/talk keep working):
1. `tools/ep2_forge/bull_hero_fix.py` (exact command in its docstring; source in `.farm/retired/inferno_bull_rigged_pre_hero_2026-10-11.glb`):
   Idle_02 rebuilt from the bind pose + a breath; weights limited per limb by nearest bone segment (backpack = Spine02
   rigid, belt pouches never arm), smoothed 6 passes over the position-welded surface; hand-to-body bridge triangles
   cut; rifle-stub islands inside `--drop-box` boxes deleted. NOT `--tiny-tex`: the cliff cinematic uses the embedded atlas.
2. `src/episode2/actors/ep2_bull_hero.gd` (`Ep2BullHero.dress(b)`, one line in `interlude_base._build_bull`): arms held at
   rest (Ep2BullRestArm) unless seated or reaching - the walk clip's arm swing tears the fist fused into the flask pouch;
   rifle (`winchester_1886.glb`, darkened, matte) placed vertically from the LeftHand bone every skeleton update, hidden
   on Sit clips; lit helmet lamp at the measured lens; material grade (albedo x(0.60,0.66,1.04), no orange self-glow).
   The hideout keeps its own props; `smelting_facility` now also rests the arms while walking.
3. Measure: `tools/ep2_blender/bull_game_inspect.py <glb> <out> [--clip X | --clip-glb walk.glb --clip "Armature|walking"] [--lock-arms] --stretch`
   (Cycles, no EGL) prints edges stretched >2x = the melted-surface count. Before/after: idle 6069 -> 0, walk 4229 -> 1366,
   sit 6286 -> 4186, talk 4069 -> 3048. Evidence: `docs/episode2-quality/inferno-bull-2026-10-11/`.
Traps: never write a CRLF .gd through Python text mode (smelting_facility.gd is CRLF - edit bytes); per-UV-island
majority labels tore seams (the decimated mesh is ~2200 UV islands but ONE welded shell); the talk/gesture/sit clips
still stretch the fused hand/pouch and the sit clip is hunched - a re-generated body with a free right hand is the real fix.

## Founder 2026-10-11 round 2 ("rifle hovering - WHY THE SEPARATION", "elbow webbed melting")
- Bull's rifle MUST be a child of `bull.holder("LeftHand")` (BoneAttachment3D -> follows the final drawn pose, metres frame), placed
  from the hand bone's rest (grip = wrist + 9 cm along the bone). Never place it from a measured rest point or from
  `skeleton_updated` + `get_bone_global_pose` (pre-modifier pose) - both left it hovering 0.2 m off his fist.
- Never IK his arms to shoulder height (the range demo did): the Tripo skin webs and melts at the elbow. Keep arms at rest; turn the
  rifle instead (hip fire).
