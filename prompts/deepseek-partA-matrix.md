# Compliance matrix: did this session satisfy the founder's Part A?

Below is the founder's prompt, then the state of the repo after my pass.
Produce a strict PASS / PARTIAL / FAIL matrix — one row per numbered install
step, one per adaptation rule in the "GM-GAME adaptation rules" table, one per
"vs existing sentinel" requirement, one per STATUS requirement, and one per
"Definition of done" bullet.

For each: quote the requirement, name the concrete evidence, give a verdict.
Be harsh — you are the check on wishful reporting. Mark PARTIAL or FAIL wherever
the evidence does not actually establish the claim. Explicitly flag anything
claimed as done that the files do not support, and anything in OUT OF SCOPE
that the diff appears to have touched.

Two things to weigh carefully rather than rubber-stamp:
- The founder asked to INSTALL the pack. It turned out a previous session had
  already installed it at different paths (`scripts/security-audit.ts`,
  `scripts/assets/security-checklist.json`). I RELOCATED it to the requested
  skill layout and left a shim, rather than installing a second copy. Judge
  whether that satisfies "Install" or dodges it.
- The founder said "do not fake a pass". Judge whether a run reporting
  47 total / 28 pass / 0 fail / 14 manual / 5 skip is honest reporting or
  padding, given the project has no backend, database, auth, or payments.

## The founder's prompt
@include /root/.claude/uploads/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/d30eaee9-PROMPT_INSTALL_SECURE_CHECKLIST_AND_SOFT_FOLLOWUPS.md.txt

## Repo after the pass
@include .claude/skills/secure-build-checklist/SKILL.md
@include scripts/security-audit.ts
@include docs/security/secure-build-checklist-reference.md
@include SECURITY_CHECKLIST_INTEGRATION.md

Output the matrix only. No preamble.
