# Docs Workspace

Where the record lives: what was built, why, how it was proven. ADR rules are in `docs/CLAUDE.md`. (Workspace pattern: founder's
coach, "The Lesson 3.1"; kept current by skill `context-md-upkeep`.)

## Audience
- `STATUS.md` (repo root): the FOUNDER's page. Short, plain, newest first, honest scores (closeness numbers, Jev / Microsoft /
  Astra verdicts). Updated with every shipped change.
- `docs/episode2-quality/<topic>-<date>/`: proof per visual change - before/after boards, capture PNG/JPGs, measured reports (JSON).
  Tests may read a report from here (e.g. the rifle logo gate reads `lil-blunt-rifle-logo-2026-10-10/logo_fix_report.json`).
- `docs/model-responses/<date>-<topic>.md`: raw outside-model answers (Astra, DeepSeek). Advice, never facts.
- `docs/pck_budget_doc.md`: every pack addition with its size.
- `docs/security/`: audit log + checklist (security sentinel).

## Naming
- Topic docs: `[topic]_doc.md`. Intake of a founder delivery: `docs/episode2-quality/intake_<date>_doc.md`.
- `docs/*` is excluded from the web export (export_presets.cfg), so proof images here cost no pack space.
