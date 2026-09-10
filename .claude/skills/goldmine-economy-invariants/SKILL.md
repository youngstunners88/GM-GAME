---
name: goldmine-economy-invariants
description: Audit and regression-test the Gold Mine economy in src/autoload/goldmine_system.gd for value-conservation and name-matches-behavior invariants. Use before adding or editing ANY value-moving function, before wiring a new chamber to the economy, before any on-chain/Proof-of-Play work, and whenever a founder reports wrong balances, vanishing GOLD, or a reward that "paid nothing".
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Gold Mine Economy Invariants

The economy is a **simulation** today — the game is free-to-play, no real funds
are emitted to players or any pool. That is exactly why this skill exists: it is
the **value-accounting foundation** that on-chain wiring will later inherit. A
conservation bug that is harmless in a simulation becomes a mint exploit the day
it is connected to real value. Audit it as ledger code, not as gameplay code.

## Why this exists (the archetype bug)

`forfeit_to_auction()` reads like "credit the auction pool with the forfeited
amount". It actually does:

```gdscript
if amount > gold_balance:
    amount = gold_balance      # clamp to what the player holds
gold_balance -= amount         # DEBIT THE PLAYER
auction_gold_pool += amount
```

It is a **transfer out of the player's balance**, not a pool credit. Episode 2's
early-claim path called it to route GOLD the player had *never held* (the
unvested remainder), so the clamp silently swallowed the entire payout: a
half-vested 1000-GOLD miner was credited 499 and then lost all 499. **A
successful early claim paid nothing.**

Nothing was "wrong" locally — every line did what it said. The bug lived in the
gap between the function's **name** and its **contract**. That gap is what this
skill hunts, structurally, so the next one is caught by a gate and not by luck.

## The five invariant classes

### I1 — Value conservation
Total value across `gold_balance + auction_gold_pool + (staked//escrowed) +
(burned) + (settled)` is constant across any operation **except** an explicitly
designated mint or burn. No operation may create or destroy value as a *side
effect* of doing something else.

Practical form: snapshot every balance before an operation, apply it, and assert
`delta_total == expected_mint - expected_burn`, where both expectations are
declared by the test, not read back from the code under test.

**Known gap:** `settle_auction()` sets `auction_gold_pool = 0` with no burn
ledger, and `reset_session()` zeroes everything. Both are intentional, but there
is no counter recording the destroyed amount, so conservation across those calls
is **unverifiable by construction**. Treat any new sink the same way: if you
destroy value, record it.

### I2 — Name matches behavior
Every value-moving function must do exactly what its name and docstring claim.
For each one, write the assertion from the *name* first, then run it. Divergence
is a finding even when the code is self-consistent.

Two live examples in this file:
- `forfeit_to_auction` — name implies a pool credit; it is a player debit.
- `forfeit_to_auction`'s docstring claims *"50% of remainder after LP match goes
  to Strategic Reserve, 50% is melted"* — the code implements **no split at
  all**; it moves 100% to `auction_gold_pool`.

### I3 — Clamping is intentional, and in the right direction
Every `clamp`/`clampi`/`clampf`/`min`/`max`/guard on a value transfer must be
proven to be the correct bound. Ask of each one: *what does this silently
swallow, and is swallowing it correct?* A clamp that protects an invariant is
good; a clamp that hides a caller's mistake is a clawback.

The repo already contains both patterns side by side — compare and prefer the
first:
```gdscript
# GOOD — stake_diamonds(): clamps to holdings, negative input becomes 0
amount = clampi(amount, 0, diamonds_balance)
if amount <= 0: return 0

# WEAKER — stake_in_fort_knox(): guards the upper bound only
if amount > gold_balance: return 0     # negative amount passes straight through
```

### I4 — Sign discipline (no negative-amount value creation)
Every public value-moving function must reject or clamp negative amounts. An
unguarded `-=` with a negative argument is a **mint**. Test every entry point
with a negative amount and assert no balance increases and no lifetime counter
decreases.

Lifetime counters (`lifetime_gold_mined`, `lifetime_diamonds_burned`) are
monotonic by definition — assert they never decrease, ever.

### I5 — Caller-supplied numbers are untrusted input
Any parameter that is not derived from the system's own state is attacker
input on a web/mobile export. Each must be bounded against real state.

Live examples: `melt_gold(amount_to_melt, staked_amount)` mints
`fort_knox_shares` proportional to `staked_amount`, which is **never checked
against anything the player actually staked**; `settle_auction(user_contribution,
total_pool)` computes an **unbounded** `user_contribution / total_pool`
multiplier. Both are cross-referenced by `ep2-security-and-trust-audit`.

## Protocol numbers — sourcing rule

Every economic number comes from `src/autoload/goldmine_system.gd` constants or
`docs/whitepapers/GoldMine.md`. **A missing constant is a finding, never a
licence to invent one.** Two distinct failure modes, both real here:

1. **Constant declared but never used** — the rule it encodes is not enforced.
   Audit with the sweep below; current unused set: `MAX_MELT_BONUS_PCT`,
   `RESERVE_FORFEIT_SPLIT`, `CERT_PRICE_XAUT`, `STOCKPILE_LP_MATCH_PCT`.
2. **Magic number duplicating a constant** — `melt_gold()` hardcodes
   `bonus_pct = melt_ratio * 3.0` instead of deriving
   `MAX_MELT_BONUS_PCT / MAX_MELT_RATIO`. Correct today (9/3 == 3), silently
   wrong the moment either constant is retuned.

```bash
# Unused-constant sweep — run whenever a constant is added or a rule changes.
for c in $(grep -oP '^const \K[A-Z_]+' src/autoload/goldmine_system.gd); do
  n=$(grep -rIn --include=*.gd "$c" src/ tests/ \
      | grep -v "^src/autoload/goldmine_system.gd:[0-9]*:const" | wc -l)
  [ "$n" -eq 0 ] && echo "UNUSED: $c"
done
```

## Rule-to-code reconciliation table

Each row must be asserted by a gate, not assumed. "Where enforced" is the file
and function that actually implements it — `NOT ENFORCED` is a finding.

| Rule (white paper) | Constant | Where enforced |
|---|---|---|
| 100-day miner, 1%/day linear vest | `MINER_VESTING_DAYS = 100` | `src/episode2/chamber/miner_shaft.gd` (vest fraction × principal) |
| Early claim forfeits **only** the unvested remainder | — | `ep2_session_root.gd` commit path; `awarded + forfeited == principal` |
| 20% permanent Diamond burn | `DIAMOND_BURN_PCT = 0.20` | `collect_diamonds()`; chamber reads it live via `/root/GoldMineSystem` |
| Fort Knox lock ≤ 2,888 days, ≤100% term bonus | `MAX_TERM_BONUS_PCT = 1.00` | `stake_in_fort_knox()` — bonus clamps at 2888d; the **lock length itself is not rejected** above 2888 |
| Melt ≤ 3×, bonus ≤ 900% | `MAX_MELT_RATIO`, `MAX_MELT_BONUS_PCT` | `melt_gold()` clamps ratio; bonus cap only implicit via hardcoded `* 3.0` |
| Claim cert = 22,000 shares **+ 0.5 XAUT**, non-transferable | `CERT_SHARES_REQUIRED`, `CERT_PRICE_XAUT` | `_check_certificates()` checks shares only — **the XAUT price is NOT charged** |
| Weekly auction, no carry-over | — | `settle_auction()` zeroes the pool |
| Treasury split 50/20/20/10 | `TREASURY_*_PCT` | `distribute_treasury_revenue()` — computes all four; **only nft + auction are actually moved** |

## How to run an audit

1. **Enumerate.** List every function that reads or writes a balance, pool,
   share, or lifetime counter — including ones no chamber currently calls. The
   `forfeit_to_auction` bug proves untested paths hide value bugs.
2. **Per function, assert from the name**, then I1–I5 in order.
3. **Reconcile** against the table above; a `NOT ENFORCED` cell is a finding.
4. **Sweep** for unused constants and magic numbers.
5. **Failing-first regression.** For every finding, add the assertion to
   `tests/goldmine_economy_invariants_test.gd`, watch it fail, fix, watch it
   pass. A regression test that never failed proves nothing.

## The gate

`tests/goldmine_economy_invariants_test.gd` — deterministic, headless, exits
non-zero on failure.

```bash
.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
  res://tests/goldmine_economy_invariants_test.tscn
```

It calls `reset_session()` between cases so no case inherits another's balances
— the autoload is a singleton and leaks state across tests otherwise.

## Traps

- **`GoldMineSystem` is an autoload.** Headless tests reach it at
  `/root/GoldMineSystem`. Godot 4's `in` operator tests the *property* list, so
  `"DIAMOND_BURN_PCT" in gm` is **false** for a script `const` that is perfectly
  readable as `gm.DIAMOND_BURN_PCT`. Never gate constant reads on `in`.
- **`mine_gold()` calls `GameManager.add_score()`.** The economy is not
  self-contained; a test that stubs one autoload and not the other will fail
  confusingly.
- **Integer truncation vs rounding is inconsistent** across this file (`int()`
  in `melt_gold`/`stake_in_fort_knox`, `round()` in `collect_diamonds`/
  `award_wbtc`). Assert the exact expected integer, never a float comparison.
- **Run the sentinel after `git add`** — it scans `git ls-files`, so new
  unstaged test files are invisible to it.
