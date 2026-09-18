# Drop 001 — Bong-Party Teaser
Format: format-hype-30s
State: assembled (30s master + 10s hero built; awaiting founder review → distribution)
Target date: WAITING ON FOUNDER
Hook (locked seed): "every Friday the smoke rings up on Solana"
Hero window: 9.0–19.0s (cut from Seedance 2 master — 2.5 unspent)
Masters:
- output/2026-09-18_bong-party-teaser_30s.mp4 (720x1280, 30.27s)
- output/2026-09-18_bong-party-teaser_hero10s.mp4 (720x1280, 10.0s, cut 9–19s)
Links (posts): none yet

## Recipe (from formats/format-hype-30s.md)
30s Seedance 2 story clip. 9:16. Hook in 1.5s, party-peak middle (mark 10s hero
window here), payoff = wrapped-Smoke NFT / SOL-reward eligibility (locked claim
only), CTA = $SMOKE on Solana + LilBlunt.win + follow @smokering25.

Beats:
1. 0.0–1.5s — Hook
2. 1.5–8s — Setup (Smoke Realm)
3. 8–20s — Party peak (10s hero window marked here)
4. 20–27s — Payoff (wrapped-Smoke NFT / SOL-reward eligibility)
5. 27–30s — CTA

Must-include: Lil Blunt on-model (consistent design/wardrobe/lighting), $SMOKE +
Solana in payoff/CTA, bong party as recurring anchor.
Must-not: fake ticker prices / TVL / APY / "guaranteed SOL"; Seedance 2.5 on the
full 30s; characters/brands not in the locked brief.

## Founder lock (2026-09-18)
- Cadence: calendar.md defaults
- Format: format-hype-30s
- Hook seed LOCKED: "every Friday the smoke rings up on Solana"
- Seedance 2 for the 30s; mark a 10s hero window; DO NOT spend Seedance 2.5 until founder says so
- No invented APY/MC/TVL/guaranteed SOL

## Log
- 2026-09-18 scaffolded (drop-runner)
- 2026-09-18 briefed — awaiting Astra creative
- 2026-09-18 Astra GPT-6 (openai/gpt-6-astra) authored 3 hooks + 30s beat sheet + 10s hero window (9.0–19.0s) → brief.md; shot list → script_shots.md; read-through → script_final.md
- 2026-09-18 Astra fidelity-flagged "Friday" (locked facts say weekly); founder lock of the hook resolves it — Friday confirmed for the opening line only
- 2026-09-18 state=scripted, awaiting founder lock. NOT rendered. Seedance 2.5 unspent per founder.
- 2026-09-18 FOUNDER LOCKED ("lock 001"). script_final.md + script_shots.md marked LOCKED.
- 2026-09-18 Astra GPT-6 (temp 0.2) converted the 8 locked shots → prompts/shot-01..08_seedance2.md (Seedance 2). hero_window.md notes the 9.0–19.0s cut plan; no Seedance 2.5 prompt authored (founder hold).
- 2026-09-18 Fidelity correction on shot-08: restored founder-locked CTA "follow @smokering25" that Astra dropped over a misread of the no-on-screen-numbers rule (handle ≠ metric). Annotated; founder can veto.
- 2026-09-18 state=render-ready. NOT rendered — awaiting founder render go + live render path (FilmEra MCP / MuAPI).
- 2026-09-18 FOUNDER: end card ends on "$SMOKE on Solana", drop @smokering25 handle, no figures. Reverted the shot-08 handle correction; script_final CTA updated.
- 2026-09-18 FOUNDER: "Render 001" (typed 011 — no such drop; read as 001).
- 2026-09-18 Render path = MuAPI `seedance-2-text-to-video` (Seedance 2, 4–15s/clip, x-api-key). Seedance 2.5 held. Duration bound → 30s renders as 3 clips (A 0–8s, B 8–20s [hero 9–19s], C 20–30s), ffmpeg-assembled.
- 2026-09-18 RENDERED (Seedance 2, 720x1280, 24fps, native audio):
  - Clip A 0–8s   rid cc9fffc0-ea6d-4e55-9f12-8ff19eb3d62c  (8.10s) $1.25
  - Clip B 8–20s  rid beffbb7a-9e8c-4137-966d-91ba7ca20447  (12.10s) $1.25
  - Clip C 20–30s rid 2c09a79a-419a-4152-b2e1-8c917d13d3a4  (10.08s) $1.25
  - Render subtotal ~$3.75. Raw clips in builds/ (gitignored).
- 2026-09-18 ffmpeg concat → output/…_30s.mp4 (30.27s); cut 9–19s → output/…_hero10s.mp4 (10.0s). Seedance 2.5 NOT used.
- 2026-09-18 state=assembled. Sent to founder for review before distribution.
