# Cloud startup additions

Use the existing `/workspace/GM-GAME` checkout and repository resume instructions.
Do not create worktrees for onboarding or reinstall over existing skill edits.

```bash
cd /workspace/GM-GAME
export XDG_DATA_HOME=/workspace/.gm-game-data
export XDG_CONFIG_HOME=/workspace/.gm-game-config
export XDG_CACHE_HOME=/workspace/.gm-game-cache
export GODOT=/workspace/.gm-game-tools/Godot_v4.3-stable_linux.x86_64
export BLENDER_EXE=/workspace/.gm-game-tools/blender52/blender-5.2.2-linux-x64/blender
python tools/blender_skills/verify_install.py
"$BLENDER_EXE" -b --factory-startup --python-exit-code 1 -P .claude/skills/blender-core/scripts/env_report.py
"$GODOT" --headless res://tests/ep2_logans_lake_test.tscn
```

Require the receipt match, Blender `ok:true` / version 5.2.2 and lake ALL PASS.
The official Blender release manifest/tarball and Godot templates are retained
under `.gm-game-tools`; system binaries are different versions. See the existing
environment install script for Godot/npm setup. Use `run_checked.py` for semantic
asset QA failures. GPU-dependent upstream tests were skipped locally, not passed.

Runpod spending is explicitly authorized for this task. The founder saved the
credential as `RUNPOD`; `tools/ep2_runpod/pod_run.py` now also accepts that name.
Inspect presence without printing the value, then run `status` read-only. Saved
configuration does not prove a fresh process has the binding. Preserve existing
pods/jobs, record rate/ID, fetch results and stop task-owned resources when done.
Do not run the old helper's unverified Blender 4.5 installer for this 5.2 toolkit.

An additive startup-draft save was attempted twice on 2026-10-19. The environment
configuration service returned `INVALID_ARGUMENT`; a subsequent read confirmed
the new instructions were **not saved**. The existing configuration was preserved.
These instructions are retained here; environment-draft persistence remains
unconfirmed until the service accepts the update. No new secrets were requested.
