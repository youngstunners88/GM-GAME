<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/fable-hud-tapout-review.md
     files inlined: 4
     tokens: 10670 in / 8602 out
     cost: $0.5368
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Review

## 1. Stale-pickup distance guard

**The core logic is sound, but only because BOTH guards are kept — and I can't fully verify the ordering without `_crash()` / `_reset_player()` / `_restore_tokens()`, which are not in the diff.**

Two delivery timings matter:

- **Same-flush delivery** (diamond's `body_entered` delivered in the same physics flush, immediately after the candle's): if the teleport is deferred (typical, since you often can't safely move bodies inside a physics callback), `_player.global_position` is still the PRE-teleport position at that moment and the distance check **passes**. This case is caught only by `_crash_pending` still being `true`. Your diff keeps `and not _crash_pending`, so it's covered — but note the distance check alone would NOT have been sufficient.
- **Next-step delivery** (your 30/30 repro case): the deferred restore has run, so `_crash_pending` is false — but the deferred teleport must also have run by then. **This holds only if `_reset_player()` is applied no later than `_crash_pending` is cleared.** If `_crash()` defers them in the order restore-then-reset, or the teleport is a further-deferred tween/animation, there's a window where `_crash_pending == false` but position is still pre-teleport, and the stale pickup gets through. **I need `_crash()`'s body to confirm the deferred-call ordering.**

**`STALE_PICKUP_SLACK = 24.0` — the arithmetic in the comment is wrong and the value is borderline-tight:**

- Comment says "PLAYER_SIZE=28 -> ~12px". 28/2 = **14**, not 12.
- Worst legit case: corner contact of a 28×28 player rect against the 26px circle → center distance ≈ 26 + 19.8 (half-diagonal) ≈ **45.8px** at first overlap. One step of delivery delay adds ~5.3px at RUN_SPEED=320 — **more if the player is falling** (gravity/jump speeds aren't in the diff; vertical speed can easily exceed 320). That's ≥51px vs a `claim_radius` of 50. A corner-clip pickup mid-fall **can be legitimately rejected**.
- Since your own analysis says the stale case arrives "hundreds of px" away, tightness buys nothing. **Raise slack to ~48–64.** Also verify RUN_SPEED is constant — if Blaze Rush accelerates over the run, the per-step travel term grows.

**Residual false-positive case for the guard itself:** if any level places a token within ~50px of the respawn point, a stale signal arriving post-teleport passes the distance check. The one cited pair (x413–427/x414–466 vs respawn x=0) is safe, but check all layouts.

**Missing:** `tests/blaze_diamond_bounce_repro_test.gd` isn't provided. Run it against the fixed build (should be 0/30), and add a regression test for a legit high-speed corner-clip pickup at current slack.

## 2. coin.gd credit routing

- **Cannot verify `GoldMineSystem.collect_diamonds(int)` and `GoldMineSystem.mine_gold(int)` exist with those signatures** — GoldMineSystem isn't in the provided files. If either is missing or has different args, `collect()` crashes at runtime on stages 2/3. Confirm before merge.
- The `_credit_target` cache is the right pattern: face and credit are decided from the same `current_level` read, so even if `current_level` is stale mid-transition, the face and the credit **stay consistent with each other** (wrong-but-matching beats mismatched). The real question — does the level scene set `GameManager.current_level` before its coins' `_ready()`/`_apply_stage_token()` run? — can't be answered from these files. Show me where `current_level` is assigned during level load.
- **Scoring inconsistency:** stage-1 pickups now credit `add_titanx()` which itself does `add_score(15)`, on top of `collect()`'s `ComboSystem.add_score(10)`. Stages 2/3 route through GoldMineSystem, whose score behavior is unknown. Stage-1 pickups are likely worth more than stage-2/3 pickups for no design reason. Also check whether the old `add_coin()` added score — if so, all stages' scoring changed.
- **Economy side effect:** `coins_collected` no longer increments on stages 1–3 at all. Anything gated on coin count (extra lives, unlocks, achievements) silently breaks on the entire main game. Grep for consumers of `coins_collected`/`coins_changed`.

## 3. titanx lifecycle

The classification is internally consistent, **but it has a consequence you buried:** combined with the coin.gd routing, **every standard pickup on stages 1–3 is now boss-death-proof** (titanx/diamonds/gold all survive `boss_contact_restart()`). Your own comment in `boss_contact_restart()` says the forfeit-everything behavior exists because the founder "kept reporting" missing stakes. This diff quietly reverses that fix for the primary collectible on all three stages — only rings/smoke/score are still forfeit. That's a founder-level design decision, not a code call. **Flag it explicitly to him; do not merge silently.**

Minor: `load_session()` sets `titanx_collected` but doesn't emit `titanx_changed`, so the HUD shows "TITANX 0" after a load until the next pickup — unless there's a bulk re-emit elsewhere (not shown; the excerpt doesn't emit for coins/smoke either, so confirm the existing pattern).

## 4. TAP OUT layout

- `EXPAND_IGNORE_SIZE` + `custom_minimum_size` + `STRETCH_KEEP_ASPECT_CENTERED` is the correct Godot 4 combination; the reasoning about native-resolution minimum size is accurate.
- **`preload("res://src/assets/sprites/sprite_lil-blunt_tapout.png")` — I cannot confirm this asset exists.** If it doesn't, the preload fails at script load and **the entire blaze_rush.gd script fails to compile**, killing the whole mode, not just the button. Verify the file is committed (and its `.import`).
- The face is a separate non-interactive sibling — clicking the face does nothing. Spec says "same click behavior"; strictly the button behaves the same, but a player will click the face. Consider wrapping face+button or setting the face's `mouse_filter = IGNORE` at minimum so it doesn't swallow clicks.

## 5. Other issues, ranked

1. **(High)** Unverifiable `GoldMineSystem.collect_diamonds`/`mine_gold` calls — potential runtime crash on stages 2/3 (§2).
2. **(High)** Boss-death stakes silently removed for stage 1–3 pickups (§3).
3. **(High)** Unverified `sprite_lil-blunt_tapout.png` preload — script-load failure kills Blaze Rush entirely if missing (§4).
4. **(Med)** `STALE_PICKUP_SLACK` too tight for corner-clip/falling pickups; comment math wrong (14 not 12) (§1).
5. **(Med)** `coins_collected` starvation on stages 1–3; audit consumers (§2).
6. **(Med)** Deferred-call ordering in `_crash()` unverified — the distance guard's correctness for the next-step case depends on teleport-before-flag-clear (§1).
7. **(Low)** HUD grouping: `SmokeLabel` ("BLAZE DIAMONDS", run currency) and `PowerUpLabel` sit visually under the new "TOKENS" header with no closing/COINS header — the founder asked for a TOKENS vs COINS distinction, and the diff only adds one header. Also nothing labels coins per-chain (ETH/SOL/BTC); if that was intended as HUD text, it's not implemented.
8. **(Low)** `_on_titanx_changed` may never fire after `load_session()` — stale "TITANX 0" (§3).
9. **(Low)** Conflating pickup $DIAMONDS with GoldMineSystem's mined diamonds may unbalance whatever the GoldMine mechanic economy is — depends on GoldMineSystem internals (not provided).

**Verdict:** #1 (label) and #3 (TAP OUT, pending asset check) are done. #2's fix is plausibly correct but hinges on unverified `_crash()` ordering and a slack constant with an arithmetic error. #4 is functional but has two unverified external dependencies (GoldMineSystem methods, `current_level` timing) and one major undisclosed design consequence. Send me `_crash()`/`_reset_player()`/`_restore_tokens()`, GoldMineSystem's API, and confirmation the tapout sprite is committed before this merges.