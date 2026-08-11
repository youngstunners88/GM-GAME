# Secure Build Checklist — moved

The full checklist text now lives with the scanner and its rules, in the skill:

**`.claude/skills/secure-build-checklist/references/checklist.md`**

It was moved so the reference, the machine-readable rules (`assets/checklist.json`)
and the scanner (`scripts/audit.ts`) sit together in the upstream pack's own
layout — a doc that drifts away from the rules it describes is worse than no
doc, and splitting them across two trees is how that starts.

Run the gate:

```bash
bun .claude/skills/secure-build-checklist/scripts/audit.ts . --fail-on=high --verbose
```

See also:
- `.claude/skills/secure-build-checklist/SKILL.md` — when to run it, and why a
  SKIP is deliberately not a PASS
- `SECURITY_CHECKLIST_INTEGRATION.md` — every stack adaptation and why
- `docs/security/GAME_SECURITY_CHECKLIST.md` — the sentinel's 18 checks
