---
name: gm-game-lane-gemini-3d
description: Gemini 4 Argon (google/gemini-4-argon) as the second-opinion lane for Episode 2 3D character and prop work - diagnosing bad textures, skinning/silhouette risks and repair plans from real engine captures. Prompt template, input pack, dispatch, output handling and cost caps. TRIGGER on "ask Gemini", "Argon", "second opinion on the model/rig/texture", a candidate GLB that looks wrong in the engine, or after any Hunyuan/Tripo/Meshy regenerate before shipping.
---

# Gemini 4 Argon - 3D review lane

Role: ADVISOR. It never edits the repo and never approves a ship. Claude re-derives every claim (open the file, run the
measurement, look at the capture). Router and calibration rules: `ep2-model-routing`. Pipeline context: `ep2-gpu-character-regenerate`.

## Build the pack (small and real; 3-6 images, 1024 px on the long side is plenty)
1. REFERENCE image the model must match (founder art).
2. OLD engine capture and NEW engine capture from the SAME camera (`tools/ep2_shots/*_shot.tscn`; Godot at `~/.local/bin/godot`).
3. Optional: turnaround renders (front / 3-4 / side / back) of the candidate, and a UV-atlas image.
4. Facts that cannot be seen: face count, texture sizes, GLB bytes, stretched-edge counts (`tools/ep2_blender/bull_game_inspect.py`),
   skeleton/clip constraints, engine and material settings, what was already tried and failed. A model that is not told
   what failed will re-propose it.

## Dispatch
```bash
node scripts/or-call.mjs google/gemini-4-argon prompts/gemini/gemini-4-argon-3d-review.md OUT.md --dry-run \
  --image REFERENCE.jpg --image OLD.png --image NEW.png       # prints tokens + worst-case $
node scripts/or-call.mjs google/gemini-4-argon prompts/gemini/gemini-4-argon-3d-review.md docs/model-responses/gemini-argon-<topic>-<date>.md \
  --image REFERENCE.jpg --image OLD.png --image NEW.png       # needs OPENROUTER_API_KEY in the shell
```
Copy the template and edit the Facts/Observed-defects block per job; keep the 5-part answer structure (it makes answers
comparable across models and cheap to verify). Use `:batch` (half price) when not waiting on the answer.

## Handling the answer
- Tag every claim CONFIRMED (you reproduced it), REFUTED, or UNVERIFIED; act only on CONFIRMED.
- Wrong file names / invented engine features / ignoring "already failed" list = downgrade the lane (log it).
- Feed numbers it asks for (region luminance, SSIM) to Jev typed decisions if a ship/no-ship call is needed (`jev-1-14-routing`).
- Cost: <= ~$0.25 per 3-image review. Stop at $1 per task and ask.

## First job (RUN 2026-10-15, $0.023; see the calibration log in ep2-model-routing)
The Bull face problem. Pack: `inferno_bull_with_rifle.jpg`, `engine_old_front.png`, `engine_new_front_emis035.png`, prompt
`prompts/gemini/gemini-4-argon-3d-review.md` (already contains the facts). Known answer for calibration: dark face = painted
albedo, not lighting; emission fogs; geometry detail is better; repair = face-island repaint at low emission.

Lessons from the first run: (1) list known confounds IN the image caption/facts ("this NEW capture has emission 0.35 on") - Argon read
the facts block but still attributed the washout to material; (2) ask it for the cheapest CONFIRMING test per hypothesis (it supplied
UNSHADED, which settled the question); (3) its repair steps are executable (vertex-colour mask bake, projection paint, luminance/SSIM
measures), so hand them to a headless Blender script and measure; (4) never let its REJECT/SHIP stand alone.
