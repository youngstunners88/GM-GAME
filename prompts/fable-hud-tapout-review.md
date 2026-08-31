# Review task: does this diff actually fix what it claims to fix?

The founder reported (screenshots attached to my session, described below):

1. HUD text "PUFFS" should read "BLAZE DIAMONDS".
2. A genuine, repeated bug: "player collects first diamond (often via candle
   bounce), then the game/section resets, but the diamond stays already
   claimed" in Blaze Rush — reported multiple times across sessions, never
   actually fixed before now.
3. "EXIT" button should read "TAP OUT" with Lil Blunt's own face art placed
   next to it, to sell "this is too difficult / I'm out". Same click behavior.
4. HUD needs a "TOKENS" section distinguishing $TITANX/$DIAMONDS/$GOLD
   (protocol tokens) from "COINS" (chain currency: ETH stage1/SOL stage2/BTC
   stage3).

I (Claude, this session) diagnosed #2 by writing a real-physics reproduction
test that drove the actual player through the actual candle+diamond pair
(20px apart on every level's course) and got a **100% reproduction rate over
30 cycles** — the candle's crash handler resets state and teleports the
player, but the diamond's own `body_entered` signal — already queued by the
physics server before the crash — arrives ONE PHYSICS STEP LATE, after the
existing `_crash_pending` guard has already been cleared by the deferred
restore. My fix rejects any pickup where the player's real distance to the
token exceeds the token's own collision radius + a small slack — a stale
signal arrives with the player already teleported hundreds of px away, so
this catches it regardless of the exact signal-delivery timing, without
depending on guessing the precise ordering mechanism.

## Files
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/diff_blaze.txt
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/diff_coin.txt
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/diff_hud.txt
@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/diff_gm.txt

## Deliver
1. **Stale-pickup fix**: is the distance-based guard actually correct? Walk
   through the exact sequence: candle body_entered fires, `_crash()` resets
   `_smoke_this_attempt`/teleports the player, `_crash_pending=true`, deferred
   `_restore_tokens()` runs and sets `_crash_pending=false` — then the
   diamond's stale signal arrives. At that moment is `_player.global_position`
   ALREADY the post-teleport position, or could there be a frame where the
   distance check still reads the PRE-teleport position and lets the stale
   pickup through? Is `STALE_PICKUP_SLACK = 24.0` correctly justified, or too
   tight/loose against real player+token geometry? Any case where a
   LEGITIMATE pickup (e.g., a fast dash through, or two tokens stacked close
   together) could now be wrongly rejected?
2. **coin.gd credit routing**: I route stage1/2/3 branded pickups to
   `GameManager.add_titanx()` / `GoldMineSystem.collect_diamonds(1)` /
   `GoldMineSystem.mine_gold(1)` instead of `GameManager.add_coin()`, based on
   which stage's protocol logo the pickup is showing. Is there a scenario
   where `GameManager.current_level` could read the WRONG stage at the moment
   `_apply_stage_token()`/`collect()` run (e.g., mid-transition), causing a
   mislabeled credit?
3. **titanx_collected lifecycle**: I gave it the SAME persistence class as
   GoldMineSystem's gold/diamonds (survives `boss_contact_restart()`, only
   reset by `reset_session()`), reasoning it's a protocol token holding, not
   run currency like coins/rings/smoke. Do you agree with that classification,
   or should TitanX behave like coins instead (wiped on boss death)?
4. **TAP OUT layout**: `TextureRect.expand_mode = EXPAND_IGNORE_SIZE` is set
   because the source art is 585x586 native and would otherwise ignore
   `custom_minimum_size`. Anything else about the face-art wiring that looks
   fragile?
5. Any other bug you can find in these diffs, ranked by severity.

Be concrete, cite line context, no filler.
