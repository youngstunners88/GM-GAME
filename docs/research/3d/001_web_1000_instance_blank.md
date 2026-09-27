# 001 — Web build draws no 3D above 1000 instances (VERIFIED)

**Symptom here (2026-09-27):** in the Episode 2 runner web build, the 3D view vanished
(HUD only, clear colour behind it) for ~3 s at a time. It happened whenever gold pickups
were in draw range — each pickup was a 14-mesh `gold_pile.glb`, pushing the scene past
1000 instances. Headless tests were green (no renderer), transforms were all finite.

**Root cause (found by research, not guessing):** godotengine/godot#96968 — Godot 4.3 is
the first version with non-threaded web exports, and the spatial indexer still switches to
threaded culling above `rendering/limits/spatial_indexer/threaded_cull_minimum_instances`
(default 1000). With no threads it culls everything. Reversible: drop below 1000 and the
world returns. Fixed upstream by PR #98121 (ignore the setting in single-threaded builds).

**Our fix:** `project.godot` → `limits/spatial_indexer/threaded_cull_minimum_instances=1000000`.
We must stay non-threaded (itch.io, see CLAUDE.md), so the setting is the fix, not threads.

**Proof:** `?ep2off=stress` adds 1500 meshes; `scripts/_bright.mjs`-style brightness sampling
in Chromium shows every frame rendered (no clear-colour frames) with the setting.

**How it was found:** 5 local `?ep2off=` bisection builds first narrowed it to "gold in view"
(and wrongly suspected the metallic material); one Exa search then named the real cause.
Lesson baked into the skill: **search before the second bisection round.**

Sources: https://github.com/godotengine/godot/issues/96968 · https://github.com/godotengine/godot/pull/98121
