# Skills routing — load ONE primary per task

**Rule: do not load all skills every session.** Load the primary skill for
the task type below, and the secondary only if the primary turns out to be
blocked or insufficient. This project has grown a large skill library —
loading it all for a single-purpose ask burns context for no benefit.

| Task type | Primary skill | Secondary (only if needed) |
|-----------|---------------|----------------------------|
| API key / "is X set?" / ElevenLabs / OpenRouter | `env-secrets-and-apis` | — |
| itch deploy / stale live build / butler | `itch-butler-deploy` | `env-secrets-and-apis` |
| "FIXED?" / founder still broken live / e2e proof | `live-build-proof` | `game-flow` |
| CI, gdparse, web export typing, security gates | `game-development` | `live-build-proof` |
| Death, wipe, Continue, menus, SceneRouter, pause | `game-flow` | `live-build-proof` |
| Blaze Rush enter/exit/finish | `game-flow` | `live-build-proof` |
| Sprites, parallax, VFX, UI polish | `game-graphics` | — |
| Touch / mobile / phone viewport | `mobile-playable` | `game-development` |
| Multi-model / OpenRouter orchestration | `multi-model-orchestrator` | — |

## Session-start checklist (30 seconds, every session)

1. Fetch-first (`git fetch` + `git merge --ff-only` the working branch).
2. `env-secrets-and-apis` presence-only scan — names, never values.
3. Note the live channel: which branch, whether a PR is open/draft/merged,
   and the last known itch build id if relevant to the ask.
4. Pick **one** primary skill from the table above for the founder's actual
   request before writing any code.

## Permanent project facts

- The founder's itch.io API key **is** the butler deploy credential. It may
  appear in a session as `ITCH_API_KEY` and/or `BUTLER_API_KEY` — check
  both names (`env-secrets-and-apis`) before saying deploy is unavailable.
- **Session env ≠ GitHub Actions repo secret.** A key present in this
  interactive session does not mean CI can see it — CI needs the repo
  secret configured under the exact name the workflow reads
  (`secrets.BUTLER_API_KEY` in `.github/workflows/export-game.yml`).
  Without that repo secret, every push exports but silently never deploys
  to itch — this was the actual root cause the last few "still broken
  live" reports traced back to, not a code bug.
- Last known manual deploy (verify before trusting, it will go stale):
  itch html5 build **#1850949 / version 66**, pushed 2026-08-08 with
  founder authorization after the Blaze Rush / full-wipe fixes. The founder
  must hard-refresh and confirm playtest — an agent proving something
  end-to-end in-engine is not the same as it being confirmed live.

## Not in this table but installed

`game-logic` (physics/save-load/scoring/difficulty/Web3 systems — pairs
with `game-development` for CI-adjacent logic bugs, or `game-flow` for
save/Continue specifically) and `gameplay-improvements` (combat feel, enemy
AI, boss balance, level design tuning — pairs with `game-graphics` when the
ask is also visual) are both installed under `.claude/skills/` from the
same pack. They didn't fit a single row above without duplicating rows for
every gameplay-adjacent ask; use judgment, but still load only what the
specific task needs.

**Note on `game-graphics`:** this repo already had a `.claude/skills/
game-graphics/SKILL.md` — a project-native skill pointing at
`design/art_direction_reference.md` and the real procedural-drawing
implementation. The imported pack's generic `game-graphics` skill was
**not** copied over it to avoid destroying that project-specific content;
the existing one already satisfies "game-graphics must exist."
