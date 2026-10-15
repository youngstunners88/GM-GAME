---
name: assetfurnace-pipeline
description: Turn a picture into a rigged, animated GLB with AssetFurnace (image-to-3dlab) on a cloud GPU, then import it into GM-GAME. TRIGGER on "assetfurnace", "image to 3D", "auto-rig", "rigged model", generating a character/prop from a picture, or when a Blender procedural build is not realistic enough.
---
# Why (founder 2026-10-16)

Realism is critical and the local box cannot run 3D generation (2 GB GeForce 920MX;
backends need Apple Silicon or 16 GB+ NVIDIA). AssetFurnace (Bingeljell/image-to-3dlab,
Apache-2.0, `https://github.com/Bingeljell/image-to-3dlab`) is the free route:
picture in → textured mesh → auto-rig (SkinTokens) → 21 fitted moves → GLB for Godot.
It runs on a rented cloud GPU (its README documents RunPod) or the founder's own PC.

# Rules

1. **Rent, don't force local.** Target a RunPod pod (or equal) with 24 GB+ VRAM.
   Never attempt TRELLIS.2 / Hunyuan3D-2.1 / Pixal3D-CUDA on the 2 GB local card —
   it OOMs; CPU fallback takes hours per asset. Record pod type + cost in the commit.
2. **Input discipline** (their `docs/prompt-guide.md`): soft 3D-render look, A-pose,
   open hands/paws, plain background. For HORSES: side-profile reference photo,
   legs visible and separated, head up. Bad input = bad rig; re-shoot the picture,
   never "fix it in post" with sculpting before trying a better input once.
3. **Backend pick:** Pixal3D first (single pass, keeps flat colours); TRELLIS.2 when
   fidelity beats speed (beware colour drift on flat illustration input — use photos).
   Hunyuan3D weights are NOT licensed for EU/UK/SK redistribution — check before ship.
4. **Finish chain before import:** retopo (game-size faces) → Pixel Match (keeps the
   source's real pixels: logos, faces, markings) → compress. A raw ~900k-face,
   30 MB GLB never lands in `src/` directly.
5. **Rig check for quadrupeds:** auto-rig targets humanoids — read their
   `docs/quadruped-pipeline.md` and verify feet stay planted through the exported
   move. If the fitted move slides, keep the MESH and re-rig with the in-repo
   Blender bone rig (`src/assets/models/horse/build_horse.py` pattern) instead of
   shipping a skating asset.
6. **Provenance in-repo:** every generated file lands under
   `src/assets/models/<asset>/` with the source picture, backend + seed, the
   `.provenance.json` sidecar, and license classification. BRIA RMBG is disabled
   upstream — inputs carry real alpha; never swap in another remover silently.
7. **Godot import:** GLB → Godot 4.3 import, AnimationPlayer moves as named clips.
   2D stages use headless side-view frame renders (transparent, feet-planted shared
   canvas — see the horse frames) as SpriteFrames, never live 3D.

# Gate

- Side-by-side: source picture vs turntable render vs in-game capture.
- Move check: walk/graze (or chosen move) plays 3 loops with feet planted, no skate.
- Size check: finished GLB + textures listed with byte counts; frames trimmed.
- Live proof (`browser-verify-game`) before "done".
