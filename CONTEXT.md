# GM-GAME Context

This file used to describe an early planned `src/` layout (PascalCase names
like `Player.gd`, `EnemyBase.tscn`) that predates the actual build — the real
codebase uses `snake_case` throughout and has grown well past that first
sketch (three levels, four bosses, a shooter prototype mode, an ICP canister
layer). Keeping a second, hand-maintained copy of the file tree here just
gives it a second chance to go stale, so this file now points at the sources
that are actually kept current instead of re-describing them.

## Where the real routing table lives

`CLAUDE.md`'s **CONTEXT-MANIFEST RULE** is the authoritative routing system:
read `.claude/context-manifests/default.md` first, then the manifest matching
the task's domain (`shooter.md` for the v1.2 prototype, `icp.md` for the
canister layer). Those manifests are actively maintained — a manifest whose
path 404s gets fixed in the same commit that found the problem, per their own
stated rule — so they don't drift the way this file did.

## Live project state

`STATUS.md` at repo root is the client-facing living report: what shipped,
what works, what's next. Updated every session.

## Workspace-level context

- `design/CONTEXT.md` — game design, level layouts, mechanics specs
- `docs/CLAUDE.md`, `src/CLAUDE.md` — directory-specific coding/doc standards
- `.claude/skills/` — the project's actual skill library (70+ skills); there
  is no separate "multi-model orchestrator skill" file — that workflow is
  `scripts/or-call.mjs` plus the prompt templates in `prompts/`, documented in
  `docs/session-logs/2026-07-28-orchestrator-setup.md`.

## Session history

`docs/session-logs/` — one dated file per work session, oldest-to-newest
narrative of what was built, what was found, what was verified.
