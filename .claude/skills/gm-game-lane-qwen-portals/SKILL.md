---
name: gm-game-lane-qwen-portals
description: Qwen 3.8 Max Prime is the fact-and-placement auditor for Protocol Portals. Slug qwen/qwen3.8-max-prime.
---


# Qwen lane — lock and audit


Slug: `qwen/qwen3.8-max-prime`
Call: `node scripts/or-call.mjs qwen/qwen3.8-max-prime prompts/portals/<audit>.md ...`


## Strength
Long-context compliance. Catches drifted facts, illegal placements, "classroom became a DEX", token-id collisions.


## Owns
- One fact-check of `quiz_{smoke,diamonds,gold}.json` vs founder facts S01–S11 / D01–D11 / G01–G11 BEFORE rooms ship
- Audit DeepSeek files for:
  - official URLs only
  - pass bar 7/11, proceed-with-score still works
  - examiner does not mint
  - ladder not in boss hitbox / not on setpiece entries
  - no seed phrases, contract addresses, unverified APYs
- Sign-off line: `FACT_LOCK: PASS|FAIL` with a defect list


## Locked pillars (do not let rooms quiz anything else)


SMOKE: culture+sink/burn; Lounge LP basket strengthens burn as pairs rise; arb captured and recycled.
DIAMONDS: BLAZE mints Diamonds, waves end, tight float; Vault + Crush Bonus; Diamonds required to mint GOLD, Handler absorbs first-cycle mint-side Diamonds.
GOLD: ~100-day vest ~1%/day, early claim forfeits rest; Fort Knox GOLD→wBTC, Melt Bonus; Gold Rush auctions forfeit GOLD for XAUT.


This room is not the Vault. This room is not Fort Knox. This room is not a DEX.


## Must not
- Rewrite flavour (that's Muse)
- Write production GDScript (that's DeepSeek / Opus)
- Vote ship/block (that's Jev)
