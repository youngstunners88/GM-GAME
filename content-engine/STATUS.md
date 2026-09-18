# STATUS — Smoke Content Engine

## Current
- Engine created: 2026-09-18
- Phase: engine scaffolded — repeatable pipeline ready, first drop not yet run
- Lead LLM: Astra GPT-6 via OpenRouter
- Default format: 30s Seedance 2 master + 10s Seedance 2.5 hero
- Cadence target: see `calendar/calendar.md`

## What exists
- `CLAUDE.md` — engine identity, drop lifecycle, routing, hard rules
- `calendar/calendar.md` — cadence + drop backlog board
- `formats/` — reusable recipes: 30s hype, 10s hero, still-post, X-thread + the
  `format-template.md` blank
- `script-lab / production / distribution` — CONTEXT.md per workspace
- Skills: astra-lead, seedance-pipeline, mcp-video-tools, distribution-smoke,
  **content-calendar** (new), **drop-runner** (new)
- `archive/` — for shipped drops

## Drops
| # | Slug | Format | State | Shipped | Notes |
|---|------|--------|-------|---------|-------|
| — | — | — | — | — | No drops run yet — scaffold the first with `/drop-runner` |

See `calendar/calendar.md` for the live board.

## Session 2026-09-18 — Engine foundation
- Prompt: "create a content engine based on the smoke-launch-video pack"
- Shipped:
  - Generalized the single-launch pack into a repeatable engine workspace
  - Added drop lifecycle, format library, and content calendar
  - Ported + generalized the 4 pack skills; added content-calendar + drop-runner
- Still open:
  - First real Astra brief + locked hook
  - First Seedance 2 test renders
  - FilmEra + Browser Use MCP live check
  - Founder to confirm cadence + first format
- Gates: n/a (docs/workflow pack, no game code touched)
- OpenRouter: not called this session
