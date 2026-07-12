# Lil Blunt Adventure — Security Checklist (adapted)

Source: a general "vibe-coded SaaS app" checklist (Patrick Minardi's 3-reel
framework — RLS, auth providers, webhooks, payments, multiplayer anti-cheat).
This document is **that checklist rewritten against this game's actual
architecture**, not a copy-paste of the original.

## Why most of the original doesn't apply

Lil Blunt Adventure is a **single-player, client-only Godot 4.3 game exported
to WebAssembly and served as static files** (itch.io primary, Vercel/Netlify
mirror). There is:
- No backend server, no API, no database → RLS, webhooks, connection
  pooling, and query auth are **structurally not applicable**.
- No user accounts, no login, no password reset → auth-provider and
  credential-abuse items are **not applicable**.
- No payments → Stripe/webhook entitlement checks are **not applicable**.
- No multiplayer, leaderboard, chat, or matchmaking → server-authoritative
  anti-cheat and social-surface moderation are **not applicable**.

Marking an item N/A here is a judgment call, not an omission — the
justification is stated per item so it can be challenged if the architecture
changes (e.g. if a real leaderboard or wallet integration ever ships, the N/A
items in Section D become live P0s and must be re-audited).

Items retain their original IDs for traceability back to the source reels.

---

## SECTION A — Bundle, CI, hosting, headers (the parts that DO apply)

| ID | Item | Status | Applies because |
|----|------|--------|------------------|
| A1 | No secrets/source maps in shipped bundle | **Check every audit** | The web export is a public static bundle; anyone can view-source it |
| A2 | RLS on every user-data table | **N/A** | No database |
| A3 | Real auth provider, session/refresh | **N/A** | No accounts. `Web3Manager` is explicit DEMO MODE (see D-custom below) |
| A4 | Version control + safe deploys (PR review, CI, no direct-to-prod) | **Check every audit** | Applies to any repo |
| A5 | Typed API contracts | **N/A** | No API |
| A6 | Signed webhooks, idempotency | **N/A** | No webhooks |
| A7 | Hosting: HTTPS, CDN, logs | **Check every audit** | itch.io + Vercel both serve HTTPS/CDN by default; verify it's actually wired |
| A8 | Security headers + secrets in env not code | **Check every audit** | Applies to the static bundle and its host config |
| A9 | Rate limits on abuse surfaces | **N/A** | No signup/login/contact-form endpoints exist in a static client-only game |
| A10 | Caching on hot paths | **N/A (host default)** | Static assets — itch.io/Vercel CDN caching is the whole cache layer; no app-level cache to audit |
| A11 | Scaling: stateless, pooled DB, queues | **N/A** | No server process to scale |
| A12 | Error tracking (Sentry etc.) | **Accepted risk, not FAIL** | See note below |

**A12 note:** a crash-reporting SDK would need to phone home from every
player's browser, which is a privacy/consent surface this game doesn't
currently need (see D10). The `/browser-verify-game` gate + manual QA cover
pre-release crash detection instead. Revisit if player-reported crashes
become frequent enough that pre-release testing isn't catching them.

---

## SECTION B — Abuse surfaces (signup/contact/password-reset)

**All of B1–B3: N/A.** There is no signup form, no contact form, no
password-reset flow anywhere in this game. If a future feature adds any of
these (e.g. a real newsletter signup on the itch.io page, a feedback form),
re-run this section against that specific feature before shipping it.

---

## SECTION C — Defensive-stack omissions

| ID | Item | Status | Note |
|----|------|--------|------|
| C1 | Edge-validated X-Forwarded-For | **N/A** | No origin server doing IP-based rate limiting |
| C2 | Per-actor rate-limit keys | **N/A** | No rate limiting exists (nothing to key) |
| C3 | RLS policy tests | **N/A** | No RLS |
| C4 | Column-level encryption for PII at rest | **N/A** | No database, no PII collected or stored server-side |
| C5 | GDPR intake not a spam pipeline | **N/A** | No GDPR intake form. If one is added (e.g. a support email on the itch.io page), it's just a mailto: link, not a public POST endpoint — re-audit if that changes |
| C6 | Audit log for privileged actions | **N/A** | No privileged actions (no accounts, no roles) |
| C7 | Backups exist and are restorable | **N/A** | No database. The *equivalent* control is: the game itself is 100% reproducible from `git` (source) + CI (build) — verify `git log` has no force-pushed history gaps and CI can rebuild from any commit |

---

## SECTION D — Game-specific (adapted to single-player reality)

| ID | Item | Status | Note |
|----|------|--------|------|
| D1 | Server-authoritative state | **N/A by design** | Single-player, no server. A player editing their own local `save.json` only affects their own save — same threat model as a Mario save-state editor. Not a security bug. |
| D2 | Client events validated server-side | **N/A** | No server to validate against |
| D3 | Leaderboard/economy rate-limited | **N/A** | No leaderboard, no real-money economy (GOLD/wBTC/Diamonds are in-game-only, not tradeable, not real crypto — see Global Rules in CLAUDE.md: never hardcode real wallet/contract addresses) |
| D4 | Anti-cheat / replay defense | **N/A** | No competitive surface a replay attack could exploit |
| D5 | Public game assets are integrity-checked | **Check every audit** | Assets ARE fetched by URL (the .pck/.wasm/.js bundle). Godot's .pck is not individually hash-pinned per-file, but the whole bundle is versioned by git-sha (`--userversion` in butler push) and served over HTTPS from itch.io/Vercel's CDN — verify this versioning is intact, not that per-asset hashing exists (that's SaaS-CDN-specific and doesn't fit Godot's export model) |
| D6 | Social surface moderation (chat, usernames) | **N/A** | No chat, no usernames, no friend requests |
| D7 | Payments server-validated | **N/A** | No payments |
| D8 | Server-side matchmaking | **N/A** | No multiplayer |
| D9 | Signed update mechanism | **N/A** | Updates ship via itch.io/butler and Vercel, both of which serve over HTTPS with the host's own integrity; there is no separate unsigned update channel |
| D10 | Telemetry respects consent | **Check every audit** | No telemetry currently ships. If any analytics is ever added, this becomes a live P0 — audit for opt-in gating before it ships, not after |

### D-custom: items specific to THIS game, not in the original checklist

| ID | Item | Status | Check |
|----|------|--------|-------|
| D-C1 | Wallet/crypto UI never implies real functionality | **Check every audit** | `grep -rn "DEMO" src/autoload/web3_manager.gd src/ui/main_menu.gd` — both must say DEMO explicitly. This is a real-brand trust risk: SmokeRing/DIAMONDS/GoldMine are live crypto projects, and a fake "wallet connected / TX submitted" UI reads as a real transaction to a confused player. |
| D-C2 | No real wallet/contract addresses hardcoded | **Check every audit** | `grep -rEn "0x[a-fA-F0-9]{40}"` across `src/` — any hit must be investigated (CLAUDE.md Global Rules already forbid this) |
| D-C3 | Web export stays non-threaded | **Check every audit** | `grep "thread_support" .github/workflows/export-game.yml` must show `false` — this is the fix for the "game sometimes doesn't play" root cause; regressing it silently breaks itch.io/iframe/mobile boot |
| D-C4 | postMessage handlers enforce same-origin | **Check every audit** | `grep -n "postMessage\|e.origin" web/launcher.js src/autoload/combo_system.gd` |

---

## SECTION E — Process (human-only, still worth stating)

| ID | Item | Status |
|----|------|--------|
| E1 | Threat model written down | **This document IS the threat model** — see the "why most doesn't apply" section above |
| E2 | Security-touching prompts specify the actual control | Applied going forward: prompts that touch web3_manager, headers, or CI must name the specific control, not just "add security" |
| E3 | CI fails build on secret leak | **Gap — being fixed** (see CI diff) |
| E4 | Vibe-check before public deploy | Automated equivalent: `/browser-verify-game` + this checklist's quick pass, run by `/release-game` before every ship |
| E5 | No "the app is under attack, fix it" blind-prompt pattern | This game has no server to attack in the traditional sense (no login, no DB) — the closest analog is a client-side exploit report (e.g. a cheat-save-editor complaint), which is explicitly **not a security incident** per D1 |

---

## Quick-audit command block

Run every item marked "Check every audit" with one pass:

```bash
# A1 — no source maps, no secrets in the shipped bundle
find web/game -name "*.map" 2>/dev/null
grep -rE "(sk_live|sk_test|AKIA|pk_live)" web/game src scripts 2>/dev/null

# A4 — CI exists with real gates
test -f .github/workflows/export-game.yml && echo "CI: present"

# A7/A8 — headers on the live mirror (itch.io sets its own; this checks Vercel)
curl -sI https://lil-blunt-game.vercel.app/ | grep -iE "strict-transport|x-frame|content-security|x-content-type|referrer-policy"

# A8 — .env never committed
grep -n "^\.env" .gitignore

# D5 — build is versioned (not a mutable unversioned blob)
grep -n "userversion" scripts/deploy_itch.sh .github/workflows/export-game.yml

# D-C1/D-C2/D-C3/D-C4 — game-specific
grep -n "DEMO" src/autoload/web3_manager.gd src/ui/main_menu.gd
grep -rEn "0x[a-fA-F0-9]{40}" src/ || echo "no hardcoded addresses"
grep -n "thread_support" .github/workflows/export-game.yml
grep -n "e.origin" web/launcher.js src/autoload/combo_system.gd
```

## Result table format

Every audit run appends a dated entry to `docs/security/audit-log.md` using:

| ID | Status | Evidence |
|----|--------|----------|
| A1 | PASS/FAIL | ... |
