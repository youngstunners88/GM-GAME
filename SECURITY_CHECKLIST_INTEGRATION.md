# Secure-Build-Checklist Integration — how the coach's gate runs here

The coach's `secure-build-checklist` skill (33+ checks, 11 categories) is now
a hard CI gate in this repo — **additive** to, never replacing, the existing
security model (sentinel's 18 checks, TRUST-001, rate limits, CORS, gitleaks).

## Where things live

| Piece | Path |
|---|---|
| Scanner (Bun) | `scripts/security-audit.ts` |
| Rules (adapted) | `scripts/assets/security-checklist.json` (v1.3.0+gmgame.1) |
| Human-readable reference | `docs/security/secure-build-checklist-reference.md` |
| Manual DeFi gate | `DEFI_REVIEW.md` |
| Manual Android gate | `ANDROID_EXPORT_SECURITY.md` |
| This record | `SECURITY_CHECKLIST_INTEGRATION.md` |

## CI wiring (`.github/workflows/export-game.yml`)

Order: gitleaks → sentinel → Godot export → web3.js bundle gate →
**security-audit (this gate)** → commit export → mirrors → itch.io butler.

- Step installs Bun, runs `bun scripts/security-audit.ts --fail-on=high --json`.
- **Exit 1 blocks the deploy** exactly like the web3.js gate (deploy steps are
  `if: success()`).
- `security-report.json` is uploaded as a CI artifact (30 days) on every run.
- On failure with an open PR for the branch, a comment posts the
  critical/high blockers.
- On pass the log prints: `Security audit passed — X checks, Y skipped, Z manual`.

Run locally any time: `bun scripts/security-audit.ts --fail-on=high`.

## Stack adaptations (task #2) — each one deliberate

| Change | Why |
|---|---|
| `file_must_exist` → ANY-OF semantics | Upstream required ALL alternatives (terms.md AND terms.html AND `legal/**`) and `existsSync` can't glob — DATA001/003 could never pass anywhere. The lists are clearly alternatives. |
| `.md` added to the content-scan allowlist | DATA002 targets `["*.md"]` but upstream silently skipped markdown — the check was unsatisfiable. Legal text lives in markdown. |
| `requires_file` extension (+ DEP002 gets `"requires_file": "package.json"`) | Lockfile checks only apply where a Node manifest exists; this repo has none (CI installs playwright ad hoc). The check re-arms automatically the day a package.json lands. |
| Loopback git remotes allowed in DEP004 | The remote-execution sandbox proxies git via `http://…@127.0.0.1`; loopback can't be MITM'd off-host. GitHub remotes in CI remain HTTPS-enforced. |
| `stack_profile` block in the JSON | Documents in-band: Godot 4.3 HTML5 + Cloudflare Worker; no Supabase/Postgres/Mongo/React — those checks skip or pass structurally (SEC002/AUTH001/AUTH004/LOG003 auto-skip). |
| DeFi category → manual + `DEFI_REVIEW.md` | No `.sol` in repo, but external ERC-20/721 interactions exist (task #3): added M-DEFI-1 (addresses correct + audited) and M-DEFI-2 (no dangerous wallet permissions — we request zero `approve`s, structurally). |
| PLAT manual items → `ANDROID_EXPORT_SECURITY.md` | No Android preset today; the gate is pre-committed for the day one appears (task #4). |

## Findings the gate produced on first run (and their real fixes)

1. **DATA001 (high)** — we collect emails with no ToS/Privacy. Fixed
   properly: `terms.md` + `privacy.md` written (honest, game-specific).
2. **DATA002 (high)** — no export/delete flow. Fixed properly: REAL
   `GET /data-export` + `GET /data-delete` Worker routes (authenticated by
   the per-player unsubscribe token, rate-limited), linked in every email
   footer, documented in privacy.md. Not just words matching a regex.
3. **DATA003 (medium)** — no license/provenance file → `LICENSE.md` with the
   full asset-provenance table.

Current status: **28 pass · 0 fail · 14 manual · 5 skip · exit 0** at
`--fail-on=high`.

## Relationship to the existing model (constraint: additive only)

- `security-sentinel.sh` = repo-SPECIFIC invariants (thread_support, INJ-003
  eval hygiene, TRUST-001 wallet posture…). Unchanged.
- `security-audit.ts` = UNIVERSAL vibe-coding checklist (secrets, deps,
  injection, legal, platform, DeFi). New.
- Both run in CI on every push; either can block alone. The checklist
  narrative home remains `docs/security/GAME_SECURITY_CHECKLIST.md`
  (Sections A–H) — audit runs append to `docs/security/audit-log.md`.
