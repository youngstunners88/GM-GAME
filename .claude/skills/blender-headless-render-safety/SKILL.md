---
name: blender-headless-render-safety
description: Render and iterate on Blender scenes WITHOUT using the open GUI session's MCP (render_viewport_to_path / execute_blender_code). On this 8 GB RAM / GeForce 920MX machine a heavy EEVEE render through the GUI MCP freezes Blender, times out every tool, and (2026-10-05) took the whole app down with the unsaved scene. TRIGGER before ANY Blender render, volumetric/DOF/GI test, scene build with 100+ objects, or whenever an Blender MCP call "timed out".
user-invocable: true
allowed-tools: Bash, Read, Write, Edit
---

# Blender: render headless, never through the GUI MCP

## Why (what actually happened, 2026-10-05)
- `mcp__Blender__render_viewport_to_path` ran a 500-object EEVEE scene (haze volume, DOF, GI) inside the artist's GUI Blender. The call timed out, then **every** MCP call timed out
  (Blender "Not Responding", 2 GB RAM), then Blender restarted and the in-memory scene was lost (only an earlier `save_as` survived).
- Machine: 7.9 GB RAM total with ~2 GB free, GeForce 920MX (2 GB VRAM, no RTX), i7-6700HQ. No system Python or Node on PATH (`python`/`node` not found) - Blender's own bundled Python is the only interpreter.

## Rules
1. **GUI MCP = inspect and tiny edits only** (`get_objects_summary`, screenshots, reading properties). Never render, never build 100+ objects, never bake there.
2. **Put the build in a script file in the repo** (`tools/ep2_blender/*.py`), idempotent (delete its own collection/materials first). A scene that only lives in RAM is a scene you will lose.
3. **Render with a separate process and a log file**:
   ```bash
   BL="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
   (nohup "$BL" -b [file.blend] --python tools/ep2_blender/<script>.py -- <args> > .farm/run.log 2>&1 &)
   for i in $(seq 1 18); do sleep 15; grep -q -E "render done|Traceback" .farm/run.log && break; done; grep -E "render done|Traceback|Error" .farm/run.log
   ```
   Piping through `| tail` in a background shell throws the log away - that is exactly how a failed run in this repo became "unknown cause". Always `> file 2>&1`.
4. **Iterate small**: 640x360 @ 16 samples (~25 s) until the look is right, then one 1920x1080 @ 64 final. Scale 4096 textures to 2048 inside the script.
5. **Do not touch the user's unsaved scene.** Check `bpy.data.is_dirty` / `filepath` first; for anything destructive build into a new file (`..._v3.blend`) or a separate headless process.
6. **Debug with a neutral pass** (`--neutral`: white lights, Standard transform) before touching materials - it separates material faults from lighting faults in one render.
7. Check the user's Blender is alive with `powershell Get-Process blender | Select Responding`; if `Responding=False`, WAIT (a background poll), do not kill it.
8. The headless process loads the user's Tripo add-on (websocket on port 60600, "port in use" warning). Harmless; ignore it.

## Where this applies
`tools/ep2_blender/rifle_hero.py` (skill `ep2-rifle-realism`) and `tools/ep2_blender/bull_hero_scene.py` (Inferno Bull forge hall - **written but never verified by a render**; run it with rule 3 once the GUI scene is saved or closed, because it builds ~500 objects).
