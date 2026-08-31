# SESSION 6 SHARED FACTS — Lil Blunt Adventure (Godot 4.3 GDScript 2D platformer)

You are a co-worker model advising on a specific change. You cannot run the
game. Be concrete, terse, and Godot-4.3-correct. Do NOT restate the codebase.

## Founder live complaints (from real play of the shipped build)
1. Diamond Vault "looks better but no real utility for diamonds collected."
   Wants a vault CHARACTER/clerk Lil Blunt talks to that asks: how many
   $DIAMONDS tokens to STORE/STAKE in the vault, and how many BLAZE DIAMONDS
   (from collections) to CRUSH — clamped by a stack limit from collections.
   Must feel like a gamified DIAMONDS protocol action, not a coin pile.
2. Stage 2 boss "still fires circles" — reads like Stage 1. Must fire diamonds
   + crystal/diamond shards ONLY (distinct geometry), and still chase.
3. Stage 3 boss "still only jumps in one spot" — must CHASE horizontally.
4. Fort Knox needs more development — deeper than one gold room.

## Current economy (src/autoload/goldmine_system.gd)
- `diamonds_balance` (int): $DIAMONDS tokens, collected via diamond_shard
  powerup (20% burn on pickup). `stake_diamonds(amount, days)` already exists
  (clamps 0..diamonds_balance, mints `diamond_shares`, 288d=base..2888d=2x).
- `gold_balance`, `fort_knox_shares`, `stake_in_fort_knox(amount, days)`.
- There is NO separate "Blaze Diamonds" counter yet. Blaze Diamonds are the
  diamonds collected in the Blaze Rush dash mode (src/dashmode/blaze_rush.gd).

## Current Stage 2 boss (Distributor) projectiles
- `_throw_shards()` fires ETH-orbs: boss_projectile.tscn (draws fx_dot.png
  recolored by `tint`), tint = ETH-blue (0.6,0.8,1.0,1.0), redirectable
  (Forced Distribution -> Pool Drain signature mechanic). THESE render as blue
  CIRCLES — this is what the founder calls "circles."
- `_throw_crystal_shards()` already fires a visually-distinct crystal: hides the
  base dot (tint alpha 0) and adds an angular Polygon2D shard child. This is
  the pattern to copy.
- Boss chases via `_hover_pursue` (works in gates).

## Current Stage 3 boss (Claim Jumper)
- Has `_ground_chase(delta, speed)`: sets direction toward player, moves
  velocity.x toward speed*direction, with a ledge-sense that zeroes velocity.x
  at a lip. Has a hop in PATROL: hops when on wall, or at a crossable ledge, or
  when player is >80px ABOVE and `_gap_crossable(direction)`.
- Suspected jump-in-place cause: when the player kites near/above the boss, the
  "player above" hop fires repeatedly; if dx < TURN_DEAD_ZONE (34px) direction
  isn't updated, so the hop carries little/no horizontal travel -> hops in place.
- Arena clamp + ledge suicide already fixed; must NOT regress ledge suicide.

## Hard constraints
- Web export MUST stay non-threaded. Never hardcode wallet/contract addresses.
- Godot 4.3: `var x := <Variant>` (e.g. from get_first_node_in_group()) is a
  HARD parse error — always type explicitly.
- Every fix needs a real-physics headless gate that FAILS on the pre-fix code.
