# GDScript / Godot 4.3 — Hard-Won Gotchas

Not official API docs — this file is for traps that **actually cost real
debugging time in this project**, discovered by running code, not by reading
about it. Add to it only when a trap is confirmed by a real repro, the same
evidentiary bar the rest of this project holds itself to. Each entry states
what was observed, why, and the concrete fix pattern.

## 1. Lambda closures capture local value-type variables BY VALUE, not by reference

A `func(...): ...` lambda in GDScript captures local `bool`/`int`/`float`/
`String` variables **at closure-creation time**. Assigning to the captured
variable from *inside* the lambda mutates only the lambda's private copy —
the outer scope never sees the change.

```gdscript
var fired := false
some_signal.connect(func(_arg): fired = true)   # WRONG — outer `fired` never changes
await get_tree().physics_frame
print(fired)  # always false, even after the signal demonstrably fired
```

**Confirmed via an isolated `extends SceneTree` repro** (connect a lambda to
`area_entered`, print from inside the lambda to prove it fires, then check
the outer variable — the print fires, the outer variable stays `false`).

This is a real trap specifically for the common test-harness pattern "wait
for a signal by polling a flag set from a connected callback." A **bound
method** (`self._on_area_entered`) does not have this problem — it mutates
`self`'s real properties, not a closure copy. That's why the shipped game
code (which always uses bound methods, never inline lambdas, for physics
signal handlers) was never affected — this bit a test-only diagnostic, not
gameplay code. But the pattern is generic enough to recur anywhere a test or
tool tries the "lambda + captured flag" shortcut.

**Fix pattern**: never gate a wait loop on a variable mutated by an inline
lambda. Either connect a bound method that mutates `self` state, or read a
real object property directly on each poll (e.g. `orb.get("_redirected")`)
instead of a synthetic flag.

## 2. Rapid sequential create/destroy of physics `Area2D` nodes can SIGSEGV the engine

Creating a physics object (`Area2D` + `CollisionShape2D`), waiting a few
physics frames for an overlap, then immediately `queue_free()`-ing it and
creating the *next* one in a tight loop crashed Godot 4.3 itself with
**signal 11 (SIGSEGV)** — not a GDScript-level error, a native engine crash
with a full backtrace and no script stack.

Confirmed in `tests/distributor_behaviour_test.gd`'s `_test_pool_drain_...`
function: a `for orb in orbs: <create attack> <wait> <queue_free>` loop
crashed partway through, reliably, every run.

**Fix pattern**: don't churn physics objects sequentially inside a loop when
you need one per iteration. Create all of them **up front** in one pass, let
physics settle across shared frames, then free all of them together at the
end. This is strictly safer than trying to time a `queue_free()` +
recreation cycle correctly, and sidesteps whatever engine-internal state the
rapid churn was corrupting (root cause not identified further — the fix
avoids the pattern entirely rather than working around a specific internal
sequencing).

## 3. A shared `SceneTree` across sequential test functions leaks state you don't expect

Godot test files structured as one `Node` script running several test
functions in sequence (`_ready() -> await _run()` calling each test
function one after another) all share **the same live scene tree** for the
whole run. A long-running earlier test (900 physics frames ≈ 15 real
seconds) can leave spawned entities alive well into a *later* test function
if those entities have a lifetime longer than the gap between tests (here:
projectile orbs with a 4-second lifetime).

A later test doing a naive `get_children()` search filtered only by group
membership (`is_in_group("boss_projectile")`) can pick up a **stale**
leftover from the earlier test instead of the one it just spawned — with no
error, just silently wrong data (confirmed by reading the stale orb's real
internal timer property directly: `2.15s` old, long past its own relevant
window).

**Fix pattern**: when a test spawns something identifiable, always filter
`get_children()` by a unique identifier scoped to *this* test's own
invocation (e.g. `child.get("volley_id") == this_volley_id`, a value read
back from the system under test at the moment this test triggered it) —
never trust group membership alone in a test file where earlier tests run
real physics frames and leave long-lived objects behind. See
`tests/distributor_behaviour_test.gd`'s `_test_orb_redirect_under_real_physics`
and `_test_pool_drain_under_real_physics` for the pattern in place.

## 4. Engine-reference version drift is a real, live risk — verify against ground truth, don't trust a stale doc

`VERSION.md` in this same directory claimed **Godot 4.6** for over five
months (since 2026-02-12) while the project was — and always had been —
pinned to **4.3** everywhere that actually matters: `project.godot`, CI's
`GODOT_VERSION`, and `CLAUDE.md`'s own title. `src/CLAUDE.md` and
`docs/CLAUDE.md` both instruct every session to trust this directory before
using any engine API — so a stale claim here was one `@abstract` decorator
away from shipping a hard parse error, the exact failure class the
Distributor boss actually shipped with once (see the header comment in
`tests/distributor_behaviour_test.gd`).

**Fix pattern**: this file's claim is corrected as of 2026-07-31 (see
`VERSION.md`). Going forward: before trusting any "pinned engine version"
claim in a doc, cross-check it against `project.godot`'s
`config/features`, the CI workflow's version string, and CLAUDE.md's own
title — three independent ground-truth sources that should always agree
with each other and with the reference docs. If they don't, the doc is
wrong, not the ground truth.
