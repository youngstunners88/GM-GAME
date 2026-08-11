---
name: secure-build-checklist
description: Broad pre-ship security gate for Lil Blunt Adventure — 47 checks across 11 categories (secrets, supply chain, auth, injection, AI-generated-code risk, API hardening, observability, legal posture, infrastructure, platform privilege, DeFi). Additive to game-security-sentinel, never a replacement. Run before any release, after adding a dependency/endpoint/auth flow, and whenever the architecture gains a surface the checklist currently skips.
metadata:
  author: adapted from kofi.zo.computer's secure-build-checklist v1.3.0
  local_version: 1.3.0+gmgame.1
---

# Secure Build Checklist

The **broad** pre-ship gate. Where `game-security-sentinel` asks 18 sharp
questions specific to this game, this asks 47 general ones drawn from a
general-purpose secure-build pack, adapted to the architecture this project
actually has.

Both must be green — or skip-justified — before anything is called ship-safe.
Neither replaces the other. See "Relationship to the sentinel" below.

## Run it

```bash
bun .claude/skills/secure-build-checklist/scripts/audit.ts . --fail-on=high --verbose
bun .claude/skills/secure-build-checklist/scripts/audit.ts . --fail-on=high --json
```

Bun is required. If it is missing, install it (`curl -fsSL https://bun.sh/install | bash`)
rather than skipping the gate — **a gate that did not run is not a pass**, and
must never be reported as one.

Exit codes: `0` clean at the threshold, `1` blockers found, `2` internal error
(including "no rules loaded", which is deliberately fatal — see below).

`scripts/security-audit.ts` at the repo root still works; it is a three-line
shim that execs this one, kept so existing muscle memory and any external
reference keep working. It is not a second copy.

## Layout

| Piece | Path |
|---|---|
| Scanner (Bun/TypeScript) | `scripts/audit.ts` |
| Rules, adapted | `assets/checklist.json` |
| Human-readable reference | `references/checklist.md` |
| Integration record + adaptation rationale | `/SECURITY_CHECKLIST_INTEGRATION.md` |
| Manual DeFi gate | `/DEFI_REVIEW.md` |
| Manual Android gate | `/ANDROID_EXPORT_SECURITY.md` |

This is the upstream pack's own layout. An earlier integration had flattened it
to `scripts/assets/security-checklist.json`; it was moved back so this tree
stays byte-comparable to upstream and a version bump is a diff rather than an
archaeology exercise.

## The rule that matters most: a skip is not a pass

This project is a Godot 4.3 game exported to HTML5 and hosted on itch.io. It
has **no backend, no database, no auth, no server routes, no payments**. A large
fraction of a general SaaS checklist therefore cannot fail here — not because
the project is secure, but because the surface does not exist.

That is the dangerous case. Forty irrelevant checks reporting PASS manufactures
confidence that nothing earned. So:

- A check that does not apply reports **SKIP with a machine-readable reason**,
  and skips are counted and printed **separately from passes**.
- A check that needs a human reports **MANUAL**, also counted separately.
- The scanner **exits 2 if it loads zero checks**. A rules file that failed to
  parse would otherwise sail through as a clean pass, which is the single worst
  outcome this tool can produce.

Read the summary line as `pass / fail / manual / skip` — never as one number.

## Applicability for this architecture

| Category | Verdict | Why |
|---|---|---|
| Secrets & Environment | **APPLIES** | Real greps over a real tree; CI holds a butler deploy key. |
| Dependencies & Supply Chain | **APPLIES** | Godot + export templates are checksum-pinned; no `package.json`, so lockfile rules re-arm the day one lands. |
| Auth, AuthZ & Sessions | **MOSTLY SKIP** | No auth exists. Re-arms the moment accounts or a leaderboard do. |
| Injection & Input Validation | **APPLIES** | `OS.execute`, `Expression`, `JavaScriptBridge.eval`, runtime-built file paths. |
| AI-Generated Code Risk | **APPLIES** | `eval`/dynamic-exec greps apply; Supabase RLS and `VITE_`-prefix rules skip. |
| API Hardening | **APPLIES** | The Cloudflare Worker endpoints are the only server surface. |
| Logging & Error Tracking | **APPLIES** | Sentry (`error_reporter.gd`) and PostHog (`analytics.gd`) are wired. |
| Data Handling & Legal | **APPLIES** | Emails are collected; `terms.md`, `privacy.md`, export/delete routes exist. |
| Infrastructure & Deployment | **APPLIES** | Includes the non-threaded web export rule that keeps itch.io booting. |
| Platform Privilege / Android | **MANUAL, pre-armed** | No Android preset today; gate pre-written for the day one appears. |
| DeFi & Smart Contracts | **MANUAL** | No `.sol` in-tree, but real ERC-20/721 interactions exist. |

## Re-audit triggers — check these the moment they change

Every SKIP above is conditional on the architecture, not permanent. Re-run and
re-classify immediately if the project gains:

- a real backend, database, or any server-side session
- user accounts, login, or a leaderboard
- real payments or a checkout flow
- multiplayer or any socket the client does not fully control
- a `package.json` with runtime dependencies
- an Android/desktop export preset
- any `.sol` or deployed contract artefact in-tree

## Relationship to the sentinel

- `game-security-sentinel` → 18 project-specific checks, runs **unprompted**
  mid-session, in `release-game.sh`, and in CI. Sharp and narrow.
- `secure-build-checklist` (this) → 47 broad checks, run at release and when a
  new surface appears. Wide and general.
- Overlap is intentional and additive. **Never delete either**, and never
  "consolidate" one into the other — they fail differently, which is the point.

## CI

Wired into `.github/workflows/export-game.yml` after the web3 bundle gate and
**before** the export commit and the itch.io push, so a blocker stops the
deploy. `security-report.json` is uploaded as an artifact on every run, and
critical/high blockers are posted to the open PR.
