---
name: ship-visual-proof
description: Stops "optimisation", pack-size, export-filter, import-setting, material, lighting or cleanup work from changing what the player sees. TRIGGER before any change to .github/workflows/export-game.yml (exclude_filter), *.import files, export presets, pack-size trims, texture/audio compression, material or lighting code, or any "tidy up / shrink / dedupe / remove unused" work, and before shipping anything the founder did not ask for.
---
# Why (founder 2026-10-18)

"Why did you change my rifle!!!" / "Why are you doing shit I didn't ask for!!! I don't want it highlighted."

Commit `a089786a` (2026-10-18, pack-size trim) added 20 loose texture files to the CI export
`exclude_filter`, claiming they were dead because "textures are EMBEDDED in the .glb, zero
references". That was wrong. `gltf/embedded_image_handling=1` EXTRACTS GLB textures to loose
files next to the model and the imported scene points at them. With those files out of the
pck, every one of these rendered untextured and washed out to white/cream in the shipped game:
the Winchester, the mine-lift cage, the flame quad, the Sheriff, Mike Dean, the cowboy, the
bartender and the donkey cart. No source code changed. The gate passed, CI was green, and the
build was broken for the player.

The lesson: a green gate and a green CI measure size and tests, not what the player sees.

# Rules

1. **A size or cleanup task may never change visible output.** If shrinking the pack, trimming
   an asset, or tidying files can alter a model, texture, sound, light or UI the founder has
   seen, it needs the proof below. If you cannot prove it is invisible, do not ship it.
2. **Never trust "unused".** "Zero references", "dead", "embedded" and "nothing loads it" are
   claims to test, not facts. Test with the engine, not with grep.
3. **Founder-approved things are locked.** The rifle, the title screen, the characters and
   anything the founder said they like do not change unless the founder asked in this
   conversation. When in doubt, ask. Do not "improve" them on the side.
4. **Do not add highlights, outlines, tints or glow the founder did not ask for.**
5. **One concern per commit.** A pack-size commit contains pack-size changes only.

# Proof required before shipping an export / import / material change

1. **Texture probe (must exit 0):**
   `godot --headless --path . --script tools/ep2_forge/texture_ref_probe.gd`
   It loads every shipped GLB and fails if any texture its materials use is matched by the
   export `exclude_filter`. `scripts/ship-to-master.sh` runs it.
2. **Before/after capture of every asset the change touches.** Render the model in the engine
   (SubViewport scene, since Hyprland tiles the window narrow) from the base commit and from
   your commit, same camera. Save both images in `docs/episode2-quality/<date>-<topic>/`.
   A model that went flat, white, grey, cream or black fails. A fresh critic subagent that
   did not make the change compares the pairs and answers "identical / different".
3. **Measure the export, not the editor.** The editor reads loose files from disk and hides
   exactly this bug. Check the web export (`scripts/ep2-local-export.sh`, which reads the
   preset out of the workflow) or a fresh-clone run (`scripts/pack-gate-fresh.sh`).
4. **If the pack gate fails, pick a change the player cannot see** (audio bitrate, a texture
   nobody looks at) and prove it with the same before/after. Never get under the gate by
   removing something the game loads.

# Report format

For each touched asset: `file | used by | before capture | after capture | identical?`.
Say "live" only after CI, the butler push and a look at the real itch build
(skill `always-ship-live`). Log it in `GM Game/Work Log/<date>.md`.

# Known traps

- Godot extracts GLB textures to `<name>_Image_N.png` / `_BaseColor.jpg` beside the GLB. They
  look like orphan files. They are not.
- A warm `.godot` cache or the editor can show the model fine while the export is stripped.
- `pck` size and a passing test block say nothing about how a model looks.
