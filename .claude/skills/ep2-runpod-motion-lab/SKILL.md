---
name: ep2-runpod-motion-lab
description: Produce detailed, natural motion clips for Episode 2 humans (Rich, Utah, townsfolk) on the founder's Runpod GPU - text-to-motion or video-to-motion on the pod, retargeted in headless Blender onto the game skeleton, baked to clean game clips. Cost rules, pod lifecycle, clip list, licensing. TRIGGER on "detailed movements", "they move stiffly", "make them animate properly", "motion on Runpod", "generate animations", "mocap".
---

# Runpod motion lab (founder 2026-10-19: "move properly with detailed movements", "access Runpod for this")

Read first: `ep2-cloud-gpu-runpod` (pod facts, `tools/ep2_runpod/pod_run.py`, Jupyter-over-HTTPS access) and
`ep2-character-performance` (the motion contract: planted feet, stride matched to speed, anticipation and settle,
moving holds, skin guard). This skill is the production path for HUMAN clips; the bear/Bull rules there still apply.

## Access (checked 2026-10-19)
- The Runpod MCP server (`mcp__runpod-key__*`) is authenticated: no API key is needed from the founder.
  `runpodctl` is at `~/.local/bin/runpodctl`; `RUNPOD_API` may be in the env (name only, never print it).
- Founder pod `xw8jpdvnvbkwr2` "average_coffee_vole": 1x RTX 4090, 50 GB container disk, no volume, **$0.89/h**,
  status EXITED on 2026-10-19 (no compute charge while stopped).
- **Money rules**: state the hourly price and an estimate before starting or creating anything; get the founder's
  yes; report minutes and $ after every job; stop the pod when idle (container disk is lost on stop, so copy results
  out first); never terminate or delete what the founder did not ask for.

## Pipeline
1. **Clip list first** (per character, 30 fps, loops closed, in place unless the clip is a travel clip):
   Idle, Idle2 (glance, weight shift), Walk, Turn90 L/R, StairsUp, StairsDown, Greet (nod + hat touch), Talk (dry
   gestures, Rich), Point, Counter (lean on hands), WipeRifle, InspectRifle (shoulder, sight, lower), Carry (crate),
   PutDown, Reach (high shelf), Sit/Bench (Utah at the workbench), CigarPuff (Rich).
2. **Generate on the pod** with an open text-to-motion model that outputs SMPL/SMPL-H joint rotations
   (current candidates: Tencent HY-Motion 1.0, MoMask; check the licence for commercial game use and record it
   in `design/ep2/motion/jobs/<job>/rights.md` before using any output). Prompts describe one action with timing
   ("a shopkeeper leans on a counter with both hands, shifts weight, looks up, 6 seconds"). Generate 3-4 seeds per
   clip and keep the best. Video-to-motion (a founder reference video) is the alternative for signature moves.
3. **Convert**: SMPL -> BVH on the pod (or locally), keep the source files with the job.
4. **Retarget in headless Blender** (installed `blender-animation` skill): match rest poses (T vs A matters most),
   COPY_ROTATION per bone + hips location scaled by leg length, then self-bake with
   `~/.claude/skills/blender-animation/scripts/bake_action.py --source X --target X`, remove the constraints.
   Rich's UE-style rig and Utah's Mixamo rig are first mapped to the shared game skeleton (`ep2-tripo-folk-to-game`).
5. **Clean**: decimate keys 0.3-0.5, smooth jitter without killing fast intent, lock feet with IK pins on contact
   frames, close loops (first = last pose and velocity), no bone scale keys.
6. **Hands**: rifle wiping, crate carrying and counter leaning need contacts measured against the props in the
   Armory (`ep2-prop-contact-animation`). Generated motion gets the body right; contacts are authored on top.

## Proof
- Per clip: `look`-style frame strip (headless render, 8 frames) from front and side; feet do not slide (world-space
  foot travel on contact frames < 2 cm); no knee or elbow pops; loop seam invisible.
- Skin guard: `~/.claude/skills/blender-character-rigging/scripts/stress_poses.py` plus every clip rendered on the
  decimated game mesh (not only the source mesh).
- In Godot 4.3: each clip plays in the Armory from the Episode 2 camera, at the speed the NPC actually moves
  (stride matched), switching clips blends (cross-fade 0.2-0.3 s), never snaps.
- Report to the founder: clip count, pod minutes, $ spent, pod state (stopped or running).
