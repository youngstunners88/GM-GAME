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

> **⚠️ ARCHITECTURE CHANGED — 2026-07-18 (Layer Shift).** The trigger condition
> above has now fired. The Layer-Shift work added: (1) a **backend proxy**
> (`backend/worker.js`, Cloudflare Worker), (2) an **on-chain-identity
> leaderboard**, (3) **community lore submission**, (4) **anonymous funnel
> telemetry**, and (5) **real wallet integration** (connect / `balanceOf` /
> `mint`). Several Section-A/C/D items that were N/A "because the architecture
> has no surface" now have surface. They are re-audited in the new
> **Section F — Layer Shift** below, and the affected items point there.
> Everything is code-complete but **the backend is not deployed and no
> contracts are set** (`backend_base_url` + `contracts.*` empty in
> `config.json`), so the live surface is currently zero — but the controls are
> documented now so they gate the moment you deploy.

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
| D3 | Leaderboard/economy rate-limited | **RE-OPENED → Section F (F2/F7)** | A real on-chain-identity leaderboard now exists (Layer Shift). Rate-limiting is a live P0 on backend deploy; data model is re-audited in F7. |
| D4 | Anti-cheat / replay defense | **N/A** | No competitive surface a replay attack could exploit |
| D5 | Public game assets are integrity-checked | **Check every audit** | Assets ARE fetched by URL (the .pck/.wasm/.js bundle). Godot's .pck is not individually hash-pinned per-file, but the whole bundle is versioned by git-sha (`--userversion` in butler push) and served over HTTPS from itch.io/Vercel's CDN — verify this versioning is intact, not that per-asset hashing exists (that's SaaS-CDN-specific and doesn't fit Godot's export model) |
| D6 | Social surface moderation (chat, usernames) | **N/A** | No chat, no usernames, no friend requests |
| D7 | Payments server-validated | **N/A** | No payments |
| D8 | Server-side matchmaking | **N/A** | No multiplayer |
| D9 | Signed update mechanism | **N/A** | Updates ship via itch.io/butler and Vercel, both of which serve over HTTPS with the host's own integrity; there is no separate unsigned update channel |
| D10 | Telemetry respects consent | **RE-OPENED → Section F (F8)** | Anonymous funnel telemetry (`/track`) was added (Layer Shift). Re-audited in F8: event-name-only, no PII, no persistent ID; confirm the page privacy note before backend deploy. |

### D-custom: items specific to THIS game, not in the original checklist

| ID | Item | Status | Check |
|----|------|--------|-------|
| D-C1 | Wallet/crypto UI never implies real functionality | **SUPERSEDED → Section F (F4), 2026-07-18** | The 2026-07-12 "resolved by removal" state no longer holds: Layer Shift reintroduced wallet UI, but as **real, user-signed** integration (not a demo). The trust concern is now resolved by honesty of behavior — actions are genuinely user-authorized on-chain and never gate core play — rather than by removal. Full re-audit in F4. The old `web3_manager.gd` demo file remains absent; the new seam is `web3_bridge.gd`. |
| D-C2 | No real wallet/contract addresses hardcoded | **Check every audit** | `grep -rEn "0x[a-fA-F0-9]{40}"` across `src/` — any hit must be investigated (CLAUDE.md Global Rules already forbid this) |
| D-C5 | No raw private-key-shaped hex literals in tracked source | **Check every audit** — added 2026-07-12 | D-C2's regex only matches **40-hex-char addresses**. The two real Ethereum private keys that leaked into this repo's git history (see audit-log.md incident) were **64-hex-char private keys** — a shape D-C2 never checked. `scripts/security-sentinel.sh` SEC-005 scans for `[a-fA-F0-9]{64}` across all tracked source, excluding known-safe checksum files (Godot/butler SHA256 pins). This is a working-tree scan, not a history scan — gitleaks covers history. |
| D-C3 | Web export stays non-threaded | **Check every audit** | `grep "thread_support" .github/workflows/export-game.yml` must show `false` — this is the fix for the "game sometimes doesn't play" root cause; regressing it silently breaks itch.io/iframe/mobile boot |
| D-C4 | postMessage handlers enforce same-origin | **Check every audit** | `grep -n "postMessage\|e.origin" web/launcher.js src/autoload/combo_system.gd` |

---

## SECTION F — Layer Shift: backend proxy + wallet + leaderboard (added 2026-07-18)

The Layer-Shift features (see `LAYER_SHIFT.md`) added real chain/backend surface.
This section re-audits the Section-A/C/D items that flipped from N/A, plus new
Layer-Shift-specific controls. **Live status:** all code-complete; live surface
is zero until `config.json` (`backend_base_url`, `contracts.*`) is filled and the
backend is deployed. Each item below marks whether it gates **now** or **on
deploy**.

| ID | Item | Status | Note |
|----|------|--------|------|
| F1 | **API key never reaches the client** | **Check every audit (now)** | `MISTRAL_API_KEY` lives ONLY in the backend (`backend/worker.js` reads `env.MISTRAL_API_KEY`). The client calls `{backend_base_url}/oracle`, never Mistral directly. Verify no key/secret string appears in `src/`, `web/`, or `config.json` (sentinel SEC-001/SEC-004 cover this). The proxy pattern is the whole point — regressing it (client calling Mistral with an embedded key) is a critical leak. |
| F2 | **Backend abuse rate-limiting** (flips A9/C1/C2) | **✅ IMPLEMENTED (2026-07-18, PR #5 review)** | Per-IP fixed-window KV counters in `worker.js` on every mutating path: `/oracle` 10/min (spends Mistral credits), `/lore` 10/min, `/score` 30/min, `/track` 60/min; over-limit → 429. Best-effort (KV eventual consistency) — a Cloudflare WAF rate rule can be layered on top for hard guarantees. `/lore` also length-capped ≤200 chars client + server. |
| F3 | **CORS scope** | **✅ IMPLEMENTED — one env var at deploy** | `worker.js` CORS is env-driven: defaults to `*` for local dev; set `ALLOWED_ORIGIN` (comma-separated origins) in `wrangler.toml` `[vars]` before production and only allow-listed origins are echoed. Deploy step documented in `backend/README.md`. |
| F2b | **Leaderboard scores are unauthenticated (explicit trust model)** | **Accepted risk, documented** | `/score` accepts client-supplied score+wallet with no signature — an untrusted, best-effort arcade board by design (gas-free, no signup); the wallet is a pseudonymous label, not verified identity. Rate-limited (F2) against flooding. If the board ever needs to be trustworthy (prizes, rewards), gate submissions behind a wallet signature (SIWE) — noted at the handler in `worker.js`. |
| F4 | **Wallet actions are user-signed, never auto-charged** (revises D-C1) | **Check every audit (now)** | Wallet UI is back, but it is **real, not fake**: `connect`/`balanceOf` are read-only; `mint` is a user-signed `eth_sendTransaction` the player confirms in their own extension. Nothing spends funds without an explicit wallet confirmation, and every path degrades gracefully (no wallet → the game plays on). This resolves the original D-C1 trust concern differently than "removal": the UX is honest because the actions are genuinely user-authorized on-chain, and none are gated in front of core play. |
| F5 | **No real addresses hardcoded** (reaffirms D-C2) | **Check every audit (now)** | All contract/chain wiring is in `config.json`, loaded at runtime by `Web3Bridge`; `src/` contains zero 40-hex address literals (sentinel SEC-004). |
| F6 | **eval injection surface** (new) | **Check every audit (now)** | Wallet/contract addresses interpolated into `JavaScriptBridge.eval` are sanitized by `web3_bridge.gd::_hex()` (strict `^0x[0-9a-fA-F]+$`) — a validated hex string carries no quotes/JS. Enforced by sentinel **INJ-003** (updated 2026-07-18 to check the `_hex()`/postMessage invariant instead of the old postMessage-only heuristic). |
| F7 | **Leaderboard data = pseudonymous wallet, no PII** (revises D3/C4) | **Check every audit (now)** | The leaderboard stores `{wallet_address, score, level, timestamp}` in backend KV. A wallet address is pseudonymous, not PII in the classic sense, and it's already public on-chain; no emails/names are collected. Scores are off-chain (KV) by design — the gas tradeoff is documented in `backend/README.md` and `LAYER_SHIFT.md` (V2). If real PII is ever added (e.g. a display name), C4/D6 re-open. |
| F8 | **Funnel telemetry consent** (revises D10) | **Review before deploy** | `/track` sends anonymous button-click events (event name only, no PII, no persistent ID). This is minimal, anonymous product analytics rather than user tracking. Before the backend deploys, confirm the itch.io page privacy note mentions anonymous gameplay analytics; keep events PII-free. |

---

## SECTION G — AgentMail marketing engine: email PII (added 2026-07-19)

The AgentMail integration (`backend/agentmail.js`, `marketing.js`,
`email_templates.js`; see `AGENTMAIL_SETUP.md`) makes the backend store **real
PII for the first time: player email addresses**. That re-opens C4/C5/D10-class
items. Live surface remains gated on deployment + AgentMail env being set.

| ID | Item | Status | Note |
|----|------|--------|------|
| G1 | **Consent before capture + double opt-in** | **Check every audit (now)** | Signup requires `consent === true` server-side (400 without it); checkbox unticked by default; panel optional + skippable forever. **Double opt-in (PR #6):** a spoofed signup POST can trigger at most ONE email (Welcome 1, which carries the confirm link); all campaign mail (digest, welcome 2/3, milestones) requires `confirmed`, set only by the emailed `/confirm` link. Abuse quotas: signup 5/hr/IP + 1/address/day; referral 3/hr/IP + 3/day/player + one invite per address ever; events 120/min/IP. |
| G2 | **One-click unsubscribe honored end-to-end** | **Check every audit (now)** | `/unsubscribe?token=` flips consent off, adds the address to local suppression, AND pushes it to AgentMail's send block list. `sendEmail()` refuses suppressed recipients — suppression is enforced at the send seam, not just at campaign selection. |
| G3 | **PII minimization** (re-opens C4) | **Accepted risk, documented** | Stored per player: email, optional display name (≤40 chars), optional wallet, timestamps, welcome stage. No passwords, no payment data, no addresses. KV is Cloudflare-encrypted at rest; no column-level crypto exists on KV — acceptable for a marketing list, revisit if anything more sensitive is ever stored. |
| G4 | **Email keys server-side only** (extends F1) | **Check every audit (now)** | `AGENTMAIL_API_KEY`, `WEBHOOK_SECRET`, `XAI_API_KEY` are wrangler secrets read from `env`; nothing email-related ships in the client bundle (the game only calls `/email/signup`, `/referral`, `/events`). |
| G5 | **Support webhook authenticated + replay-safe** | **Check every audit (now)** | `/agentmail/webhook` 401s without the `WEBHOOK_SECRET` query param; when `AGENTMAIL_WEBHOOK_SIGNING_KEY` is set (do set it), the svix-style HMAC signature over `<id>.<timestamp>.<body>` is verified with a ±5 min staleness window; every event/message id is deduplicated via a 24 h KV gate before triage — a replayed webhook cannot re-trigger LLM spend or a second outbound reply. |
| G6 | **Open-redirect guard on the click tracker** | **Check every audit (now)** | `/go?to=` redirects only to EXACT https hosts (youngstunners88.itch.io, itch.io, twitter.com, x.com, basescan.org, t.me, own backend host) plus `*.itch.io` (the game's own CDN); anything else — including http: — falls back to the game URL. Tightened from registrable-domain suffix matching per PR #6 review. |
| G7 | **Send-rate + duplicate protection** | **Check every audit (now)** | Idempotency-Key on every send (deterministic per logical email), max 1 email/player/day (welcome exempt by design), 429 exponential backoff. Cron re-runs cannot double-send. |
| G8 | **Outbound email content** | **Check every audit (now)** | All template interpolations are HTML-escaped (`esc()`), user-supplied text never lands in HTML raw; support replies are LLM plain text wrapped by our template. CAN-SPAM footer (identity + reason + unsubscribe) on every template including referrals to non-subscribers. |
| G9 | **LLM support triage safety** | **Check every audit (now)** | Incoming email text (attacker-controlled) is prompt input to Mistral/Grok. Auto-send requires ALL of (PR #6 hardening): category `question` (bug/feature/other always human-review), confidence ≥ 0.7, AND content checks on the answer — ≤1200 chars, zero links other than the game's own URL, zero email addresses. Reply goes ONLY to the original sender; labels are fixed strings; no tool use in the triage call; per-message decision is durable via the webhook dedup gate. Residual risk: a prompt-injected but link-free, address-free wrong answer to the asker themselves — bounded blast radius. |

---

## SECTION H — Level-depth analytics pipeline (added 2026-07-19, task #23)

Granular gameplay telemetry now exists (`/event`, `/player-analytics`,
`/community-lore`, `/hall-of-blaze` — see `LEVEL_DEPTH.md`). Delta-audit on
top of Sections F/G:

| ID | Item | Status | Note |
|----|------|--------|------|
| H1 | **Telemetry stays pseudonymous** | **Check every audit (now)** | Events carry only the client-generated random player id + fixed-vocabulary event types (server-side allowlist rejects unknown types); payload fields are length/range-clamped; `pstats` has a 90-day TTL. No email/wallet joins happen in the analytics path. |
| H2 | **New routes rate-limited** | **Check every audit (now)** | `/event` 120/min/IP, `/player-analytics` + `/community-lore` + `/hall-of-blaze` 30/min/IP — same `overLimit` KV pattern as Section F/G routes. |
| H3 | **Adaptive difficulty can't be weaponized** | **Accepted risk, documented** | A player could spoof `/event` deaths to make their own level easier (self-serving only — tuning is per-player-id and only ever REDUCES difficulty within fixed bounds: −15% patrol, a warning puff, a checkpoint, a hint). No leaderboard or economy value derives from tuning, so there's nothing to gain beyond a gentler solo run. |
| H4 | **Kimi/OpenRouter key server-side only** (extends F1/G4) | **Check every audit (now)** | `OPENROUTER_API_KEY` is a Worker secret read from `env` (`kimi_client.js`); the weekly realm-news blurb is 1 cached call/week; blurb output is length-capped and angle-bracket-stripped before templating (G8 escaping still applies downstream). |

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

**This is now automated.** Every item below (A1, A4, A8, D5, D-C1–D-C5, plus
several new checks this hand-written block never covered) runs in one command:

```bash
./scripts/security-sentinel.sh
```

See `.claude/skills/game-security-sentinel/SKILL.md` for when this runs
autonomously (every release, every CI push, and mid-session whenever the
agent touches security-relevant surface — no invocation needed) and
`scripts/security-sentinel.sh` for the check implementations themselves.

The manual commands below are kept for ad-hoc spot-checks / debugging the
script itself, not as the primary audit path:

```bash
# A7 — headers on the live mirror (itch.io sets its own; this checks Vercel)
curl -sI https://lil-blunt-game.vercel.app/ | grep -iE "strict-transport|x-frame|content-security|x-content-type|referrer-policy"

# D5 — build is versioned (not a mutable unversioned blob)
grep -n "userversion" scripts/deploy_itch.sh .github/workflows/export-game.yml
```

## Result table format

Every audit run appends a dated entry to `docs/security/audit-log.md` using:

| ID | Status | Evidence |
|----|--------|----------|
| A1 | PASS/FAIL | ... |
