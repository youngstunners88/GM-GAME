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
| 001 | bong-party-teaser | hype-30s | scripted (awaiting founder lock) | no | Astra creative filed; hero window 9.0–19.0s; NOT rendered; Seedance 2.5 unspent |

See `calendar/calendar.md` for the live board.

## Session 2026-09-18 — Drop 001 briefed + scripted
- Prompt: founder lock — cadence defaults, format-hype-30s, drop 001, hook seed
  "every Friday the smoke rings up on Solana", Seedance 2 for 30s, mark 10s hero,
  do NOT spend Seedance 2.5 yet
- Shipped:
  - Scaffolded `calendar/drops/001_bong-party-teaser/` (drop.md, brief.md,
    script_final.md, script_shots.md, prompts/ builds/ output/ posts/)
  - Board row added, advanced briefed → scripted
  - **Astra GPT-6** (`openai/gpt-6-astra`) via OpenRouter authored 3 hooks +
    30s beat sheet + 10s hero window (9.0–19.0s) → brief.md; shot list →
    script_shots.md; read-through → script_final.md
- OpenRouter: called (model `openai/gpt-6-astra`); ~3 completion calls, ~$0.15
  total. First attempt hit a `max_tokens` credit ceiling (HTTP 402); resolved by
  lowering max_tokens and splitting into affordable focused calls — NOT an
  outage, lead model used throughout (no weaker substitute).
- Fidelity note: Astra flagged "Friday" as `WAITING ON FOUNDER` (Gitbook says
  weekly). Founder's hook lock resolves it — Friday confirmed for the opening
  line only. All Astra lines filed verbatim.
- Stopped at: script_final.md + script_shots.md **ready for founder lock. NOT
  rendered.** Seedance 2.5 unspent per founder.
- Gates: n/a (no game code, no render)

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
