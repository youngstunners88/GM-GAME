---
name: ltx-layout-to-render
description: Turn a Blender grey-clay playblast + art-direction stills into finished video/frames with the LTX-2.5 Layout-to-Render LoRA, for photoreal creature motion and cutscenes. TRIGGER on "LTX", "layout to render", "clay render", "AI finish a playblast", photoreal animation passes, or Episode 2 film/cutscene finishing.
---
# Why (founder 2026-10-16)

Lightricks `LTX-2.5-22b-IC-LoRA-Layout-To-Render` (HF, `ltx-2.x-community-license`)
renders finished video FROM a 3D viewport animation: grey clay or blocky playblast
carries camera + motion + placement (Blender/Unreal), a first frame (made from the
clay's first frame via any image model — never the grey frame itself) carries art
direction. Killer fit for "hyper realism in movements": our rigged horse walk cycle
rendered as clay + a photoreal horse still = finished gallop footage, motion
guaranteed real because the layout IS our animation. Same trick finishes Episode 2
films from staged blockouts.

# Rules

1. **Compute is remote.** The 22B distilled pipeline wants ~24 GB VRAM; the local
   2 GB card cannot run it and no HF Inference Provider hosts it. Routes, cheapest
   first: (a) ComfyUI + `ComfyUI-LTXVideo` nodes on a rented GPU (RunPod etc.),
   (b) LTX Studio / fal-style hosted inference if/when supported, (c) founder's PC
   if it has the VRAM. Record route + cost per shot.
2. **Layout recipe (their model card):** 24 fps clay/playblast from Blender,
   width × height divisible by 64 (1920×1088 known-good), frame count snaps to
   8k+1 (72f → 65f — plan for the trim). Two-stage distilled: 960×544 × 8 steps,
   then 2× upscale + 3 steps at full res. LoRA strength 1.0, CFG 1,
   `euler_ancestral`, seed 42 for reproducibility.
3. **Keyframes hold the look:** first frame mandatory (the art direction), add mid +
   last frames for long shots. Prompt = 1–2 sentences describing the FIRST FRAME;
   never write "clay / 3D / Unreal" in it. If output ignores art direction, the
   first frame was wrong — regenerate the still, not the video.
4. **Sprite extraction:** finished clips become game frames with ffmpeg
   (`-vsync 0` PNG sequence), trimmed + feet-planted shared canvas like the horse
   frames. AI video boils between frames — run 2 seeds and keep the steadier, or
   restrict AI finish to the BODY and composite our crisp legs/head over it.
5. **License gate:** `ltx-2.x-community-license` + gated HF access (contact-info
   consent) — read the full terms before ANY asset ships; commercial clearance is
   per-asset and recorded in `src/assets/models/<asset>/`. When in doubt, AI
   footage is reference/cutscene-only, never sold as the game sprite without
   clearance.
6. **Alignment proof:** overlay first/last output frames on the clay layout —
   camera + object placement must match (that alignment is the entire reason to use
   this over plain text-to-video). Drift = re-run with stronger keyframes.

# Gate

- Layout clip + first-frame still + prompt committed next to the output.
- Overlay check (layout vs finished) attached; boiling assessed across 2 seeds.
- In-game capture of extracted frames before "done" (`browser-verify-game`).
