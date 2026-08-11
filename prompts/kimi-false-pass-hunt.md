# Task: find the checks that would FALSELY PASS on this repo

An additive "secure build checklist" is being installed alongside an existing scanner.
The failure mode I care about is **not** a missed vulnerability — it is a check that
reports PASS for the wrong reason, because that is indistinguishable from real safety
in a report and is how a team ships something broken while believing it is covered.

Project: Godot 4.3 GDScript game, exported to HTML5, hosted on itch.io. Static bundle,
no backend/DB/auth/payments. Wallet UI uses `window.ethereum`. CI = GitHub Actions +
butler deploy.

## Files
@include scripts/security-sentinel.sh
@include docs/security/secure-build-checklist-reference.md

## Deliver, ranked by how badly it would mislead
1. Every check in `security-sentinel.sh` that can pass **vacuously** — i.e. its grep
   targets a pattern, a path, or a file glob that does not or cannot exist in this repo,
   so it reports PASS having examined nothing. Quote the specific line/pattern. Note:
   the script scans `git ls-files`, so anything not yet `git add`ed is invisible to it —
   call out every check where that matters.
2. Every check whose regex is narrower than its stated claim, i.e. the label promises
   more than the pattern detects. Give a concrete string that the label implies should
   be caught but the regex misses.
3. Same two questions for the checklist categories in the reference doc, if they were
   implemented naively as greps.
4. For each finding: the minimal change that makes the check honest — either tighten the
   detection, or make it explicitly report SKIPPED-WITH-REASON instead of PASS.
5. Finally: is there any check that would report FAIL on something that is actually
   correct for a Godot project? False positives that would train someone to ignore the
   scanner.

Be adversarial. Assume every PASS is a lie until the pattern proves otherwise.
