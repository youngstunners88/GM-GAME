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
| 001 | bong-party-teaser | hype-30s | assembled | not yet | 30s master + 10s hero in output/ (Seedance 2, ~$3.75); 2.5 unspent; awaiting founder review → distribution |

See `calendar/calendar.md` for the live board.

## Session 2026-09-18 — Drop 001 RENDERED + assembled
- Prompt: founder "Render 001" (typed 011; no such drop → read as 001) + end-card
  decision (end on "$SMOKE on Solana", drop handle, no figures)
- Render path proven: **MuAPI `seedance-2-text-to-video`** (Seedance 2, 4–15s/clip,
  720x1280, native audio). FilmEra MCP was not available; MuAPI used instead.
- Duration bound (4–15s) → 30s composed as 3 in-bounds clips, ffmpeg-assembled:
  - Clip A 0–8s   rid cc9fffc0…  · Clip B 8–20s rid beffbb7a… (hero 9–19s) · Clip C 20–30s rid 2c09a79a…
  - Render subtotal ~$3.75. **Seedance 2.5 NOT spent** (founder hold).
- Output: `output/2026-09-18_bong-party-teaser_30s.mp4` (30.27s) +
  `_hero10s.mp4` (10.0s, cut 9–19s). Raw clips in builds/ (gitignored).
- Sent both to founder for review before distribution.
- Gates: n/a (no game code)

## Session 2026-09-18 — Drop 001 LOCKED + Seedance 2 prompts
- Prompt: founder "lock 001"
- Shipped:
  - script_final.md + script_shots.md marked LOCKED
  - **Astra GPT-6** (temp 0.2) converted the 8 locked shots → `prompts/shot-01..08_seedance2.md` (Seedance 2)
  - `prompts/hero_window.md` documents the 9.0–19.0s cut-from-master plan; **no Seedance 2.5 prompt authored** (founder hold)
  - Board advanced scripted → render-ready
- Fidelity correction: shot-08 — restored founder-locked CTA "follow @smokering25"
  that Astra dropped over a misread of the no-on-screen-numbers rule (a brand
  handle is not a fake metric). Annotated in the shot file; founder can veto.
- OpenRouter: called `openai/gpt-6-astra` (1 batched prompt-authoring call,
  ~$0.10). Lead model throughout; no substitute.
- **NOT rendered.** Awaiting founder render go + a live render path (FilmEra MCP
  not added this session; MuAPI available). Seedance 2.5 unspent.
- Gates: n/a (no game code, no render)

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
