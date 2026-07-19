# docs — decision log (append-only)

- **2026-07-12 · Adapted checklists over imported ones.** The general SaaS
  security checklist was rewritten against THIS architecture with per-item
  N/A justification — and the N/A triggers re-fire when architecture changes
  (proven: Sections F, G, H were added exactly that way).
- **2026-07-18 · Honesty sections are mandatory.** Every feature doc carries
  a live-vs-needs-your-infra table; no feature is described as live when it's
  inert behind missing keys/addresses.
- **2026-07-19 · ICM umbrella as overlay, not upheaval.** Track nodes route
  to existing code/docs (catalog holds no books); nothing physically moved.
  Root map = 00-welcome / 01-architecture / 02-status; tracks carry
  00-context / 01-current-state / 02-next-task / 03-decisions.
- **2026-07-19 · STATUS.md stays the client's page.** The ICM root
  `02-status.md` is the thin health map for agents; STATUS.md remains the
  narrative report the client reads. One home per fact: 02-status links,
  never duplicates the changelog.
- **2026-07-19 · Two audit engines, one posture.** `security-sentinel.sh`
  (repo-specific, 18 checks) and `security-audit.ts` (coach's 33-check
  universal gate, stack-adapted) both run in CI; neither replaces the other.
