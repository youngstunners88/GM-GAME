# Grok 4.6 — DESIGN ONLY. The wall fix worked and broke two other things. Audit the replacement design. Be blunt.

## Situation (all measured, real Godot 4.3 arena)

Boss 3 "Claim Jumper", BODY=280, origin=top-left, HALF_BODY=140.
Arena x 3700..4400. `_clamp_to_arena()` clamps CENTRE to [3724, 4376] and sets
`velocity.x = 0` on any frame it actually clamps.

Both arena walls (west seal, east end wall) used to be solid to the boss. That
was the freeze: with the player parked east he pinned with his right edge at
4390, velocity.x = 0, **frozen 13.05s of 15s**, centre stuck at 4250.

I moved BOTH walls onto a player-only collision layer. The freeze went away
(centre 4316, freeze 1.55s). But the full test suite then failed three gates
that had been green:

| gate | before | after |
|---|---|---|
| glued to player (<110px) over an 18s kite | 12.0% | **97.0%** |
| air-hop events, 40s kite | 11 | **0** |
| air-hop events, 16s pinned-at-wall scenario | 8 | **0** |

## Why (my analysis — challenge it)

1. HOP TRIGGER GONE. The only hop trigger is
   `want_hop = is_on_wall() or (at_ledge and _gap_crossable(direction))`
   plus a "player is >80px above AND `_higher_ground_ahead()`" case. The arena
   floor is flat, so with no wall contact `is_on_wall()` never fires and he
   never hops. **The double jump the founder demanded had been firing because
   of the wall-pogo bug.**

2. STANDOFF COLLAPSES vs A MOVING PLAYER. `_ground_chase(delta, speed,
   min_separation=200)` does: if `abs(dx) < min_separation`, set
   `target_vx = clamp(player_vx, -speed, speed)` (MATCH the player's velocity,
   deliberately neither stop nor retreat), plus a weak outward bias
   `-sign(dx) * speed * 0.25` only when `abs(dx) < min_separation * 0.6`.
   Against a stationary player this holds ~122px and the project's own
   separation gate passes. Against a player moving ~170px/s it tracks at
   whatever distance it arrived at — 97% inside 110px.
   Boss contact = instant full-run restart, so 97% glued is unplayable.

## Constraints you must respect
- Founder bans "ride on top of Lil Blunt" AND demands a visible double jump
  "when geometry needs it".
- Founder bans fixing chase by only adding standoff ("It is NOT a substitute
  for correct pursuit") and bans speed-only fixes.
- You already rejected, in an earlier packet, a 2s no-progress "vault" using
  `abs(dx)/delta` on one frame. Do not re-propose that.
- The clamp zeroes velocity.x, so any impulse must survive that.

## Deliver, concretely

A. HOP TRIGGER. What should replace `is_on_wall()` as the hop trigger so the
   double jump fires "when geometry needs it" on a FLAT arena floor, without
   re-introducing pogo? Is the honest answer "on a flat arena he correctly
   should NOT hop, and the founder's double-jump demand can only be satisfied
   by geometry that needs one"? Say so plainly if that is the truth.

B. STANDOFF vs MOVING PLAYER. Give the specific rule that keeps ~200px against
   a player moving at up to 240px/s in either direction, without (i) losing
   ground to a fleeing player, (ii) reversing into a retreat, (iii) camping.
   State it as a formula over dx, player_vx and speed. Name what it breaks.

C. Is it correct to have held this fix back rather than ship 97% glue to
   replace a 13s freeze? One paragraph, and say which is worse for a player
   given contact = instant run reset.

D. Rank what to do next in order, for a founder who has rejected ~50 attempts.
