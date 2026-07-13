---
name: game-security-sentinel
description: Autonomous security scanner for Lil Blunt Adventure. Runs unprompted whenever the agent touches secrets, wallet/crypto UI, dynamic execution, file I/O, deploy config, or CI — no user invocation required. Adapted from a general SaaS "secure-build-checklist" into this game's actual client-only Godot architecture.
metadata:
  author: adapted from kofi.zo.computer's secure-build-checklist, 2026-07-12
---

# Game Security Sentinel

The autonomous, always-on security layer for Lil Blunt Adventure. This skill
exists so security scanning happens **without being asked** — per CLAUDE.md's
SECURITY-GATE RULE, that's a project requirement, not a nice-to-have.

Runs `scripts/security-sentinel.sh` — the single source of truth for this
project's automated security checks. The same script also runs from
`scripts/release-game.sh` (every ship) and `.github/workflows/export-game.yml`
(every push, independent of any chat session existing at all). This skill's
job is the third leg: catching issues **mid-session, before they're even
committed**, whenever the agent is about to touch security-relevant surface.

## Where this came from

Adapted from an uploaded generic `secure-build-checklist` skill (25+ checks
across 9 categories: secrets, dependencies, auth/sessions, SQL/NoSQL
injection, Supabase RLS, CORS, rate limiting, error tracking, ToS/PP). That
checklist assumes a SaaS app with a backend, a database, and user accounts.
**This game has none of that** — it's a single-player, client-only Godot 4.3
export served as static files. Category-by-category adaptation rationale
lives in `docs/security/GAME_SECURITY_CHECKLIST.md` (the pre-existing
adaptation of a *different* general checklist, done the same way) — read
that first if you need to understand why something is N/A rather than fixed.

What DID port over cleanly, because the underlying risk is real in any
codebase regardless of backend:
- Hardcoded secrets / credentials (SEC-001 → still critical here)
- `.env` hygiene (SEC-002/003 → still applies, this repo has no committed .env)
- Dynamic code execution / eval / shell injection (AI001/INJ004 →
  GDScript's `Expression` class and `OS.execute()` are the direct
  equivalents; `JavaScriptBridge.eval` is this project's one legitimate use,
  checked for safe fixed-template usage only)
- Path traversal (INJ005 → `FileAccess.open()` with a non-const path)
- Supply-chain integrity (DEP001/DEP003 → Godot/butler are SHA-pinned in CI,
  not "latest"; no npm/bun dependency tree exists in this repo to `audit`)
- HTTPS/no-debug-artifacts (INFRA001/DEP003-equiv → source maps, thread_support)

What's genuinely new, not in the uploaded checklist, added because of an
incident this project actually had:
- **SEC-005**: a 64-hex-char private-key scan. The original wallet-address
  check (now SEC-004) only matches 40-hex-char addresses — it would **not**
  have caught the two real Ethereum private keys that leaked into this
  repo's git history on 2026-07-12 (see `docs/security/audit-log.md`). That
  incident is the reason this check exists; don't remove it.
- **TRUST-001**: wallet/crypto UI must never imply real functionality without
  explicit DEMO labeling — SmokeRing/DIAMONDS/GoldMine are live crypto
  projects and this game is their promo vehicle, so fake wallet UX is a
  real-brand trust risk, not a cosmetic detail.
- **CI-003/CI-004**: meta-checks on the security tooling itself — guard
  against `.gitleaks.toml`'s allowlist or `.gitleaksignore`'s fingerprint
  list quietly growing wide enough to hide a real finding under the excuse
  of "just suppressing false positives" (exactly the failure mode this
  project had to think through carefully when the wasm/pck allowlist was added).

## When to activate — automatically, without being asked

Run `./scripts/security-sentinel.sh` (or at minimum re-read its relevant
section) the moment ANY of these happens in a session, unprompted:

- Before every `/release-game` run — **already enforced**, Step 1 calls this
  script directly. This skill doesn't need to re-trigger there; it's for
  everything else.
- The agent is about to commit or push any change touching:
  - `src/autoload/web3_manager.gd`, any file with "wallet" in the name, or
    any new crypto/currency UI
  - Any `.gd` file adding `OS.execute`, `Expression.new`, `JavaScriptBridge.eval`,
    or a new `FileAccess.open` call
  - `.github/workflows/*.yml`, `.gitleaks.toml`, `.gitleaksignore`, or
    `scripts/release-game.sh` / `scripts/security-sentinel.sh` themselves
  - `export_presets.cfg` or the export preset block in `export-game.yml`
    (thread_support, debug flags)
  - Any new third-party API key, webhook, or external service integration
- A user pastes in an external security checklist, audit script, or asks
  "is this safe to ship" / "run a security check" / "audit this"
- The agent notices a hardcoded-looking secret, address, or key while doing
  unrelated work — stop and run the scan immediately, don't wait to be asked
- Before merging any branch to `master` (the ALWAYS-SHIP rule's merge step)

Do NOT activate for: pure docs/design edits with no code touched, asset
additions (sprites/audio) that don't wire in new I/O or network calls, or
work explicitly marked throwaway/prototype.

## How to run it

```bash
./scripts/security-sentinel.sh                 # human-readable, fail-on=high
./scripts/security-sentinel.sh --json           # machine-readable
./scripts/security-sentinel.sh --fail-on=medium # stricter gate
./scripts/security-sentinel.sh --log            # also append a dated entry
                                                 # to docs/security/audit-log.md
```

Exit 0 = no blockers at the threshold. Exit 1 = blockers present.

## What to do with results

1. **Critical/high failures → stop and fix before continuing the task at
   hand**, the same way a failing test blocks a PR. Re-run after fixing.
2. **Medium failures → fix in the same session if the touched file is
   already open; otherwise note it in STATUS.md's known-gaps section.**
3. **A check reporting something this game doesn't have a mechanism to
   fix automatically** (e.g. a licensing question on a new asset) → ask
   the user explicitly, don't guess.
4. Always prefer **narrowing the actual vulnerable code** over widening a
   suppression file (`.gitleaks.toml`, `.gitleaksignore`) — CI-003/CI-004
   exist specifically to catch the lazy version of "fixing" a finding.
5. Log every real run with `--log` so `docs/security/audit-log.md` stays the
   single audit trail — don't create a second log file.

## Files

- `SKILL.md` — this file
- `scripts/security-sentinel.sh` (repo root, not under this skill dir — it's
  shared with CI and the release pipeline, so it lives where those look for it)
- `docs/security/GAME_SECURITY_CHECKLIST.md` — the full category-by-category
  adaptation rationale (why most SaaS-checklist items are N/A here)
- `docs/security/audit-log.md` — dated run history, including the
  2026-07-12 leaked-key incident that motivated SEC-005

## Extending

To add a new check: add a `record "ID" "severity" ...` block to
`scripts/security-sentinel.sh`, re-run against this repo to confirm it
doesn't false-positive on existing (audited-clean) code, then add a row to
this file's "what's genuinely new" section explaining the rationale — every
check here should be traceable to either a real risk category or an actual
incident, not a generic best-practice checkbox copied without adaptation.

## Relationship to `/security-audit`

`/security-audit` (`.claude/skills/security-audit/`) is the deeper,
human-in-the-loop engine-level audit (save tampering, cheat vectors, 6
categories, full report) — run before major milestones. This skill is its
fast, unprompted, always-on sibling: narrow, scriptable, boolean pass/fail
checks that catch regressions the moment they're introduced, not just before
a milestone. Both write to the same `docs/security/audit-log.md`.
