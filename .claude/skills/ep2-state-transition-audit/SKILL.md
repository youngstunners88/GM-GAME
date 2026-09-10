---
name: ep2-state-transition-audit
description: Audit the Episode 2 persistent-session-root architecture — the runner↔chamber swap, the five rail-#5 guards, and the rule that economy commits happen ONLY in the session root, exactly once per resolved chamber. Use when adding a chamber, editing ep2_session_root.gd, changing any transition or signal wiring, or when a founder reports a double reward, a lost reward, a wrong resume position, or a soft-lock after a chamber.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Episode 2 State-Transition Audit

Episode 1 had no persistent root: levels were self-contained and a bug cost you
a jump. Episode 2's runner↔chamber loop introduces transition, re-entrancy and
double-commit bugs that simply could not exist before — and because chambers
move value, those bugs are accounting bugs, not gameplay bugs.

This skill audits `src/episode2/session/ep2_session_root.gd` and every scene it
swaps between.

## The architecture rule this defends

> **Economy commits live in the session root, never in the disposable chamber
> scene.** The chamber *computes* its outcome and emits it; the root *commits* it.

This is not stylistic. **A scene that credits itself cannot be made idempotent
by its caller.** Idempotency requires a single owner of the commit decision that
outlives the thing being committed. `miner_shaft.gd` therefore never touches
`GoldMineSystem` — it emits `chamber_cleared(result)` and stops.

When auditing a new chamber, the first check is: *does this scene import,
reference, or write `GoldMineSystem` anywhere?* If yes, that is a finding before
any behavior is examined.

```bash
# Every chamber must come back empty.
grep -rn "GoldMineSystem\|mine_gold\|forfeit_to_auction\|auction_gold_pool" \
  src/episode2/chamber/ || echo "clean — chambers touch no economy"
```
(The one legitimate exception in `miner_shaft.gd` is a **read-only** lookup of
`DIAMOND_BURN_PCT` so the burn rate can't drift from the real constant. Reads
are fine; writes are the violation.)

## The five rail-#5 guards

Each must be asserted **individually** — a test that only exercises the happy
path proves none of them.

| # | Guard | Mechanism | Failure it prevents |
|---|---|---|---|
| 1 | Double-triggered rewards | `_rewarded_chambers` keyed by `_chamber_segment` | A chamber pays out twice |
| 2 | Stale input | verbs routed by `_mode`; hard no-ops during `TRANSITION` | A button pressed on the runner's last frame drives a half-loaded chamber |
| 3 | Duplicate player | `_teardown_active()` frees and NULLs before instantiating | Two player-bearing scenes alive at once |
| 4 | Wrong resume position | `_completed_distance` banked **before** teardown | Track restarts at 0 after a chamber |
| 5 | Mobile memory | outgoing scene `queue_free()`d, never hidden | Two 3D scenes resident → phone OOM |

### Guard 1 has a subtlety that already bit us

The reward key must be **the segment the chamber belongs to**, captured at
entry — not the root's current `_segment`. `_advance_segment()` increments
`_segment` as part of handling the first payout, so a duplicate signal arriving
afterwards is attributed to the *next* segment, finds no flag, and pays again.

```gdscript
var owner_segment: int = _chamber_segment          # captured at _enter_chamber()
if owner_segment < 0 or _rewarded_chambers.has(owner_segment):
    return
_rewarded_chambers[owner_segment] = true
```

Both branches need separate coverage: `< 0` catches a **late** duplicate (after
`_chamber_segment` is cleared), `has()` catches a **re-entrant** one. A test that
only drives the late case leaves the per-chamber flag unproven.

### What is NOT a reachable failure mode

Connecting the same callable to `chamber_cleared` twice does **not** reach the
guard — Godot refuses a duplicate connection outright ("Signal is already
connected to given callable"). Don't write a test that claims to prove the guard
that way; it passes for the wrong reason. Drive the handler directly instead.

## Required assertions

**Commit-exactly-once**
- One resolve → exactly one `chamber_committed`, and totals match the principal.
- Re-entrant duplicate → still one commit.
- Late duplicate after `_advance_segment()` → still one commit.
- Two segments in a plan → chamber 2's payout is **not** suppressed by chamber
  1's flag (this is why the guard is a keyed dict, not a bool).

**No-partial-on-failure**
- Player dies mid-vest → `chamber_failed`, **zero** economy writes, balances
  byte-identical to pre-entry.
- Run fails in the runner → no chamber ever loads, no commit.
- Assert the *absence* of a write by snapshotting `GoldMineSystem` before and
  after, not by trusting that no signal fired.

**Re-entrancy / lifecycle**
- enter → fail → retry the same segment.
- `chamber_reached` fires twice (guard: `_mode != Mode.RUNNER` early-return).
- `setup()` called again on a reused instance clears **every** terminal flag —
  a stale `_resolved`/`_running` makes every later `step()` a silent no-op
  (the runner's Kimi-audit #5c class of bug; both scenes carry the same risk).

**Node/state hygiene**
- After a full loop, `get_children()` contains exactly one active scene.
- Node count returns to baseline across N cycles (feeds
  `deterministic-stress-harness`).

## How to drive it headlessly

Both the runner and the chamber expose `step(delta)` specifically so a gate can
advance the sim deterministically without a frame clock. The root forwards to
whichever scene is active. Always drive in fixed `1.0/60.0` increments; a coarse
step can skip a whole window (a 12m zip segment at `RUN_SPEED = 12` is ~1s wide).

Use `commit_to_economy = false` for loop-shape tests so the gate never mutates
the real `GoldMineSystem` singleton and leaks GOLD into another test in the same
headless run. Test the commit path separately, against an explicitly-read
baseline.

## Trap: the chamber's own combat can end the test early

`_plan_one()` ships a bear at `z = 6.0`. Once the rig starts, it reaches the rig
in ~4.4s and lands a hit every 2s — the player is dead ~8.4s in, well before a
22.5s half-vest. A test that starts the rig and then steps 22.5s will get
`chamber_failed` and **no payout**, which looks like a commit bug and is not.
Clear the bear first (`BEAR_HP` shots) when measuring vest/payout behavior.

## The gate

`tests/ep2_session_root_test.gd` (loop shape + guards) and
`tests/ep2_miner_shaft_test.gd` (chamber mechanics).

```bash
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
$G --headless res://tests/ep2_session_root_test.tscn
$G --headless res://tests/ep2_miner_shaft_test.tscn
```

Both exit non-zero on failure. Warm `.godot/` with `--headless --import` first
or a cold run can SIGTERM during asset import before a single assertion runs.
