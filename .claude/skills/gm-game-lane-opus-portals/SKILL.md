---
name: gm-game-lane-opus-portals
description: Opus 5.5 on OpenRouter does dangerous multi-file Godot merges when DeepSeek truncates or stage .tscn surgery can strand the player. Slug anthropic/claude-opus-5.5, plain Opus 5.5 only (founder: never the batch model).
---


# Opus lane — heavy merge only


Slug: `anthropic/claude-opus-5.5` — founder rule 2026-09-24: do NOT use the `:batch` model at all (it also cannot be called through chat/completions).
Wrapper: `node scripts/opus-offload.mjs` with a verify command (script compile + protocol_portals_test + new ladder/room test).


## Strength
Long-context edits across `level_0N_*.tscn` + `level_base.gd` + new portal scenes without dropping LevelBase runtime ground, cameras, or boss arenas.


## Owns
- Merging PortalLadder instances into the three live stage scenes
- Wiring descent/ascent so the player returns to the same world x
- Shared StudyRoom skins without packing 80M-poly anything
- Recovery when DeepSeek returns empty / fenced / truncated files


## Must not
- Be the default author (rate-limit + cost)
- Redesign protocol facts
- Replace Vault / Knox
- Import raw Meshy into the 2D stage


## Verify before giving files back to Claude
`godot --headless` compile + existing 155 portal tests + new room-loop test.
No commit from the offload script. Claude reviews `git diff`, then gates.
