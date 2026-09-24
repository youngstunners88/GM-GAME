---
name: gm-game-jev-gauntlet
description: Run the Jev ship/block gauntlet for portal work — evidence packs, Playwright captures, decisions API calls, and the legality rules for votes. TRIGGER before declaring any portal/ladder/room/NFT task done or shipping to master.
---

# Jev Gauntlet

## 0. Model & endpoint (from the founder spec — do not improvise)
- Model: `~typesafe/jev-latest`
- POST https://openrouter.ai/api/alpha/decisions
- NEVER chat/completions. Jev VOTES — it does not paint and does not write GDScript.

## 1. Gates
- `ladder_unmissable` — glow readable at gameplay zoom
- `room_has_dividing_line` — no sellotape seam in study plates
- `nft_matches_protocol` — still shows the right logo family
- `ship` — ship or block

Legality: FIXED is illegal if ship == block OR any defect score >= 0.6.

## 2. Evidence pack (assembled before every vote)
- Playwright capture of each ladder AT GAMEPLAY ZOOM
- Playwright capture of each study room (plates + dividing line)
- 3 NFT orbit stills
- Pre-grade the pack with the workhorse lane (`deepseek/deepseek-v4.1-flash`,
  native vision) and attach its notes — Jev decides, cheap models describe.

## 3. Session discipline
- NEVER route Jev's lane to a chat model, no matter what fails.
- Record every vote + evidence paths in `portals/90_gates/` and a line in
  STATUS.md. A vote that isn't recorded didn't happen.
- Block = task stays OPEN, fix and re-run. No override, no "ship anyway".
