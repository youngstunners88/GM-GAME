# Project status — health, blockers, open items

> One home per fact: the client-facing living report is **`STATUS.md`**
> (detail, changelog, evidence). This file is the thin health map + blocker
> board. Per-track detail: each track's `01-current-state.md`.

## Health (2026-07-19)

| Track | State | Evidence |
|---|---|---|
| godot-client | 🟢 Shipping — L1 depth verified 5/5 strict gates (PLAYING reached) | `game-verify-level.png`, CI green |
| backend | 🟡 Code-complete, NOT deployed | all endpoints built + rate-limited; needs `wrangler deploy` + secrets |
| marketing | 🟡 Engine built, dormant until backend + AgentMail DNS | `AGENTMAIL_SETUP.md` is copy-paste ready |
| docs | 🟢 Current | layer maps + setup guides shipped with each feature |

## Blockers (client-input, in order of unlock value)

1. ~~Valid Mistral key~~ → **UNBLOCKED 2026-07-19**: two valid keys in env
   (`MINSTRAL_API_KEY`, `MINSTRAL_API_KEY2`, both HTTP 200). Deploy step:
   `wrangler secret put MISTRAL_API_KEY` (paste key 1) and
   `wrangler secret put MISTRAL_API_KEY2` (key 2, failover tier).
2. **Backend deploy** (~5 min): `backend/README.md` → gives Oracle,
   leaderboard, lore, analytics, difficulty their server.
3. **AgentMail key + smokering.game DNS** (~20 min): `AGENTMAIL_SETUP.md`
   → email engine goes live.
4. **Contract addresses** in `config.json` (badge ERC-721 + 3 ERC-20s)
   → badge mint, token perks, boss spectacle activate. See `DEFI_REVIEW.md`
   manual checks BEFORE filling these.
5. **itch.io Publish click** (~10 s): page is uploaded, sitting in Draft.

## Standing gates (never skip)

gitleaks → `security-sentinel.sh` (18 checks) → Godot export →
web3.js bundle gate → `security-audit.ts` (adapted 33-check gate) → browser
verify (strict PLAYING) → butler. Checklist:
`docs/security/GAME_SECURITY_CHECKLIST.md` (Sections A–H).

## Recently landed

Layer Shift (PR #5) → AgentMail engine (PR #6) → L1 Level Depth + Kimi K3
(PR #7) → ICM restructure + security-audit CI gate + L2/L3 depth (this batch).
