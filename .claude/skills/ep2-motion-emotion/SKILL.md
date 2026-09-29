---
name: ep2-motion-emotion
description: Layer 5 of Episode 2 — skeletal animation and emotion for Lil Blunt and the bears. Meshy auto-rigging + library clips baked into one GLB, measured clip timings, the RunnerMotion state picker, weapons on hand bones, emotion cues (danger "!", cheer, hit), and the traps (0.01 armature scale, clips import non-looping, rigs drop normal maps). TRIGGER on animation, rig, pose, "statue", "stiff", "fluid movement", emotions, character reactions, or adding a new character/clip.
---

# FIRST decide: rigged clips, or a POSED hero? (founder 2026-09-29)
| Situation | Use |
|---|---|
| The model has weapons/props **baked into the mesh** in a pose the founder chose (Meshy "Smiling Zipline Hero": pickaxe raised, golden revolver aimed) | **Posed hero + procedural body language** — `RunnerMotion.hero_pose()` (recoil kick, chop lean, duck sink, hit throw, hop lean, cheer bounce, run bob). A skeletal clip would swing the arms and deform the baked weapons. |
| A neutral A-pose character whose props are separate meshes | Rig + clips (pipeline below) |
| An enemy in a fixed attack pose (Meshy "Mine Bear Archer": drawn bow) | Static statue: yaw-track the rider, procedural tumble when shot |
What went wrong on 2026-09-29 (all three founder complaints at once): a T-pose model re-animated with seated
clips folded into the cart; the separate revolver/pickaxe meshes rode hand bones that sat inside the cart and
were never drawn. The founder's own posed model had both weapons already. **Check what a candidate model
already contains before adding anything to it** (`scripts/glb-shot.mjs`).
Posed-hero placement rules (all measured, see `runner_view.gd` HERO_*): feet-origin pivot; chest 0.55 m ABOVE
the cart rim so torso, hat, leaves and both weapons read; yaw the whole figure so the baked barrel (model +X)
points at the reticle, clamped to [-1.6, -0.2] rad; muzzle-flash pivot parented to the barrel tip
(0.45, 0.05, 0.48 native); on a cable the pickaxe head (model top) sits on the cable.

# Pipeline (rigged characters)
1. Forge the static PBR model first (`ep2-asset-forge`), keep its Meshy task id (forge_manifest.json).
   Rig within **3 days** of that task (Meshy deletes sources).
2. Pick ≤10 clips from the library (`GET /openapi/v1/animations/library`; ids in
   `docs/research/3d/002_meshy_rig_animation_api.md`).
3. `python3 tools/meshy/meshy_rig.py <task_id> .farm/rig/<name>_rigged.glb --height <m> --actions a,b,c`
4. `python3 tools/meshy/shrink_glb.py … src/episode2/assets/<name>_rigged.glb --max 1024`
   (7–8 MB → ~1.8 MB). Copy the `.rig.json` next to it for provenance.
5. **Measure** the key moment of every clip before choosing offsets (bone-speed peak / hips apex)
   — probe below. Put the numbers in `RunnerMotion` clip tables `[clip, offset, speed]`.
6. Gate: `tests/ep2_runner_motion_test.gd`.

# The code (separation of concerns)
- `src/episode2/runner/runner_motion.gd` — pure: `pick_rider(...)`, `pick_archer(...)`,
  `danger_eta(...)`, and the `Anim` cross-fade driver (sets loops on `LOOPING` clips).
- `runner_view.gd` — owns AnimationPlayers, feeds event timers (`_t_hit/_t_shot/_t_swipe/_t_hop/_t_cheer`),
  places the revolver/pickaxe on the RightHand/LeftHand **bone positions** each frame, shows the
  "!" emote when `danger_eta < DANGER_SECS`, turns the rider toward the aim point.
- Priorities (rider): zip > hit > swipe > duck > jump > hop > shoot > reload > cheer > idle.
  Archer: die > loose (0.5 s before its arrow flies) > aim (in range) > idle. Boarder: leap / stomp / flinch.

# Measured timings (re-measure after any re-rig)
Side_Shot trigger 0.86 s · Charged_Axe_Chop impact 2.02 s · Regular_Jump apex 0.80 s ·
CrouchLookAroundBow head at 65 % · Archery_Shot release 1.16 s.

Probe (run with `--headless -s`, delete after): load the GLB, `ap.play(clip)`, step
`ap.seek(t, true)` + `sk.force_update_all_bone_transforms()` every 0.02 s, track
`(sk.global_transform * sk.get_bone_global_pose(bone)).origin` — peak speed = the hit/release
frame, max hips y = jump apex.

# Traps (each one cost a capture)
- **Armature 0.01 scale** (bear): measure skinned height with `mi.get_aabb()` (`_measure_rig`),
  not through the node chain, or the rig renders ×100 off-screen. Motion test guards it.
- Clips import **non-looping**; `Anim` sets `LOOP_LINEAR` for names in `LOOPING`.
- Rigged GLBs keep **base colour only** — accept it, or re-texture; don't expect the PBR normals.
- The static GLBs stay as fallbacks (`rig` missing → static model → capsule), never nothing.
