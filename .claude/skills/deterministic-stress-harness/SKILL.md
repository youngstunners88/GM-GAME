---
name: deterministic-stress-harness
description: Seeded, reproducible stress/fuzz/soak testing for the Episode 2 loop and the Gold Mine economy. Use after any change to the session root, a chamber, or a value-moving economy function; before adding a new chamber; and whenever a bug is suspected to be intermittent, timing-dependent, or only visible after many cycles.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Deterministic Stress Harness

The existing Episode 2 gates prove single, hand-written scenarios. This skill
extends them into **seeded** long-run and adversarial testing — the class of bug
that only appears on cycle 400, or under an input order nobody thought to write
by hand.

Non-negotiable: **a stress test that cannot be reproduced is a rumor, not a
finding.** Every run is driven by an explicit seed, and every failure prints the
seed and the exact operation sequence that produced it.

## Seeding contract

```gdscript
var _rng := RandomNumberGenerator.new()
_rng.seed = SEED          # fixed default; override with --seed=N

# On ANY failure, before anything else:
print("REPRO: seed=%d step=%d op=%s" % [SEED, i, op_name])
```

Rules:
- Never call the global `randi()`/`randf()` — they are not seeded per-run and
  make the suite irreproducible. Use the local `RandomNumberGenerator` only.
- The default seed is committed and fixed so CI runs the identical sequence
  every time. Randomizing the default converts a regression gate into a flaky
  one.
- A failure's seed + step index must be enough to replay it exactly. If it
  isn't, the harness is under-instrumented — fix that before chasing the bug.
- When a seed finds a real bug, that seed becomes a **permanent named case**
  in the gate, alongside the fix. Fuzzers find bugs once; regression cases keep
  them found.

## The three suites

### S1 — Soak (drift)
Thousands of runner↔chamber cycles. Assert, comparing end to start:

| Metric | Expected | Why it matters |
|---|---|---|
| Economy totals | **exact zero drift** with `commit_to_economy = false` | any drift is a leak in the commit boundary |
| Orphan node count | exact zero growth | guard #3/#5 — a scene not freed is a mobile OOM |
| Active scenes | exactly 1 | two live 3D scenes is the memory failure mode |

Zero drift means *exact integer equality*, not "close". Economy values are ints;
there is no rounding excuse.

Node counting must run **after** a `process_frame` — `queue_free()` is deferred,
so counting immediately after a swap always over-reports and looks like a leak.

### S2 — Adversarial input
Drive illegal and hostile sequences and assert the system refuses them without
crashing or paying out:
- Verb spam every frame (jump/duck/shoot/claim) regardless of mode.
- Out-of-order transitions: claim before rig start, shoot after resolve, lane
  switch while ziplining, `setup()` mid-run.
- Simultaneous events on one frame: full-vest tick landing on the same frame as
  an Early Claim pull; `chamber_reached` twice.
- Rapid re-entry: fail → immediately retry, repeatedly.
- Mid-action interrupts: `queue_free()` the active scene mid-step.

The assertion is usually **"nothing happened"** — no extra commit, no balance
change, no crash. Assert the absence explicitly by snapshotting state; a test
that merely survives proves nothing.

### S3 — Economy fuzz
Randomized-but-bounded sequences over every value-moving function
(`mine_gold`, `collect_diamonds`, `award_wbtc`, `melt_gold`,
`forfeit_to_auction`, `settle_auction`, `stake_in_fort_knox`, `stake_diamonds`,
`add_blaze_diamonds`, `crush_blaze_diamonds`, `distribute_treasury_revenue`,
`on_player_death`). After **each** operation, re-assert every invariant from
`goldmine-economy-invariants`.

Include the hostile end of the domain deliberately — negatives, zero, values
above the player's holdings, and `int` extremes. Those are exactly where the
sign-discipline (I4) and untrusted-input (I5) bugs live, and a fuzzer that only
samples sane positive values will never reach them.

Bounded means bounded in *magnitude* (so `int` overflow isn't the only thing
found), never bounded to *valid* values only.

## Runtime budget

The whole suite must finish inside the headless time limit. Practical shape:
- Soak: cycles are cheap when driven by `step()` — no rendering, no real clock.
- Prefer many short cycles over few long ones; the loop boundary is where the
  bugs are, not the middle of a run.
- **Warm `.godot/` first.** A cold `--headless` run imports ~1200 assets before
  the first assertion and will SIGTERM under a naive timeout. This has bitten
  this repo before:

```bash
# Once per container, before any gate:
.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --import
```

Use `--import`, not `--editor --quit`: the latter quits mid-scan and leaves the
cache empty (0 files imported) while appearing to succeed.

## Test assets never enter the pack

Stress fixtures, seed corpora and reproduction artifacts live under `tests/`,
which `export-game.yml`'s `exclude_filter` already drops from `index.pck`.
Never place a fixture under `src/` — the pack budget is 190 MiB with single-digit
MiB of headroom, and `export_filter="all_resources"` sweeps in everything under
`res://` that Godot recognizes.

## Reproduction artifact

On failure the harness must emit a block that can be pasted straight into the
gate as a permanent case:

```
REPRO seed=1337 step=412 op=melt_gold(-100, 50)
  pre : gold=0 pool=0 shares=0
  post: gold=100 pool=0 shares=50      <-- INVARIANT I1 VIOLATED (mint)
```

## The gates

```bash
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
$G --headless res://tests/ep2_stress_soak_test.tscn
$G --headless res://tests/goldmine_economy_fuzz_test.tscn
```

Both exit non-zero on failure and print `REPRO:` lines for every violation.
