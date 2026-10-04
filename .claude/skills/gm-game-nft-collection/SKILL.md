---
name: gm-game-nft-collection
description: "The six soulbound NFTs of Lil Blunt Adventure (per stage: one for defeating the boss, one for passing the protocol test), their ids, names, triggers, art and the single contract shared by the game, the ICP canister and smokegame.win. TRIGGER on any NFT, badge, scorecard, 'issue an NFT', boss reward or exam reward work, and before touching src/data/nft_collection.json, docs/nft/NFT_CONTRACT.md or src/autoload/nft_issuer.gd."
---

# What exists (founder, 2026-10-04: "each stage issues NFTs - one for defeating the boss, one for passing the test; 6 in total")
| id | Name | Trigger |
|---|---|---|
| boss_auditor | Tax Evader | Auditor dies (stage 1) |
| boss_distributor | Crystal Miner | Distributor dies (stage 2) |
| boss_claimjumper | Claim Jumper Slayer | Claim Jumper dies (stage 3) |
| test_smoke / test_diamonds / test_gold | SMOKE / DIAMONDS / GOLD Scholar | exam PASSED (>= 7 of 11) in that protocol room |

Never add, rename or re-purpose ids. A FAILED exam issues nothing. Soulbound, one per player, no multipliers, never gated on holdings.

# Single source of truth (change here first, then both sides)
- `docs/nft/NFT_CONTRACT.md` - ids, JSON, canister HTTP + Candid, identity, honesty rules.
- `src/data/nft_collection.json` - the game's copy (id, name, kind, stage, trigger, art, spoken line, blurb).
- Art: founder's Drive folder "NFTs" (originals in `design/nft/drive/`, 512px web copies in `src/assets/nft/*.webp`).
  Open point: the three TEST plates currently use his Blaze Rush artwork (the only stage-matched art he supplied); swap the
  `art` path in the json if he sends dedicated test art.
- Hooks (real events, not timers): `GameManager.mark_boss_defeated(key)` -> `NftIssuer.on_boss_defeated`; each boss `die()` calls it;
  `StudyRoom._finish_quiz` -> `NftIssuer.on_test_passed(protocol, score, total)` only when `session.passed`.

# Checks
`godot --headless res://tests/nft_issuer_test.tscn` (also in CI). Fails if ids drift, art/audio is missing, a trigger is unwired,
or a hostile save/reply can invent an NFT or a chain time.

# Related
`gm-game-nft-icp-issuance` (on-chain flow + Caffeine concord), `gm-game-nft-congrats` (card, jingle, voice).
