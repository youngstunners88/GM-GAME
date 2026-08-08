# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.3.stable |
| **Project Pinned** | 2026-02-12 |
| **Last Docs Verified** | 2026-07-31 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | LOW — pinned version is within LLM training data |

## Corrected 2026-07-31

This file previously claimed the project was pinned to **Godot 4.6** — that
was **wrong and never true**. The actual pinned/shipped engine, confirmed
against every ground-truth source in this repo, has always been **4.3**:
- `project.godot` → `config/features=PackedStringArray("4.3", "Forward Plus")`
- `.github/workflows/export-game.yml` → `GODOT_VERSION: "4.3-stable"`
- `CLAUDE.md` title → "Godot 4.3 2D Platformer"
- Every session's local engine bootstrap → `Godot_v4.3-stable_linux.x86_64`

`docs/CLAUDE.md` and `src/CLAUDE.md` both tell every coding session to
"always check `docs/engine-reference/` before using any engine API" — a
stale claim of 4.6 here was actively steering sessions toward suggesting
4.4+-only syntax (`@abstract`, variadic `Variant...` args, Jolt-as-default,
etc.) that a real 4.3 export **rejects as a hard parse error**. That is
exactly the failure class the Distributor boss shipped with once already
(a `:=`-from-Variant parse error that made the whole script silently inert —
see `tests/distributor_behaviour_test.gd`'s header). A grep confirmed no
shipped `.gd` file currently uses any 4.4+-only syntax, so this was a live
risk, not yet a realized bug.

The 4.4→4.6 research in `breaking-changes.md` and `current-best-practices.md`
was real work and is kept, but it describes a **future upgrade path that has
not been undertaken** — it does not apply to the engine this project
currently builds and ships against. Do not use anything from those two files
when writing GDScript for the current codebase; they are upgrade-planning
reference only, for whenever `/setup-engine upgrade 4.3 4.6` is actually run.

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3, which is exactly
what this project is pinned to — so for the *current* engine, there is no
gap. The gap only matters if/when the project upgrades past 4.3; see the
correction above.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://godotengine.org/releases/4.6/
