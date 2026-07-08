# Blaze Rush — Secret Geometry-Dash Runs

**Status**: Implemented (v1)  
**Modules**: `src/dashmode/` (portal, run scene, layouts), `GameManager` (SMOKE currency, unlock persistence)  
**Inspiration**: Geometry Dash's one-tap auto-runner flow — proven addictive on mobile.  
**Requested by**: Client (Rich) direction — secret unlockable dash moments per level, crypto-congruent.

---

## Overview

Each of the three levels hides one **Blaze Portal** — a shimmering smoke ring that
stays locked until the player has accumulated enough score. Entering an unlocked
portal launches a **Blaze Rush**: a Geometry-Dash-style auto-runner where Lil Blunt
compresses into a glowing SMOKE cube and rockets through a neon corridor. One tap
to jump, instant restart on crash, pure rhythm-flow.

Crypto congruence:
- Collectible in runs = **$SMOKE tokens** (new persistent counter, 💨 in HUD).
- Obstacles = **red candles** (market-dip spikes) and **FUD walls** — market
  hazards, NOT weed-themed, per global enemy rules.
- Finishing a run pays **GOLD** (GoldMine); a **flawless** first-try run pays
  **Diamonds** through `GoldMineSystem.collect_diamonds()` — so the whitepaper's
  20% Diamond burn applies even to bonus rewards. Every reward flows through the
  existing GOLD / Diamonds / $SMOKE economy.

## Player Fantasy

"I got so many points the level cracked open a secret — now I'm in a neon smoke
tunnel going full FOMO-rocket speed." Skill expression + secret discovery + a
rhythm-game palate cleanser between platforming.

## Detailed Rules

### Unlock
- Portal spawns per level (position in level script `_setup_blaze_portal()`).
- Locked state: dim ring + "??? PTS" hint. No interaction.
- Unlocks when `GameManager.total_score + ComboSystem.current_score >= threshold`
  (both score systems count — collectibles feed either).
- Thresholds: Level 1 = 1,500 · Level 2 = 2,500 · Level 3 = 4,000.
- Unlock is instant + audible + screen-shake; portal brightens and pulses.
- Once cleared, the portal shows a ✓ state; re-entry allowed (replay for SMOKE,
  but completion GOLD/Diamond bonuses pay once per session).

### Run (auto-runner)
- Lil Blunt auto-runs right at 320 px/s. Gravity 2200 px/s². Jump = −700 px/s.
- ONE input: tap anywhere / Space / W / existing `jump` action. No double jump.
- Cube rotates 180° per jump (Geometry Dash signature feel).
- Crash (candle, FUD wall, pit) → instant restart at run start. Attempt counter
  increments. SMOKE collected that attempt resets. No health loss, no GOLD
  forfeiture — the Rush is a bonus realm outside GoldMine death rules.
- Reach the exit ring → rewards, then return to the level at the portal.

### Rewards
| Event | Reward |
|---|---|
| SMOKE token pickup (in run) | +1 to the attempt's 💨 counter (lost if you crash — banked only at the finish line) |
| Run completed | attempt's SMOKE banked to persistent 💨 total + 10 score each (no combo break); +5 GOLD (`mine_gold`) once per level per session |
| Flawless (attempt 1, no crash) | `collect_diamonds(5)` → 4 after 20% burn, once per level per session |

## Formulas
- `unlock_ready = GameManager.total_score + ComboSystem.current_score >= threshold`
- Completion score payout = `smoke_this_run * 10`
- Diamond payout = `floor(5 * (1 - DIAMOND_BURN_PCT)) = 4` (burn logic lives in GoldMineSystem)

## Edge Cases
- Player dies in the main level BEFORE entering: portal state persists (score
  doesn't reset on respawn, only on session reset).
- Re-entering a cleared portal: SMOKE + score still collectible; GOLD/Diamond
  one-time bonuses suppressed via `GameManager.blaze_rush_completed`.
- Pause works inside runs (StateMachine PLAYING state, pause menu overlays).
- Session reset (`reset_session`) clears SMOKE, completions, and portal unlocks.

## Dependencies
- `SceneRouter` (scene swap in/out of run)
- `ComboSystem` (score + launcher postMessage)
- `GoldMineSystem` (GOLD + Diamond payouts, burn)
- `GameManager` (SMOKE persistence, return-trip bookkeeping)
- `AudioManager` ("powerup"/"coin" SFX reused; dedicated track later)

## Tuning Knobs
All in `src/dashmode/blaze_rush.gd` consts + `blaze_rush_layouts.gd`:
`RUN_SPEED`, `GRAVITY`, `JUMP_VELOCITY`, per-level `LAYOUTS` obstacle arrays,
`UNLOCK_THRESHOLDS` (in level scripts), reward constants.

## Acceptance Criteria
- [ ] Portal appears locked in each level; unlocks at threshold with feedback
- [ ] Entering unlocked portal loads the run; tap/jump controls respond on mobile + keyboard
- [ ] Crash restarts instantly at x=0 with attempt counter increment
- [ ] SMOKE HUD counter (💨) updates live during runs and persists in saves
- [ ] Completion returns player to source level at the portal position
- [ ] GOLD/Diamond one-time bonuses pay exactly once per level per session
- [ ] Diamond bonus routes through collect_diamonds (burn observable in totals)
