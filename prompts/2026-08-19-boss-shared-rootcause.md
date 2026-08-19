# Lil Blunt Adventure — Boss "does not move" root-cause review (Godot 4.3, GDScript)

The founder reports, furiously and repeatedly, that the Stage 1, Stage 2 and Stage 3
bosses DO NOT MOVE / DO NOT CHASE in the live game. Multiple prior repair sessions
tuned speeds, accelerations, standoff distances and "climb locks" and the complaint
persisted every time. Treat all in-file comments claiming a chase bug was already
fixed as SUSPECT — they are the record of failed attempts.

## Hard evidence gathered this session (trust this over the code comments)

Headless instrumentation drove a REAL kiting player (240 px/s, wall to wall) inside
each real boss arena and sampled the full pursuit pipeline at 4 Hz for 9 s:

    STAGE 1 Auditor      tracking_score -0.20   x_span 250 px   frozen 33%   arena bounds: NONE (0,0)
    STAGE 2 Distributor  tracking_score +0.56   x_span 460/460  frozen 28%   clamped_at_wall 28%
    STAGE 3 Claim Jumper tracking_score +0.39   x_span 396/420  frozen 17%   clamped_at_wall 0%

(tracking_score: +1 = boss moves the same direction as the player, 0 = uncorrelated,
-1 = consistently moves away.)

So with the player INSIDE the arena, bosses 2 and 3 track well. Boss 1 does not.

Separately, photogrammetric analysis of the founder's own screenshots established:
- Stage 2 screenshot: the PLAYER is at world x ~3109, which is 591 px WEST of
  boss_arena.start_x = 3700. The boss is hard-pinned at his west clamp (measured
  world x ~3813; his clamped reachable centre range is [3820, 4280]).
- Stage 1 screenshot: the player has retreated ~900 px west; the boss never left the
  arena mouth.

Arena facts:
  level 01 boss_arena = {start_x 2800, end_x 3400}; the Auditor is given NO arena
      bounds at all by level_01_smoke_realm.gd (arena_min/arena_max stay (0,0)).
  level 02 boss_arena = {start_x 3700, end_x 4400}; Distributor BODY 240 ->
      reachable centre [3820, 4280] (460 px of a 700 px arena).
  level 03 boss_arena = {start_x 3700, end_x 4400}; Claim Jumper BODY 280 ->
      reachable centre [3840, 4260] (420 px of a 700 px arena).
  A "seal wall" is raised behind the player when they enter the arena, but it is
  REMOVED again whenever the player goes back west of start_x - 40 (this exists to
  avoid a soft-lock: checkpoints sit west of every arena, so a player who dies
  mid-fight respawns outside a wall that is already up).
  Boss contact = GameManager.boss_contact_restart(), an INSTANT full-run restart
  (score/coins/rings zeroed, level reloaded) — not a hit.

## Your task

1. Confirm or refute this proposed SHARED root cause: the player can be outside the
   boss arena while the fight is live, and every boss is clamped strictly inside the
   arena, so the boss freezes against a clamp and the founder perceives "the boss
   does not move". Attack this hypothesis; say what it fails to explain.
2. Explain Stage 1's NEGATIVE tracking score specifically. Note auditor.gd's CHARGE
   state uses `charge_target` captured ONCE on state entry, and its VULNERABLE state
   runs `velocity.x = move_toward(velocity.x, 0.0, 200.0)` with NO delta scaling.
3. Propose the MINIMAL SHARED fix, not three stage-specific hacks. Consider: should
   the seal be un-droppable while the boss lives (and how then to avoid the
   respawn soft-lock it was deleted to prevent)? Should the boss's clamp follow the
   player outside the arena? Should the fight suspend/reset when the player leaves?
4. Boss speeds are 290-385 px/s vs a 240 px/s player top speed, and contact is an
   instant run-wipe. Is that combination survivable at all? If a boss is strictly
   faster than the player and touching him wipes the run, what is the intended
   counter-play, and what should change so the fight is hard but fair?
5. The Stage 3 boss is ALSO reported "way too easy to defeat". Reconcile that with
   "does not move" — is the player killing a wall-pinned boss from safety?

FORBIDDEN in your proposals: teleporting bosses, infinite detection range, disabling
collisions, bypassing state machines, arbitrary speed boosts, fake chase movement,
removing mechanics to make tests pass.

Cite exact file:line. Be concrete and specific. Disagree with the hypothesis if the
code says otherwise.

## Source

@include src/boss/auditor.gd
@include src/boss/distributor.gd
@include src/boss/claim_jumper.gd
@include src/boss/boss_base.gd
