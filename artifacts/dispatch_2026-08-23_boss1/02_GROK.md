# Grok 4.6 — DESIGN AUDIT ONLY. Be blunt. Two Level-1 P0s.

## Context
Level 1 is a FULL-STAGE HUNT: no arena seal, the Auditor (BODY 220, contact =
instant full-run restart via boss_contact_restart) chases the player across the
whole stage. Ground y=650, stage x 0..3400.

Prior rounds established (measured):
- Checkpoint carries an invisible solid 32x48 body ("StandSurface"). Solid → it
  both WALLS the boss (pins/pogos at x=2200 → "floating") AND is his STAIRCASE
  in the flee-west hunt. Remove it → boss strands at a breakable block. Make it
  one-way → considered before; concern was a boss resting on an invisible box.
- Raising LEAP -620→-630 fixed a 4px platform-clear deficit but regressed both a
  hunt gate (stuck 1335 frames) and a sky-float gate (2.8%→7.1%). Vertical
  impulse is not the fix.
- Two gates must BOTH stay green: hunt (fleeing player, whole route, boss must
  close) and sky-float (parked player, boss feet must stay near ground).

## Proposed fix set for the Auditor (critique it)
A. Checkpoint StandSurface → ONE-WAY collision (landable from above, passable
   horizontally). Boss can still use it as a staircase but is never walled by it.
B. Boss SMASHES breakable blocks he is pressed against (is_on_wall), no score,
   secret walls excluded — so the block lane never strands him.
C. Horizontal commit on every wall-leap (velocity.x toward player at takeoff) so
   a blocked leap travels sideways instead of pogoing straight up.
D. Progress timer: no horizontal progress for N seconds while player is beyond
   reach → vault toward player (leap + horizontal commit).
E. Leave LEAP at -620 (do NOT raise it).

## Second P0: player soft-lock at stage end
Three secret_walls (flavor "smoke tip" easter eggs) float at y=586 (head height)
ON the ground corridor at x=468/1368/2768. A walking player is walled by them;
a jump clears them, but on a hunt return with a floating boss the player reports
being trapped at the end, unable to return west. Proposed: REMOVE the three
secret walls from Level 1's corridor (they're flavor; boss also needed collision
exceptions for them).

## Deliver
1. Does fix set A–E make BOTH gates green in principle, or is there a specific
   scenario where A (one-way) + B (smash) still stalls him? Name it.
2. The one-way StandSurface "boss resting on an invisible box" worry: at a
   checkpoint (top y=500, ground y=650) the box top is 150px up. Is a boss
   briefly standing there actually a "sky float" a founder would screenshot, or
   is that overblown vs the alternative (removing his staircase)? Give a verdict.
3. Is C's horizontal-commit safe, or does it reintroduce the runaway-climb /
   erratic-landing that an earlier round fixed with a height cap? How do C and
   the height cap coexist?
4. Removing the 3 secret walls: any downside beyond losing flavor? Could it
   break the boss collision-exception code or any gate that expects them?
5. Rank the 5 boss fixes by necessity — which are load-bearing for BOTH gates,
   which are optional polish?
