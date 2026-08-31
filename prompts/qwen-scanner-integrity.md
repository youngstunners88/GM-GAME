# Task: can this scanner be fooled into reporting a clean pass?

Below is a Bun/TypeScript security scanner and the JSON rule set it executes.
It gates a deploy: exit 0 ships the game, exit 1 blocks it.

I am NOT asking whether the rules are good. I am asking whether the SCANNER
faithfully executes whatever rules it is given — because a scanner that
silently under-reports turns every green run into false assurance, and that is
worse than having no scanner at all.

@include .claude/skills/secure-build-checklist/scripts/audit.ts
@include .claude/skills/secure-build-checklist/assets/checklist.json

## Deliver, most severe first
1. **Silent-skip paths.** Every place a check can fail to execute and NOT be
   counted as a failure: unreadable file, glob matching nothing, regex that
   throws, missing `requires_file`, a category with no checks, a `files` list
   whose extensions the walker never yields, depth/size limits, ignored
   directories. For each: does it land in pass, skip, manual, or vanish
   entirely from the totals? Vanishing is the worst — name every one.
2. **Walker blind spots.** `walk()` skips certain directory names and caps
   depth. List every real repo path that would therefore never be scanned,
   and say whether any rule *claims* coverage there. Note the repo ships
   `web/game/*.js`, `.github/workflows/*`, `src/**/*.gd` and a `.claude/` tree.
3. **Exit-code correctness.** Trace `--fail-on=high`. Can a `critical` finding
   ever exit 0? Can a rule be `fail` and not counted in the blocker tally? Does
   a thrown exception mid-scan exit non-zero, or produce a partial report that
   still exits 0?
4. **JSON vs human divergence.** Do `--json` and the printed table ever report
   different counts from the same run? Same question for `--verbose`.
5. **Self-audit gap.** The scanner and its rules now live under `.claude/`. Is
   `.claude/` itself scanned? If a secret were committed there, would any rule
   catch it? Answer from the code, not from intent.
6. For each real finding, the smallest patch that fixes it. Quote line context.

Adversarial. Assume every green run is a lie until the code proves otherwise.
