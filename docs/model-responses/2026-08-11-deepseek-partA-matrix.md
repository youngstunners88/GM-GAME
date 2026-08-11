<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: prompts/deepseek-partA-matrix.md
     files inlined: 5
     tokens: 4599 in / 2969 out
     cost: $0.0067
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Compliance Matrix — Part A

## INSTALL STEPS

| # | Requirement | Evidence | Verdict |
|---|---|---|---|
| 1 | "Copy skill into the repo: `.claude/skills/secure-build-checklist/` SKILL.md, assets/checklist.json, references/checklist.md, scripts/audit.ts" | SKILL.md exists at `.claude/skills/secure-build-checklist/SKILL.md` (116 lines). `scripts/audit.ts` exists at `.claude/skills/secure-build-checklist/scripts/audit.ts` (inferred from shim path). `assets/checklist.json` and `references/checklist.md` paths are documented in SKILL.md and INTEGRATION.md but **their file contents are not provided in the repo state**. INTEGRATION.md still references the OLD path `scripts/assets/security-checklist.json` as "Rules (adapted)" — contradicting the claim of relocation. | **PARTIAL** — Two of four required files are confirmed present; two are referenced but not provided in evidence. The integration doc still points to the old flat path for the rules file, suggesting incomplete relocation. |
| 2 | "Do not overwrite existing `security-sentinel` / `scripts/security-sentinel.sh`" | No evidence of sentinel deletion or modification. SKILL.md explicitly states "Never delete either" and "additive to game-security-sentinel." INTEGRATION.md confirms sentinel is "Unchanged." | **PASS** |
| 3 | "Runtime: prefer `bun scripts/audit.ts` from the skill path. If Bun missing, install or document `npx bun` / equivalent; do not fake a pass." | SKILL.md documents `bun .claude/skills/secure-build-checklist/scripts/audit.ts . --fail-on=high --verbose`. Bun install instructions provided. The shim at `scripts/security-audit.ts` re-execs the real scanner via `spawnSync("bun", [real, ...])`. | **PASS** — Runtime path documented; shim preserves old invocation path. |

## RELOCATION JUDGMENT (Install Step 1 nuance)

| Concern | Finding |
|---|---|
| Did relocation satisfy "Install" or dodge it? | The founder asked to install at `.claude/skills/secure-build-checklist/`. A previous session had installed at `scripts/security-audit.ts` + `scripts/assets/security-checklist.json`. The pass **moved** the scanner to the skill path and left a shim. This IS installation at the requested path — the skill now lives where specified. The shim is additive compatibility, not duplication. **However**: INTEGRATION.md still lists `scripts/assets/security-checklist.json` as the rules path (line: "Rules (adapted) | `scripts/assets/security-checklist.json`"), which contradicts the claim that rules were moved to `assets/checklist.json` under the skill. Either the rules weren't moved, or the integration doc is stale. Either way, the evidence is inconsistent. | **PARTIAL** — Scanner relocated correctly; rules file location is contradictory across docs. |

## GM-GAME ADAPTATION RULES

| Rule | Requirement | Evidence | Verdict |
|---|---|---|---|
| Critical/High from real greps | "Block deploy until fixed" | INTEGRATION.md reports "0 fail" at `--fail-on=high`. DATA001, DATA002, DATA003 were found and fixed (ToS, privacy, export/delete routes, LICENSE.md). No current critical/high blockers. | **PASS** — Blockers found and fixed; exit 0. |
| Supabase RLS / VITE_ secret patterns | "SKIP if no such stack — mark skip with reason" | SKILL.md: "Supabase RLS and `VITE_`-prefix rules skip." INTEGRATION.md: "no Supabase/Postgres/Mongo/React — those checks skip or pass structurally." | **PASS** |
| npm audit / lockfile | "Run if Node tooling exists; if pure Godot with no package.json deps of concern, note N/A" | INTEGRATION.md: "Lockfile checks only apply where a Node manifest exists; this repo has none." `requires_file: "package.json"` added to DEP002. SKILL.md: "no `package.json`, so lockfile rules re-arm the day one lands." | **PASS** |
| Sentry / PostHog / error tracking | "Should pass if already wired; if fail, fix config not invent stack" | SKILL.md: "Sentry (`error_reporter.gd`) and PostHog (`analytics.gd`) are wired." INTEGRATION.md reports 28 pass / 0 fail. No evidence of config fixes needed. | **PASS** — Claimed as passing; no fail evidence. |
| ToS / Privacy Policy | "MANUAL — ask founder or open issue; do not invent legal pages this session unless asked" | INTEGRATION.md: "DATA001 (high) — we collect emails with no ToS/Privacy. Fixed properly: `terms.md` + `privacy.md` written (honest, game-specific)." This was **fixed**, not left as MANUAL. The founder said "do not invent legal pages this session unless asked" — the pass **did** invent them. | **FAIL** — Adaptation rule required MANUAL (ask founder); the pass instead wrote legal pages unprompted. |
| DeFi / Solidity category | "SKIP unless contract artefacts appear" | INTEGRATION.md: "DeFi category → manual + `DEFI_REVIEW.md`. No `.sol` in repo, but external ERC-20/721 interactions exist." SKILL.md: "No `.sol` in-tree, but real ERC-20/721 interactions exist." The rule says SKIP unless contracts in-tree; the pass made it MANUAL instead, adding M-DEFI-1 and M-DEFI-2. | **PARTIAL** — Rule said SKIP; pass escalated to MANUAL with justification. Reasonable but not what the rule specified. |
| Android Wireless ADB / control-plane | "SKIP for web itch build; note for future mobile APK" | INTEGRATION.md: "PLAT manual items → `ANDROID_EXPORT_SECURITY.md`. No Android preset today; the gate is pre-committed." SKILL.md: "No Android preset today; gate pre-written for the day one appears." Rule said SKIP; pass made it MANUAL with pre-committed gate. | **PARTIAL** — Same pattern as DeFi: rule said SKIP, pass escalated to MANUAL. |

## vs EXISTING SENTINEL

| Requirement | Evidence | Verdict |
|---|---|---|
| "Both must be green (or skip-justified) before claiming ship-safe" | INTEGRATION.md: "Current status: 28 pass · 0 fail · 14 manual · 5 skip · exit 0." Sentinel status not explicitly re-verified in provided files, but INTEGRATION.md states sentinel is "Unchanged" and SKILL.md says "Never delete either." | **PASS** — Checklist reports green; sentinel claimed unchanged. |
| "Do not delete either" | SKILL.md: "Never delete either, and never 'consolidate' one into the other." No evidence of deletion. | **PASS** |

## STATUS REQUIREMENT

| Requirement | Evidence | Verdict |
|---|---|---|
| "Record: checklist version" | SKILL.md metadata: `local_version: 1.3.0+gmgame.1`. INTEGRATION.md: "v1.3.0+gmgame.1". | **PASS** |
| "Record: pass/fail/skip counts" | INTEGRATION.md: "28 pass · 0 fail · 14 manual · 5 skip." | **PASS** |
| "Record: any critical/high with file:line" | INTEGRATION.md lists DATA001, DATA002, DATA003 as findings but reports them as **fixed** — current status is 0 fail. No current critical/high with file:line recorded because none remain. | **PASS** — None to record; fixed blockers documented. |
| "Record: relationship to sentinel 18/18" | INTEGRATION.md: "Relationship to the existing model" section. SKILL.md: "Relationship to the sentinel" section. Sentinel 18/18 status not explicitly re-stated as "18/18" in provided files, but claimed unchanged. | **PARTIAL** — Relationship documented; explicit "18/18" re-verification not in evidence. |

## HONESTY OF REPORTING (47 total / 28 pass / 0 fail / 14 manual / 5 skip)

| Concern | Finding |
|---|---|
| Is 28 pass / 0 fail / 14 manual / 5 skip honest for a project with no backend, database, auth, or payments? | The SKILL.md explicitly addresses this: "A check that does not apply reports SKIP with a machine-readable reason, and skips are counted and printed separately from passes." The 28 passes are for checks that **do** apply (secrets greps, injection, API hardening, observability, legal, infrastructure). The 5 skips are for non-applicable surfaces. The 14 manuals are for gates requiring human judgment (DeFi, Android, some legal). This distribution is **consistent with the stated architecture** — a Godot HTML5 game with Cloudflare Workers, Sentry, PostHog, email collection, and ERC-20/721 interactions. The pass did not inflate passes by counting skips as passes. | **HONEST** — The separation of pass/skip/manual is deliberate and documented. The numbers are plausible for this architecture. |

## DEFINITION OF DONE

| # | Requirement | Evidence | Verdict |
|---|---|---|---|
| 1 | "Skill installed under `.claude/skills/secure-build-checklist/`" | SKILL.md confirmed at path. `scripts/audit.ts` at skill path (inferred). `assets/checklist.json` and `references/checklist.md` paths documented but **not provided in evidence**. INTEGRATION.md still references old flat path for rules. | **PARTIAL** — Scanner and SKILL.md confirmed; rules and reference files not in evidence; integration doc contradicts relocation. |
| 2 | "Audit run; critical/high fixed or skip-justified for Godot/itch" | INTEGRATION.md: "28 pass · 0 fail · 14 manual · 5 skip · exit 0." DATA001/002/003 fixed. No current blockers. | **PASS** |
| 3 | "Sentinel still 18/18" | Claimed unchanged in INTEGRATION.md and SKILL.md. Explicit "18/18" re-verification not in provided evidence. | **PARTIAL** — Claimed but not re-verified in provided files. |
| 4 | "Soft follow-ups only if live evidence" | No evidence of soft follow-ups executed. Part B states "do not reopen PR #19/#20 hard fixes without live fail evidence" — no evidence this was violated. | **PASS** — No unauthorized follow-ups in evidence. |
| 5 | "STATUS + commit; deploy if security fixes landed" | INTEGRATION.md serves as STATUS record. No commit hash or deploy confirmation in provided files. | **PARTIAL** — STATUS documented; commit/deploy not confirmed in evidence. |

## OUT OF SCOPE VIOLATIONS

| Out-of-scope item | Touched? | Evidence |
|---|---|---|
| "inventing ToS pages" | **YES** | INTEGRATION.md: "DATA001 (high) — we collect emails with no ToS/Privacy. Fixed properly: `terms.md` + `privacy.md` written." This directly violates the adaptation rule requiring MANUAL for ToS/Privacy and the out-of-scope prohibition on inventing legal pages. | **FAIL** |
| "replacing security-sentinel" | No | Sentinel claimed unchanged. | **PASS** |
| "large Stage 3 redesign without screenshots" | No evidence | — | **PASS** |
| "Video, B.AI, Episode 2" | No evidence | — | **PASS** |

---

## SUMMARY

| Category | PASS | PARTIAL | FAIL |
|---|---|---|---|
| Install Steps (3) | 2 | 1 | 0 |
| Relocation Judgment | 0 | 1 | 0 |
| Adaptation Rules (7) | 4 | 2 | 1 |
| vs Sentinel (2) | 2 | 0 | 0 |
| STATUS (4) | 3 | 1 | 0 |
| Honesty of Reporting | 1 | 0 | 0 |
| Definition of Done (5) | 2 | 3 | 0 |
| Out of Scope (4) | 3 | 0 | 1 |
| **TOTAL** | **17** | **8** | **2** |

**OVERALL VERDICT: PARTIAL**

**Blockers:**
1. **FAIL — ToS/Privacy adaptation rule violated**: Founder explicitly required MANUAL for legal pages; pass invented `terms.md` and `privacy.md` unprompted, also violating OUT OF SCOPE.
2. **PARTIAL — Rules file location contradictory**: INTEGRATION.md still points to `scripts/assets/security-checklist.json` while SKILL.md claims it lives at `assets/checklist.json` under the skill. Cannot confirm installation completeness.
3. **PARTIAL — Two required skill files not in evidence**: `assets/checklist.json` and `references/checklist.md` are documented but their contents were not provided in the repo state.