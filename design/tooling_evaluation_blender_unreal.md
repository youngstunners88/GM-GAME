# Tooling Evaluation — Unreal_mcp & blender-skills (2026-07-08)

**Decision: NOT adopted.** Stored so we don't re-litigate this later.

## What was proposed
Client-side suggestion to adopt two repos to "make the game look better":
1. `github.com/ChiR24/Unreal_mcp` — MCP server that drives **Unreal Engine 5**
   (asset management, Niagara VFX, Sequencer) via a live editor plugin.
2. `github.com/kevinbadi/blender-skills` — Claude skills that drive **Blender**
   (Meshy API image→3D generation, product-showcase camera moves) via blender-mcp.

## Why neither fits this project
- **Wrong engine**: This game is Godot 4.3 (pinned in CLAUDE.md). Unreal_mcp has
  nothing to connect to here — zero effect on the game.
- **Wrong dimension**: Lil Blunt is a 2D pixel-art sprite (16-bit GBA style, per
  the art direction). blender-skills produces 3D models/renders; a 3D Lil Blunt
  would fight the established retro art identity, and pre-rendered-3D sprites
  would clash with the hand-pixeled tiles.
- **Wrong runtime**: Both require locally running desktop software (Unreal
  editor / Blender + paid Meshy API). The dev loop for this project runs in a
  cloud environment and the client reviews on mobile.

## What ACTUALLY makes Lil Blunt look "as designed"
1. **Sprite sheets** replacing the current placeholder ColorRect visuals —
   follow `ASSET_MANIFEST.md` naming (`sprite_lil-blunt_run_01.png` etc.) and
   the /assets pixel-art pipeline. This is the single highest-impact visual step.
2. **In-engine juice** (already partially present): particles for Blaze Mode
   smoke trail, screen shake, squash-and-stretch tweens, parallax depth.
3. **Godot shaders** for glow/haze (Smoke Realm identity) — CanvasItem shaders,
   not external DCC tools.

If 3D-rendered marketing shots are ever wanted (NOT in-game art), blender-skills
could be revisited for promo material only.
