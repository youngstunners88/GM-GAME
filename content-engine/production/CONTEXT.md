# Production — Seedance pipeline

## What happens here
Build the video for a drop. Seedance prompts, MCP runs, masters. Per-drop work
lands in `../calendar/drops/NNN_slug/` (`prompts/`, `builds/`, `output/`); the
folders here (`briefs/ specs/ builds/ output/`) are shared scratch/reference.

## Stack
- Main story: Seedance 2 (all shots)
- Hero 10s: Seedance 2.5 — one clip only
- Prompt authoring: Astra GPT-6 (OpenRouter) → Claude writes files
- Capture / research / assemble: FilmEra MCP, Browser Use MCP, video-use,
  jev-ultrafast, openjev
- Other env: Monid AI, MuAPI, Typesafe

## Process (per drop)
1. Read the drop's locked `script_final.md` + `script_shots.md`.
2. One prompt file per shot: `prompts/shot-NN_seedance2.md`.
3. One hero file: `prompts/hero_seedance25.md` covering the exact 10s window.
4. Run generation through the available Seedance / FilmEra / MuAPI path.
5. Assemble in the drop's `builds/`.
6. Master lands in the drop's `output/` with naming from `../CLAUDE.md`.
7. Log every render id and cost note in STATUS.md; advance the calendar board.

## Visual standards
- Prompt fidelity: every named element from the locked shot list must appear
- Do not swap Seedance 2.5 onto the full 30s
- Continuity: same character design, wardrobe, lighting across shots
- 9:16 first; 16:9 only if founder asks
- No burned-in fake ticker prices or fake TVL

## Good work
- 30s narrative complete with beginning / party peak / launch CTA
- 10s hero loops or stands alone as a quote-tweet clip
- Audio plan noted even if SFX are added later
- Failed takes stay in `builds/`; only masters in `output/`

## Files
- `briefs/ specs/ builds/ output/` — shared scratch/reference
- Per-drop renders live under `../calendar/drops/NNN_slug/`
