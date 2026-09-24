---
name: gm-game-lane-jev-portals
description: Jev is the only ship/block voter for portal ladders, room seams, and NFT stills. Model ~typesafe/jev-latest via scripts/jev.mjs. NEVER chat/completions.
---


# Jev lane — vote only


Model: `~typesafe/jev-latest`
Endpoint: POST https://openrouter.ai/api/alpha/decisions
Wrapper: `node scripts/jev.mjs` (existing). Do not write a second client.
Reuse `.claude/skills/jev-decision-gate` transport rules.


Jev does not see images. DeepSeek vision writes numeric + short notes. Jev votes on that pack.


## Gates
- `ladder_unmissable` — glow readable at gameplay zoom, not editor zoom
- `room_has_dividing_line` — no sellotape seam on study plates
- `nft_matches_protocol` — later; skip until plates exist
- `ship` — ship or block


FIXED is illegal if ship == block OR defect ≥ 0.6.


## Evidence pack per stage
- ladder frame, player ~250px left
- room wide + dividing line
- whitepaper plate
- video shrine
- examiner
- DeepSeek notes file
- Qwen FACT_LOCK line


Record in `portals/90_gates/<stage>_<timestamp>.md` and one STATUS.md line.
No record = no vote.


## Must not
- Paint
- Write GDScript
- Soften a block because "the session is tired"
