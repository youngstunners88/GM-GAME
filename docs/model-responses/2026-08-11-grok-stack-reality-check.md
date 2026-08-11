<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-stack-reality-check.md
     files inlined: 2
     tokens: 7931 in / 1784 out
     cost: $0.0266
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Category verdicts

| # | Category | Verdict | Why |
|---|----------|---------|-----|
| 1 | Secrets & Environment | **APPLIES** | CI holds `BUTLER_API_KEY`, `GITHUB_TOKEN`; gitleaks already runs; any secret in `config.json`/GDScript ships in the pck. |
| 2 | Dependencies & Supply Chain | **APPLIES** (partial) | Not npm-app deps — Godot editor/templates, butler binary, Actions, `web/web3.js`. Workflow already checksums Godot + butler. `npm audit` is theatre. |
| 3 | Auth, AuthZ & Sessions | **SKIP** | No routes, sessions, webhooks, user accounts. |
| 4 | Injection & Input Validation | **SKIP** (almost) | No SQL/Mongo/shell/uploads. Residual: any GDScript that builds strings from wallet/URL query input — narrow, not this category's checklist. |
| 5 | AI-Generated Code Specific Risks | **MANUAL** / partial | No Supabase/RLS/CORS/VITE_ keys. Real bits: no `eval` in bridge JS; no secrets under client-visible prefixes; human review of AI GDScript/`web3.js`. |
| 6 | API Hardening | **SKIP** | No app API. itch.io/GitHub Pages serve static files only. |
| 7 | Logging, Monitoring & Error Tracking | **SKIP** (prod) / **MANUAL** (CI) | No server to log/PII/audit. Optional client error sink is product choice, not baseline. |
| 8 | Data Handling & Legal Posture | **MANUAL** | No accounts/payments/cookies you set — but wallet connect + public game still imply ToS/privacy/license posture (esp. if branding/NFT/crypto copy). |
| 9 | Infrastructure & Deployment | **APPLIES** (partial) | HTTPS is itch/GitHub's job; no DB/backups/`NODE_ENV`. Real: CI secrets manager, pinned deploy tools, branch protections on the push-back-to-repo workflow. |
| 10 | Platform Privilege & Control-Plane Abuse | **SKIP** | Browser WASM canvas + `window.ethereum` user-mediated signatures. No ADB, accessibility, device-admin, remote shell. Inspecting release artifact for dev leftovers is the only echo — belongs under supply-chain/release hygiene. |

**Theatre if scored as written:** npm audit, lockfiles, RLS, rate limits, bearer-on-writes, session auth, DB backups, GDPR delete flows, HSTS you set, Wireless ADB.

---

## 2. Real risks the checklist does not cover

1. **`BUTLER_API_KEY` + `contents: write` CI = full ship pipeline compromise**  
   Stolen repo secrets or a malicious PR workflow path → push arbitrary `web/game/*` to itch and force-push `gh-pages`. Players get a trojanized WASM/JS bundle on trusted URLs. Checklist talks platform secrets generically; not “game update channel = code execution for every player.”

2. **Hostile or broken `web3.js` / `index.html` bridge (supply chain of the only privileged client surface)**  
   Bridge is injected into head, talks `window.ethereum`. Any XSS in hosted origin, malicious script tag swap in CI, or unchecked edit to `web/web3.js` → malicious `eth_sign`/`personal_sign`/typed-data prompts, drain-via-phishing, or endless signature spam. No key handling ≠ no wallet risk.

3. **Static bundle integrity on third-party hosts (itch.io + Cloudflare/Pages mirror)**  
   You don’t control itch’s CDN edge, cache purge, or account takeover. Account takeover on itch or GitHub Pages DNS/Cloudflare beats every green checklist item. No release signing/transparency for `index.wasm`/`index.pck` that players can verify.

4. **`config.json` force-included in pck — contract addresses / backend URLs are attacker-movable if build is movable**  
   Export preset embeds `config.json`. If an attacker ships a build (via CI or host), they point the game at malicious contracts/RPC while UI still looks like Lil Blunt. Checklist “no NEXT_PUBLIC secrets” misses “public config is an attack steering wheel.”

5. **GDScript/PCK is reverse-engineerable; any “security” in game logic is honor-system**  
   Client-side scores, gates, NFT checks, claim eligibility — fully forgeable. Checklist assumes server re-verify; you have no server. Designing as if the client is honest is the bug.

6. **Workflow commits build artifacts back to the branch with write token**  
   Expands blast radius: poisoned `web/game/` lands in git history, mirrors, and manual zip artifacts. Reviewers may treat committed WASM as trusted noise.

7. **SharedArrayBuffer/thread footgun is product/security-adjacent**  
   You correctly force `thread_support=false`. A “helpful” preset change re-enables threads → broken boot or pressure to add COOP/COEP headers itch won’t give you — availability + future CSP/header fantasies. Not in the 10 categories.

*(If only five: 1–5 are the core; 6–7 are close seconds.)*

---

## 3. Re-audit triggers (SKIP → APPLY)

| SKIP category | Applies again when… |
|---------------|----------------------|
| **3 Auth** | Any backend, save sync, gated content, admin route, or signed session — even a single Cloudflare Worker. |
| **4 Injection** | Leaderboard, chat, name input stored/reflected, replay upload, or any server query/command/path from client strings. |
| **6 API hardening** | You expose any HTTP API (claims, inventory, mint relay, score submit). |
| **7 Logging/monitoring** | You collect accounts, payments, or operate a server where auth failures/outbound traffic mean something. |
| **10 Privilege/control-plane** | Native export (Android/iOS/desktop) with plugins, overlays, updaters, debug deep links, or remote assist. |

**Partial categories expand when:**
- **5** — Supabase/Firebase/any BaaS, LLM features, or bundler env prefixes.
- **8** — Email list, analytics cookies, payments, real personal data.
- **9** — Own origin/server/DB instead of only itch static hosting.

---

## 4. Ranked by exploitability *here*

1. **CI/deploy secret abuse → malicious itch/Pages bundle** (steal wallets via fake prompts / full game replace)  
2. **`web3.js` / HTML shell tampering or host XSS → malicious signing UX**  
3. **itch.io or GitHub/Cloudflare account takeover** (same end state as 1, outside checklist)  
4. **Poisoned `config.json` in a shipped build → wrong contracts/RPC**  
5. **Trusting client-side game logic for anything economic or exclusive**  
6. **Artifact-in-git + wide `contents:write` making build poisoning easier to land and persist**  
7. **Secret leakage in repo/history/`config.json`/GDScript** (gitleaks-relevant; lower if truly no secrets)  
8. **Unpinned/unverified toolchain regression** (Godot/butler download path — partially mitigated)  
9. **Legal/ToS gaps around wallet connect** (lawsuit/process risk, not remote code exec)  
10. **Thread/COOP preset mistake** (DoS/boot fail, not theft)

**Bottom line:** Run a short checklist: secret scan, pin+verify CI tools, protect deploy keys/environments, treat `web3.js`+`index.html`+`config.json` as the TCB, assume PCK is public and forgeable, and plan itch/GitHub account recovery. Scoring the SaaS 10-by-10 will greenwash the actual kill chain.