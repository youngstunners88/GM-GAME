# Security Audit Log

Each entry is one run of `docs/security/GAME_SECURITY_CHECKLIST.md`'s
quick-audit block. Newest first.

---

## 2026-07-12 — INCIDENT: real private keys in public git history (found by CI gitleaks)

The gitleaks gate added in the previous audit **did its job**: a full-history
scan (workflow_dispatch run 29191717114) failed with 33 findings. Triage:

- **~31 false positives** — every committed build of `web/game/index.wasm`
  contains the Godot engine's embedded PEM header string literals (crypto
  module). Fixed: `.gitleaks.toml` now allowlists `web/game/index.wasm|.pck`
  (build artifacts only; all source paths stay scanned).
- **2 TRUE positives** — commit `a0a4fb2` ("Initial commit - workspace
  backup", 2026-03-03) swept an entire workspace into this repo, including
  trading-bot scripts (`real-trade.ts`, `buy-clawked*.ts`, `paraswap-swap*.ts`)
  with **two hardcoded Ethereum private keys**. The files were deleted in
  `66ca285`, but the keys remain in git history — and **this repo is PUBLIC**
  on GitHub (public since repo creation 2026-05-06). Derived addresses:
  `0x0089395dBced5DE83D65f13a38140F70777D56F0` and
  `0x3713C3af73870c2674F63E7C796B13c4A4014201`.

**Status: keys must be treated as fully compromised** (public-repo scrapers
harvest these in minutes). Remediation:
1. **Owner action (urgent, done outside this repo):** move any funds off both
   addresses; never reuse these keys anywhere. Rotation is the fix — history
   scrubbing alone does NOT un-leak a key.
2. **Pending owner approval:** rewrite git history (`git filter-repo`) to
   drop the leaked blobs, force-push all branches. Destructive; needs sign-off.
3. **Intentional:** `.gitleaks.toml` does NOT allowlist these findings —
   full-history scans stay red until the history rewrite lands, as a standing
   reminder. Push-event scans (new commits only) pass, so CI ships normally.

Also proves the N/A-review rule works: "no real keys exist in this project"
was an architecture assumption; the backup commit predating the game violated it.

---

## 2026-07-12 — Initial adapted-checklist audit

Ran the full quick-audit block for the first time after adapting the
original SaaS checklist to this game's actual (client-only, no backend)
architecture.

| ID | Status | Evidence |
|----|--------|----------|
| A1 | PASS | `find web/game -name "*.map"` — no source maps shipped; no `sk_live`/`AKIA`/`pk_live` strings in `web/game`, `src`, or `scripts` |
| A4 | PASS | `.github/workflows/export-game.yml` exists with real build/verify gates |
| A7 | PARTIAL | itch.io not yet live (page not created — expected, owner action pending per STATUS.md). Vercel mirror serves HTTPS + CDN. |
| A8 | **FAIL (mirror only)** | `vercel.json` defines CSP, X-Content-Type-Options, Referrer-Policy — but `curl -sI https://lil-blunt-game.vercel.app/` shows only `strict-transport-security` and `x-frame-options` live (Vercel platform defaults). CSP/nosniff/referrer-policy are defined in-repo but not present on the live response — the deployed Vercel build predates the header config, or Vercel isn't applying `vercel.json` headers on this project. **Fix needs a Vercel redeploy trigger, which this environment cannot perform** (no Vercel token/CLI wired here) — flagging for the user or a future session with Vercel access. Not urgent: Vercel is the mirror, itch.io is primary, and itch.io serves its own headers per `web/_headers`'s own comment. |
| E3 | **FIXED THIS AUDIT** | No `gitleaks`/`trufflehog` step existed in CI. Added `gitleaks/gitleaks-action@v2` as the first CI step — fails the build non-zero on any secret finding. |
| D5 | PASS | Every itch.io/CI deploy is versioned via `--userversion "$(git rev-parse --short HEAD)-..."` — builds are traceable to a commit, not a mutable blob |
| D-C1 | PASS | `web3_manager.gd` uses `DEMO_ADDRESS = "0xDEMO...0000"`; `main_menu.gd` labels both wallet states `WALLET DEMO: ON/OFF` explicitly |
| D-C2 | PASS | No hardcoded real wallet/contract addresses (`0x[a-fA-F0-9]{40}`) found in `src/` |
| D-C3 | PASS | `variant/thread_support=false` in the export preset — the itch.io/iframe/mobile boot-failure root cause stays fixed |
| D-C4 | PASS | `web/launcher.js` rejects postMessage from any origin other than `window.location.origin`; `combo_system.gd` sends only to `window.location.origin`, never `'*'` |

**Sections N/A in full** (justified in the checklist doc, not re-litigated
per audit): A2, A3, A5, A6, A9–A11, all of B, all of C except C7-equivalent,
D1–D4, D6–D9. Re-audit any of these the moment a real backend, accounts,
payments, or multiplayer feature is proposed — the N/A status is tied to
the current architecture, not a permanent exemption.

**Open item carried forward:** Vercel header gap (A8). Needs a redeploy from
an environment with Vercel push access to confirm `vercel.json` takes effect.
