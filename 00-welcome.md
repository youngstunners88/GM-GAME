# You are building Lil Blunt: The Smoke Realm. Read this first.

A Godot 4.3 retro platformer for **Rich** (SmokeRing / DIAMONDS / GoldMine
crypto ecosystem), engineered up the coach's value stack: 📖 **Book** (the
platformer) → 🎬 **Movie** (baked-in ecosystem context) → 🎮 **Video Game**
(interactive + self-improving from player data).

This workspace follows the **ICM umbrella form** (github.com/RinDig/icm-architect):
the root is a map, each track is a self-contained node, and **the catalog holds
no books** — track folders route you to the real code and docs, they don't
duplicate them.

## The map — pick your track

| You are here to… | Go to | Physical code lives in |
|---|---|---|
| Change the game (levels, player, bosses, UI) | `godot-client/` | `src/`, `project.godot` |
| Change APIs, email, analytics, LLM proxy | `backend/` | `backend/*.js`, `wrangler.toml` |
| Change campaigns, social, funnels, referrals | `marketing/` | `backend/marketing.js`, templates, `scripts/` |
| Read/write the framework, guides, security | `docs/` | `docs/`, root `*.md` deliverables |

Each track carries the same four files:
`00-context.md` (what + which layer + dependencies) → `01-current-state.md`
(built / in-progress / blocked) → `02-next-task.md` (the single next action +
acceptance criteria) → `03-decisions.md` (append-only decision log).

## The walk

1. Read `01-architecture.md` (how the tracks connect — 2 minutes).
2. Read `02-status.md` (health, blockers, what's waiting on the client).
3. Open your track's `02-next-task.md` and do exactly that.

## Non-negotiables (full list in `CLAUDE.md`)

- **ALWAYS-SHIP**: every significant change → update `STATUS.md`, commit,
  push, keep master current.
- **SECURITY-GATE**: `scripts/security-sentinel.sh` + `scripts/security-audit.ts`
  run on every ship; never bypass to ship faster.
- Web export stays **non-threaded**. No real addresses/keys in code — `config.json`
  + Worker secrets only. Weed content chill; enemies never weed-themed.
