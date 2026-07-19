# docs — current state (2026-07-19)

## Current & authoritative
- `../LAYER_SHIFT.md` — Book/Movie/Video-Game mapping for every Layer-Shift
  feature, wiring reference, live-vs-needs-input table.
- `../LEVEL_DEPTH.md` — L1 depth mechanics layer map + analytics schema.
- `../AGENTMAIL_SETUP.md` — email activation runbook + compliance + exclusions.
- `security/GAME_SECURITY_CHECKLIST.md` — Sections A–H (static-game baseline,
  backend/wallet F, email-PII G, analytics H) + `security/audit-log.md`.
- `../SECURITY_CHECKLIST_INTEGRATION.md`, `../DEFI_REVIEW.md`,
  `../ANDROID_EXPORT_SECURITY.md` — coach's audit gate integration (this batch).
- ICM overlay: root `00/01/02-*.md` + four track nodes (this batch).

## In progress
- `../LEVEL_23_EXTEND.md` (L2/L3 depth, this batch).

## Known gaps
- `docs/architecture/` ADR coverage is thin relative to shipped systems (the
  studio-template checker flags it). Decision logs in each ICM track now
  carry the load; promote entries to formal ADRs when a decision gets
  contested or superseded.
- Engine-reference folder sparse; add pages as post-4.3-cutoff APIs get used.
