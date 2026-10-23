---
name: gm-blender-godot
description: Use the installed EL4CTEO Blender toolkit safely in GM-GAME: Blender 5.2 authoring, Godot 4.3 Compatibility export, pinned installation, semantic QA and source preservation.
---

# gm-blender-godot

Read docs/research/blender-skills/README.md and installation.json. The 22 upstream skills are project-local for Claude and Codex; the game-specific instructions here take precedence. The upstream license is preserved beside the audit.

1. Run `python tools/blender_skills/verify_install.py`. Stop on an unexpected mismatch and inspect it; do not overwrite another session's changes with install.sh.
2. Set BLENDER_EXE to the verified Blender 5.2.2 executable. In this cloud snapshot: `/workspace/.gm-game-tools/blender52/blender-5.2.2-linux-x64/blender`. System Blender is older. Keep XDG_CONFIG_HOME and XDG_CACHE_HOME in writable workspace paths.
3. Load blender-core plus only the relevant upstream skill. Read scripts before running them when reviewing or installing untrusted upstream code. Use a fresh process, absolute inputs and a distinct output copy. Select the intended asset; this environment can inject an unrelated Icosphere even into a new scene.
4. Use `python tools/blender_skills/run_checked.py --blend FILE .claude/skills/blender-asset-qa/scripts/qa_check.py -- --objects NAME --profile game`. Parse pass/ok and inspect warnings. Exit 0 from the unwrapped upstream CLI is not proof of passing QA.
5. For rigs use `.claude/skills/blender-character-rigging/scripts/rig_check.py`, not the stale weights_check.py prose reference. The installed large-collection slice fix is recorded in the receipt.
6. Export plain GLB using the godot preset. Generic web enables meshopt/WebP and does not match our Godot 4.3 decoder. No quantization/Draco/KTX2 by default. Preserve clips, joint count, materials, UVs, scale and bind pose through an actual import.
7. Read fresh PCK metrics before changing unrelated assets. Never alter founder-locked title art or disable security to fit budget. Use the actual gameplay camera before acceptance.

47 upstream tests passed and 3 GPU checks skipped on 2026-10-19; this is a toolkit baseline, not proof every new asset is correct. The founder explicitly authorized RunPod GPU spending for this lake task: inspect live credential presence, never print it; a saved configuration entry is not a running-shell binding. Use that authorization when the binding is available; record rate/ID and clean up only task-owned resources.
