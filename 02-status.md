# Project status — health, blockers, open items

> One home per fact: the client-facing living report is **`STATUS.md`**
> (detail, changelog, evidence). This file is the thin health map + blocker
> board. Per-track detail: each track's `01-current-state.md`.

## 🚀 DEPLOY SPRINT RESULT (2026-07-20) — the stack is LIVE

| Deliverable | State |
|---|---|
| Backend | ✅ **DEPLOYED** — https://lil-blunt-backend.teacherchris37.workers.dev · health/oracle/balances/signup/analytics all E2E-verified live · crons + support webhook registered |
| Socials | ✅ **LINKED** — @smokering25 + t.me/LilBluntdotWin everywhere incl. new FOLLOW ON X menu button (`docs/SOCIAL_LINKS.md`) |
| Onboarding | ✅ **LIVE** — NEW TO CRYPTO? screen (copy-review-polished), analytics events wired |
| Offline mode | ✅ **LIVE** — + dedicated blackhole-simulation gate (`scripts/verify-offline-sim.mjs`) |
| Budget | ✅ **DOCUMENTED** — `docs/OPERATIONS_BUDGET.md` |
| Content engine | ✅ **RUNNING** — 50 reviewed seed taglines packed into the build, X drafts + newsletter draft (AgentMail, needs_approval) |
| Email | ✅ **ACTIVE (Phase 1, @agentmail.to)** — welcome/digest/milestone/support flows armed; founder received live Welcome 1; Phase 2 = plan upgrade + smokering.game |
| Contracts | ✅ **VERIFIED + LIVE** — server-side multi-chain /balances (SMOKE=Base, DIAMONDS+GOLD=Ethereum) |
| Kimi K3 gate | ✅ **PASSED** — 90-file sweep + architecture + copy reviews; criticals fixed/disproven with evidence; trail in `KIMI_AUDIT_FEEDBACK.md` |

## Previous sprint (2026-07-19, evening)

| Deliverable | State |
|---|---|
| Backend | 🟡 **BLOCKED on 1 credential** — Cloudflare token has no account access; `./scripts/deploy-backend.sh` does everything else in one command (KV, secrets, vars, deploy, E2E). All keys validated: Mistral ×2, OpenRouter, AgentMail. |
| Socials | ✅ **LINKED** — @smokering25 + t.me/LilBluntdotWin wired in-game, emails, shares (`docs/SOCIAL_LINKS.md`) |
| Onboarding | ✅ **LIVE** in the build — "NEW TO CRYPTO?" menu screen, exact privacy copy, Learn More modal, viewed/clicked/dismissed analytics |
| Offline mode | ✅ **LIVE** in the build — banner, leaderboard cache, static-FAQ Oracle, wallet disable, analytics queue + silent reconnect sync |
| Budget | ✅ **DOCUMENTED** — `docs/OPERATIONS_BUDGET.md` (~$10–50/mo launch; $100 @10k, $400 @100k, $200 credit buffer) |
| Content engine | ✅ **RUNNING** — real Kimi K3 outputs on disk (taglines W29, X drafts) + a real newsletter draft in AgentMail awaiting approval |
| Email pipeline | ✅ **PROVEN** — `smokering-notifications@agentmail.to` created; test email delivered to the founder |
| Contracts | ✅ **VERIFIED + IN CONFIG** — SMOKE on Base, DIAMONDS+GOLD on Ethereum (cross-chain finding → new stateless `/balances` endpoint) |

## Health (2026-07-19)

| Track | State | Evidence |
|---|---|---|
| godot-client | 🟢 Shipping — L1 depth verified 5/5 strict gates (PLAYING reached) | `game-verify-level.png`, CI green |
| backend | 🟡 Code-complete, NOT deployed | all endpoints built + rate-limited; needs `wrangler deploy` + secrets |
| marketing | 🟡 Engine built, dormant until backend + AgentMail DNS | `AGENTMAIL_SETUP.md` is copy-paste ready |
| docs | 🟢 Current | layer maps + setup guides shipped with each feature |

## Blockers (client-input, in order of unlock value)

1. **Cloudflare account access (~1 min)** — set `CLOUDFLARE_ACCOUNT_ID` (or a
   token w/ Workers+KV edit perms), then `./scripts/deploy-backend.sh` does
   the rest. THIS IS THE ONLY THING between the game and a live Oracle/
   leaderboard/email/analytics stack.
2. **AgentMail plan upgrade** — free tier hit its inbox cap + allows no custom
   domains. Upgrade → support@ inbox + smokering.game DNS flow.
3. **Badge ERC-721** — still no contract; mint stays inert (token perks now
   have verified addresses and go live with the backend).
4. **DEFI_REVIEW M-DEFI-1 audit attestation** — reply with audit links (or
   written acceptance) for SMOKE/DIAMONDS/GOLD.
5. **itch.io Publish click** (~10 s): page is uploaded, sitting in Draft.

## Standing gates (never skip)

gitleaks → `security-sentinel.sh` (18 checks) → Godot export →
web3.js bundle gate → `security-audit.ts` (adapted 33-check gate) → browser
verify (strict PLAYING) → butler. Checklist:
`docs/security/GAME_SECURITY_CHECKLIST.md` (Sections A–H).

## Recently landed

Layer Shift (PR #5) → AgentMail engine (PR #6) → L1 Level Depth + Kimi K3
(PR #7) → ICM restructure + security-audit CI gate + L2/L3 depth (this batch).
