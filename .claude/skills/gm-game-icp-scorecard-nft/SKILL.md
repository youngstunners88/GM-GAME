---
name: gm-game-icp-scorecard-nft
description: Grant and mint 3D ICP scorecard NFTs for portal completions — soulbound tokens portal_smoke / portal_diamonds / portal_gold with metadata + GLB animation_url, integrated with the game's existing Proof-of-Play / Internet Identity layer. TRIGGER on ScorecardGrant, NFT mint, soulbound token, or portal scorecard work.
---

# ICP Scorecard NFTs

## 0. Rules
- Token ids: `portal_smoke`, `portal_diamonds`, `portal_gold`. Do NOT collide
  with the `s1_boss` / `s1_blaze_rush` family. Grep the repo for existing ids
  before adding any new one.
- Phase 1: SOULBOUND. One card per protocol per player.
- Art must include the official protocol logo + score plate (Jev gate
  `nft_matches_protocol`).
- Completion ALWAYS grants eligibility — even a failed quiz (proceeded_with_score).

## 1. Metadata schema
protocol, stage_id, score_correct, passed, study_path, minted_at,
2D image (the MuAPI front plate), GLB animation_url (Blender-cleaned mesh
from gm-game-media-pipeline, presented with Y-spin 0.4-0.7 rad/s in web
viewers only).

## 2. Integration
- The game already has Proof of Play on ICP with Internet Identity (no wallet,
  no seed phrase). ScorecardGrant must extend THAT layer — do not introduce a
  new wallet flow.
- PortalSession fields to persist: nft_token_id, pending_icp. Grant flow:
  ScorecardGrant marks eligibility -> mint request -> record token id back
  into the session.
- The website's leaderboard currently shows demo data while the live board is
  built — scorecard mints must not depend on the demo board being live.

## 3. Evidence before ship
Playwright captures 3 NFT ORBIT STILLS (one per protocol) -> Jev decisions
API vote (`nft_matches_protocol` + `ship`). No stills, no ship.
