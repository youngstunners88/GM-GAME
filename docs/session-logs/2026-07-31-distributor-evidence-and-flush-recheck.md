# 2026-07-31 — Distributor: real-physics evidence hardened; flush-error recheck

Session type: residual verification + feel, per the founder's
`PROMPT_DISTRIBUTOR_AND_FLUSH_RESIDUAL.md`. Video work stayed deferred. CI
infra, PostHog, Sentry, PixelLab MCP stayed closed, per instruction.

## Goal 1 — stronger end-to-end evidence for The Distributor

`tests/distributor_behaviour_test.gd` gained three new real-physics test
functions (previous session), on top of the four that already existed:

1. **Orb redirect under real physics** — spawns a live volley via
   `_throw_shards()`, builds a genuine `Area2D` (layer 64, group
   `"projectile"`, matching every real attack in this project) positioned on
   a live orb, and waits for the physics server itself to flip
   `orb._redirected` — not a direct method call. Then verifies the orb homes
   in, is consumed, and the boss actually loses health **outside** its
   vulnerable window (Forced Distribution's whole point).
2. **POOL DRAIN under real physics** — the same real-collision path, but
   redirects all three orbs of a volley and checks the boss is forced
   straight into `VULNERABLE` with real damage applied.
3. **Full damage cycle to death** — drives a fresh boss down through both
   phase thresholds via the real gated `take_damage()` path, then delivers
   the killing blow and asserts `is_dead` becomes true (relying on documented
   GDScript coroutine semantics: `die()`'s first line runs synchronously
   before its first internal `await`).

**Bug found and fixed (test-only, no engine code touched):** test 1 was
initially picking up a *stale* orb left alive from an earlier, longer-running
test in the same scene tree (orbs have a 4s lifetime; an earlier test runs
900 physics frames). Root-caused by reading the orb's real `_t` property
directly (2.15s — long past `unstable_time = 0.35`) rather than trusting
`get_overlapping_areas()`, which was reporting correctly all along. Fixed by
filtering `boss_projectile` children to the boss's *current* `_volley_id`
before selecting one, mirroring the pattern the pool-drain test already used.

**Crash found and fixed:** test 2 (pool drain) originally created, waited on,
and `queue_free()`'d one stand-in attack `Area2D` per orb *sequentially*
inside a `for` loop — create, wait up to 10 physics frames, free, then
immediately create the next. This reliably crashed the Godot engine itself
with **SIGSEGV** partway through the loop (confirmed via native backtrace;
not a GDScript-level error). Rewritten to create all three stand-in attacks
**up front**, let physics settle all three overlaps together across shared
frames, then free all three together at the end — no more tight sequential
churn of physics objects. Crash gone; the pool-drain test and the
previously-blocked full-damage-cycle test both now run and pass.

**Confirmed green, full run:**
```
[PASS] a real overlap (layer 64 + group 'projectile') redirects the orb
[PASS] redirected orb homes in and is consumed on arrival
[INFO] boss health before -> after redirect = 7 -> 5
[PASS] the redirect actually damaged the boss OUTSIDE the vulnerable window
[PASS] phase-1 volley spawns exactly 3 orbs
[PASS] all 3 orbs in the volley were redirected
[PASS] POOL DRAIN forces the boss straight into VULNERABLE
[INFO] boss health before -> after pool drain = 7 -> 5
[PASS] POOL DRAIN dealt real damage
[PASS] fresh boss starts at full health
[PASS] boss survives down to 1 HP via the gated take_damage() path
[PASS] phase escalates to 3 before death (thresholds [4,2])
[PASS] the killing blow sets is_dead
DISTRIBUTOR_BEHAVIOUR: ALL PASS
```

**Not fully explained, flagged rather than hidden:** the redirect and pool
drain tests both show a 2-point health drop (7→5) where
`MAX_REDIRECT_DAMAGE_PER_VOLLEY = 1` would predict 7→6. Hypothesis (not yet
confirmed): the boss's own hitbox stays `monitoring = true` for the entire
fight — only `monitorable` toggles with the vulnerable window — so the test's
leftover stand-in "attack" `Area2D` may be taking an incidental extra hit
from the boss's natural background state cycling during the wait loop. This
does not currently fail anything (the assertion is a loose `<` inequality),
but it means the *exact* damage-per-redirect number is not yet proven to the
same rigor as everything else in this file. Left as an open item rather than
guessed at.

**Honest remaining gap, stated per the founder's rule:** The Distributor
fight has still never been played by a human, and the boss has never been
reached via the click-driven browser harness in this project (level 2 is
gated behind level 1 + 2's full traversal, which the harness does not drive).
Redirect timing, orb cadence, and overall pace *by feel* remain unvalidated.
Everything above is proven by measurement, not by play.

**Gates run:**
| Gate | Result |
|---|---|
| distributor_behaviour (extended) | **ALL PASS** (13 checks, 0 crashes) |
| script_compile | ALL PASS — 113 scripts, 75 scenes |
| boss_arena_reachable | ALL PASS — all 3 levels |
| security-sentinel | 18/18, 0 blockers |

## Goal 2 — web-only physics-flush-error burst: recheck, not reproduced

Prior sessions documented a reproducible 5-error burst
(`body_set_shape_disabled x1`, `body_set_shape_as_one_way_collision x2`,
`area_set_shape_disabled x2`) firing once during the menu → `SceneRouter` →
Level 1 transition on a real web export, never in headless direct level
loads. Four real sources were already fixed (`one_way_platform.gd`,
`smoke_cloud_platform.gd`, `hostile_vine.gd`, `timed_door.gd` — all switched
to `set_deferred`), and one hypothesis (a `process_frame` yield around
`change_scene_to_file` on the web branch) was tried and reverted because it
did not reduce the count. The burst itself was left as a named open item.

This session re-ran the exact documented reproduction against a fresh export
of the current code (no physics-adjacent file has changed since that last
fix): export web build → serve locally with the production COOP/COEP headers
→ Playwright/Chromium (swiftshader) → click PLAY → watch console.

**Result: 0/8 runs reproduced the flush-error burst.**
- 3 runs via `scripts/verify-game.mjs` (the project's own gameplay gate).
- 5 runs via a raw full-console-dump script (no filtering, to rule out the
  regex allowlist hiding it).
- All 8 runs did reach `PLAYING` via the real `SceneRouter` web path
  (confirmed via the `[SceneRouter] Loaded ... (sync web path)` log line).
- All 8 runs showed only one pre-existing, unrelated, and harmless warning
  (`Invalid state transition: MENU → MENU`, a `push_warning` from a double
  state-machine transition on the menu itself — out of scope for this goal).

**No code was changed for this goal.** Per the founder's explicit rule —
"tune only what evidence proves wrong" — there was no reproducing failure
left to test a fix against, so applying one would be exactly the kind of
speculative, unverifiable change the last two sessions correctly avoided.

**Honest interpretation, not overclaimed:** this is evidence the burst does
not currently reproduce under the documented steps in this environment, not
proof it can never happen again. Two explanations remain open and
undistinguished:
1. It was a side effect of a change made in one of the three commits since
   the last reproduction (Sentry wiring, PostHog wiring, or the automated CI
   re-exports) that altered scene-graph size or load timing enough to move
   the race outside its window — none of which touched physics code directly,
   so this would be incidental, not a fix anyone could point to.
2. It is a genuine timing-sensitive engine race (real GPU vsync jitter vs.
   this sandbox's software/swiftshader rendering) that this headless
   environment cannot reliably trigger at all, independent of any code
   change.

**Recommendation:** close this as a **monitoring item**, not a fixed bug and
not an active one. If it resurfaces — on itch.io, in CI, or in a future
playtest — capture the browser console verbatim before touching anything;
a non-reproducing race is not evidence against the four `set_deferred` fixes
already shipped, which remain correct and are staying in.

## Gates (final, this session)
| Gate | Result |
|---|---|
| distributor_behaviour | ALL PASS |
| script_compile | ALL PASS |
| boss_arena_reachable | ALL PASS |
| security-sentinel | 18/18, 0 blockers |
| flush-error repro attempt | 0/8 — see above, not a gate, an investigation |

## Multi-model
Not dispatched. The founder's rule scoped Kimi to "further changes to the
Distributor's state machine/damage/pull/redirect" — this session's only
change to `distributor.gd`'s *behaviour* was none; the boss implementation
itself was not touched, only its test harness. Grok was scoped to "if the
fight still feels wrong after real observation" — no new human/browser
observation of the fight happened this session (see Goal 1's honest gap
above), so there is nothing for a feel pass to react to yet.

## Blind-spot audit — skills/scripts gaps found from real pain this session

Separately requested: identify gaps in project tooling and build the
highest-value missing pieces. Surveyed the existing 70+ skills and ~20
scripts first — the project is not short on generic process skills, so the
search focused on **concrete gaps that actually cost time in this session
and the two before it**, consistent with this project's own standard for
what earns a place in the toolkit (every check here traces to a real defect,
not a hypothetical one).

**Found and fixed — a live documentation defect, not a missing tool:**
`docs/engine-reference/godot/VERSION.md` claimed the project was pinned to
**Godot 4.6** and had for over five months, while `project.godot`, CI's
`GODOT_VERSION`, and `CLAUDE.md`'s own title all agree it has always been
**4.3**. Both `src/CLAUDE.md` and `docs/CLAUDE.md` instruct every session to
trust this directory before using any engine API — so this was one
`@abstract` decorator away from reproducing the exact failure class the
Distributor boss already shipped with once (a parse error that silently
made the whole script inert). Grepped `src/` for any 4.4+-only syntax
already in use: none found, so this was a live risk, not yet a realized
bug. Corrected `VERSION.md`, and added an explicit "future upgrade path,
not current" banner to `breaking-changes.md` and `current-best-practices.md`
so their real research is kept but can't be mistaken for what the current
engine supports.

**Built — three concrete gaps:**

1. **`scripts/bootstrap-godot.sh`** — this project runs in ephemeral sandbox
   containers with no cross-session persistence; every session before this
   one hand-derived the download-and-SHA512-verify sequence from
   `.github/workflows/export-game.yml` from scratch. This script is that
   exact sequence (same URLs, same checksum gate), idempotent, ~3s cold,
   instant on re-run. Tested end-to-end this session: fresh download +
   checksum pass, then a second run correctly skipped re-downloading.
2. **`docs/engine-reference/godot/gdscript-gotchas.md`** — three traps
   discovered by real debugging this session and the crash investigation:
   lambda closures capturing local value-type variables by value (not
   reference — confirmed via an isolated repro), rapid sequential
   create/destroy of physics `Area2D` objects reliably SIGSEGV-crashing the
   engine itself (confirmed and fixed in Goal 1 above), and shared-SceneTree
   test state leaking across sequential test functions (also confirmed and
   fixed in Goal 1). Linked from `godot-gdscript-specialist.md`'s Version
   Awareness section and folded into `.claude/rules/test-standards.md` as
   enforceable rules so future test authors don't rediscover them the hard
   way.
3. **`scripts/repro-web-race.mjs`** — hunting the flush-error burst (Goal 2)
   required writing a disposable "launch N fresh browser sessions, dump full
   console, aggregate" script from scratch, because `verify-game.mjs` only
   runs once against a fixed error allowlist. Promoted that into a reusable,
   generically-parameterized tool (URL, run count, grep pattern, click
   target) for the next non-deterministic race hunt. Smoke-tested against a
   live local export (2 runs, correct aggregate output) before committing.

**Considered and deliberately not built:** a dedicated "flush error / race
condition" skill wrapping the above script. Two data points (this session's
0/8 non-repro, and the prior session's reliable repro) aren't enough to
generalize a process yet, and the project's own doctrine is to build tools
from confirmed patterns, not speculative ones. If a future race investigation
needs more structure than the script provides, that's the signal to build
the skill — not before.
