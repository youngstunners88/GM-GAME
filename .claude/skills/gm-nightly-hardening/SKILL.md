---
name: gm-nightly-hardening
description: Rules and bug-class catalogue for autonomous/unattended hardening passes on Lil Blunt Adventure (the nightly Routine). Read this BEFORE any unsupervised bug-fix or security sweep, and whenever running scripts/bug-pattern-scan.sh. It carries the safety rails that keep an overnight run from shipping a regression to the live game, and the catalogue of bug classes that have actually been rejected on a founder hard-refresh.
---

# Nightly hardening — rails and bug classes

An unattended run has no founder in the loop. Everything here exists because the
alternative is shipping a regression to a **live, public, client-facing game**
while he sleeps.

## THE RAILS (non-negotiable for an unattended run)

1. **NEVER push to `master` or any `claude/**` branch.** CI exports and
   **auto-deploys to itch.io via butler** on every push to those — an unattended
   push is an unreviewed public release. Nightly work goes on
   `nightly/hardening-<date>`, which triggers no deploy.
2. **NEVER merge a PR.** Open a **draft** PR and stop. The founder merges.
3. **One fix per commit, each with its own gate**, so any single change can be
   reverted without unpicking a batch.
4. **A gate must FAIL before the fix and PASS after.** Prove it both ways in the
   same run — a gate that only ever passed is worthless. This project has already
   shipped a gate that passed on broken code (2-frame sample of a 15-frame
   hazard); sample the whole hazard window.
5. **Never weaken a gate to get green.** Never skip/disable/quarantine a test.
   If a gate fails and the fix isn't obvious, STOP and report — a red gate is a
   finding, not an obstacle.
6. **Do not touch tuning/feel constants** (boss speeds, separations, multipliers,
   level geometry). Those need the founder's eyes on a hard-refresh. Nightly is
   for **correctness and security only**.
7. **Stop on ambiguity.** If a finding needs a design decision, write it up in
   the morning report instead of guessing. Two well-proven fixes beat six guesses.
8. **Security sentinel must be 18/18** before the PR is opened. If the run added
   any new surface (backend, leaderboard, on-chain write), re-audit the N/A items
   in `docs/security/GAME_SECURITY_CHECKLIST.md`.

## THE BUG-CLASS CATALOGUE

Each of these froze or broke the live game at least once. `scripts/bug-pattern-scan.sh`
greps for them; this is the "why" behind each.

| Class | Signature | Why it kills | Fix shape |
|---|---|---|---|
| **Zero-scale live collider** | `tween_property(self, "scale", …ZERO)` on a body that still collides | A zero-scale collider is degenerate (non-invertible). Anything standing on it is trapped and cannot depenetrate → freeze, music continues | Disable the collider FIRST (`set_deferred("disabled", true)`), animate the **sprite/visual**, never the body. Hit `breakable_block`, `secret_wall`, `timed_door` |
| **Embed probe without recovery** | `move_and_collide(Vector2.ZERO, true)` | Does NOT report a *resting* overlap, so the depenetration it guards never runs | Pass the 4th arg: `move_and_collide(Vector2.ZERO, true, 0.08, true)`. Hit the ladder top-out |
| **Stranded state flag** | a flag whose only exit is a condition that may never come true (`_ground_pounding` needs `is_on_floor()`) | The condition dies with the geometry that produced it → permanent lock | Add a time-based watchdog AND clear it in `player._force_unstick()` |
| **Stranded `time_scale` / `paused`** | `Engine.time_scale = 0.05` restored on an awaited coroutine | The coroutine dies with its node; audio runs on another thread → "frozen but music plays" | Restore on a **tree-owned** `create_timer(t, true, false, true)` with a token guard |
| **Coroutine after free** | node touched after `await` with no re-check | Scene can change / node can be freed across the await | `if not is_instance_valid(self) or not is_inside_tree(): return` |
| **Physics write during flush** | `collision.disabled = true` from a physics callback | Throws "Can't change this state while flushing queries" | `set_deferred("disabled", …)` |
| **Vacuous gate** | asserts sampled at 1–2 frames against a multi-frame hazard | Passes on broken code — worse than no gate | Sample the **whole** window; verify the gate fails pre-fix |
| **Headless-green / live-broken** | world-space measurement under a player-following camera | A constant offset has zero on-screen motion; the metric passes while it *looks* parked | Measure the **gap** (camera-relative), and prefer a real browser capture |

## Triage rules for scanner output

- A zero-scale site on a **dying** entity that first disables its collider /
  monitoring / physics is usually **safe** — the scanner lists these separately
  as TRIAGE. Spot-check that the disable happens **before** the tween.
- A zero-scale site on a **live prop the player can stand on or push against**
  (block, door, platform, lift) is **always** a bug. Fix it.
- `set_physics_process(false)` with no re-enable is fine for an entity about to
  be freed; it's a soft-lock only on something that must resume.
- Do NOT "fix" a finding you can't reproduce or reason about. Report it.

## Definition of "progress by morning"

Good: 1–3 **proven** fixes, each with a pre-fail/post-pass gate, on a draft PR,
plus a written report of what was found, fixed, and deliberately left.
Bad: a large diff of speculative edits, or a green run that changed nothing
because everything ambiguous was skipped silently.
