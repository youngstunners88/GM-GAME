# Claude's validation of Kimi's canister audit

Source: `docs/model-responses/2026-07-28-kimi-icp-audit.md`
(moonshotai/kimi-k3, 12,491 in / 15,923 out, $0.2763)

Model output is an INPUT. Every claim below was checked against the real files
before anything was changed.

## CONFIRMED and FIXED

| Finding | Verified how | Fix |
|---|---|---|
| **`withoutPriorRun` keeps the LATEST run, not the best** — a worse resubmission silently erases a better score | Read `leaderboard.mo:128`. It filters out the prior entry unconditionally, then appends. My own comment above it claimed "keep only a player's single best run" — **the comment was false** | Added `bestScoreFor`; `submit` now returns `accepted = false` when the new score does not beat the stored one. Comment corrected to describe what the function actually does |
| **`cooldowns` grows forever, O(n) per submit** | Read `touchCooldown`. It filters out only the *caller's* own entry, so every other principal's row is permanent. Principals are free to mint | Eviction added: entries whose cooldown has expired are dropped on every touch. An expired entry is semantically dead, so this costs nothing |
| **Trailing newline silently drops the LAST symbol every refresh** | `Text.trim(body, #char '}')` only strips `}` when `}` is the final character. With `...}\n` it strips nothing, so the last pair keeps its `}`, `parseFloat` returns null, and the tolerant-skip design swallows it | Whitespace is now trimmed *before* the brace trim |
| **`icp_backend.fetch_prices` latch inconsistency** | Read the three failure branches: non-200 latches, non-Dictionary body latches, wrong-shape `prices` did **not**. Confirmed at the third branch | Latches like the other two |

## CONFIRMED as a real risk, defended without full verification

**`parseFloat` overflow → `+inf` → `Float.toInt` trap.** `Float.toInt` is
`Prim.floatToInt`, a compiler primitive whose trap behaviour is not readable
from base source, so I could not confirm the trap itself here. The *premise* is
solid regardless: `parseFloat` accumulates with no magnitude bound and IEEE
doubles overflow to `+inf` rather than trapping, and `inf > 0.0` passes the old
guard. Added a `MAX_PRICE` ceiling, which is correct whether or not the
downstream call traps.

## ACCEPTED as accurate, NOT acted on

- **Consensus brittleness** (`status` and `body` survive `transform` verbatim).
  Correct and well-argued: our safety depends on the *provider* returning
  byte-identical responses, which is a property of the source, not of this
  code — and `setSource` can change the provider without a canister upgrade.
  The robust fix is canonicalising the body inside `transform`, which is a
  design change. Logged for the mainnet list, not done today.
- **Fixed cycle amount is sized for a 13-node subnet** — a liveness risk on a
  larger subnet, not a theft risk. Correct; deferred with the same reasoning.
- **First-come `claimAdmin` front-run window** on all three canisters. Correct.
  Mitigation is procedural: claim admin in the same script that deploys. Added
  to the deploy notes rather than the code, since the blast radius is
  delete-only by design.
- **`profiles` linear scan** in `player_registry`. Correct, fine at hundreds of
  players, a cycles concern at tens of thousands. Deferred deliberately.

## Corrections to Kimi

- It reported `player_registry.mo` as **trap-clean**, which matches my reading.
  Worth recording because the *original* kit prompt asserted this canister
  handles score submission; the corrected prompt fixed that, and the audit came
  back consistent with the real design. Evidence the prompt fix mattered.
- Line numbers are approximate (`~L252`) and drift from the real file. Useful
  as anchors, not citations.

## Notable
Zero hallucinations. No invented APIs, no invented file paths, no invented
Motoko stdlib functions. The `@include` fix is what made that possible — this
same prompt without inlined source would have produced guesses.

## Gates after the fixes
canisters rebuild · gdparse clean · export 0 script errors · icp-contract 13/13
· save-compat 18/18 · script-compile 106+71 · boss all pass · v1.0 5/5 ·
shooter 6/6 · sentinel 18/18.
