---
name: smokerealm-resume
description: Resume GM-GAME efficiently after rate limits or another Claude/Codex session, inspect intervening commits, preserve concurrent changes, and reuse valid evidence with compact checkpoints.
---

# Commit-aware SmokeRealm resumption

Use on session startup, after a rate-limit gap, and before publishing overlapping work. This skill runs when an agent resumes; it cannot monitor Claude while Codex is unavailable.

## Recover only the delta

Read AGENTS.md, current CLAUDE.md and the default context manifest. Read `.agents/resume-checkpoint.json` if present, treating its SHAs and claims as historical evidence, not current truth. Start with the current STATUS headings and relevant sections rather than its entire accumulated history.

Run `python <skill-directory>/scripts/resume_digest.py --repo <checkout>` for a bounded, read-only report. It does not fetch automatically. Fetch `origin master` once, then rerun it; explicitly report freshness failures. The helper compares the checkpoint with origin/master, counts all intervening commits including CI commits, lists a bounded sample of substantive commits, groups changed paths, and flags paths overlapping the task. Never infer authorship from commit subject alone.

Inspect patches only for overlapping paths, changed repository instructions, and relevant tests. Use `git diff --name-only` before content diffs. Avoid `git ls-tree -l` in this partial clone: blob sizes can trigger huge downloads. Fetch/import only assets actually required for current verification.

Preserve dirty files and others' commits. Fast-forward a clean behind-only checkout; reconcile divergent work deliberately. Recheck remote master immediately before publishing and use non-forced updates. If master moves, inspect the new delta; do not overwrite it with an old tree.

## Spend context on unresolved decisions

Keep the checkpoint below roughly 2 KB: observed remote SHA, objective, owned/touched paths, completed evidence with exact source SHA, unresolved issues and next action. Update after a meaningful milestone or before yielding. Store detailed logs/screenshots on disk; return their paths and decisive results, not entire logs, binaries, or repeated history.

Reuse tests only when relevant code, dependencies, fixtures and environment are unchanged. Mark old evidence historical when overlap invalidates it. Run affected checks and required repository gates; do not rerun the whole game for skill-only edits or claim old gameplay tests validate new Claude code. Separate source commit, successful CI upload, and public BUILD verification.

Use existing `scripts/jev.mjs` only for a difficult decision with measured inputs and real uncertainty. Check credential availability without revealing values. Jev takes textual metrics, not screenshots, and does not replace Blender work, code review or visual inspection. Send a small question with options, criteria and measurements; retain the actual verdict and limits. If unavailable or inconclusive, record that and continue independent work. Do not add paid services or fabricate a verdict. Ordinary Git reconciliation needs no Jev call.

Use `smokerealm-ship` for game releases and `smokerealm-episode2-art` for art changes. A skills-only commit need not force a new game export. Preserve the current user objective and explicit authorization; a checkpoint does not authorize unrelated work.
