# Two numeric verification tasks

## Task A — verify the stale-pickup distance fix with real numbers

A candle (hazard) and a diamond (collectible) sit 20px apart on every Blaze
Rush course (x=420 and x=440). Their Area2D collision shapes: candle is a
14x30 rectangle centred at x=420 (spans x=413-427); diamond is a
CircleShape2D radius=26 centred at x=440 (spans x=414-466). These GEOMETRICALLY
OVERLAP from x=414 to x=427.

The bug: touching the candle calls `_crash()`, which resets state and
teleports the player to x=0 SYNCHRONOUSLY. The diamond's OWN `body_entered`
signal — already queued by the physics server from before the crash — still
arrives, but one physics step late, after `_crash_pending` has already been
cleared by the deferred token-restore. A real-physics reproduction test
(driving the actual player through the actual pair, not a synthetic .emit())
showed this fires on **30 of 30** crash cycles — not a rare race, deterministic.

The fix: reject the pickup unless `player.global_position.distance_to(token
.global_position) <= token_radius(26) + STALE_PICKUP_SLACK(24) = 50px`.

@include /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/diff_blaze.txt

### Deliver
1. Player teleports to x=0.0 on crash (`_reset_player()`). Diamond is at
   x=440. Compute the exact distance at the moment of the stale signal and
   confirm it is far outside the 50px claim radius — show the arithmetic, not
   just "yes it's rejected".
2. Is 24px of slack (`STALE_PICKUP_SLACK`) enough margin for a LEGITIMATE
   pickup at the fastest realistic approach? Player is a ~24x24 box (after a
   4px inset) moving at up to ~430px/s (course speed ramps range
   320-430px/s across the three levels) — at 60Hz that's up to ~7.2px per
   physics frame. Could a fast, off-center graze at the very edge of the
   26px collision radius, arriving on a frame where the player's leading
   edge is up to ~7px past the boundary, ever exceed the 50px claim radius
   and get wrongly rejected? Show the worst-case number.
3. Any OTHER pair of hazard+collectible in the course data (grep the layout
   file's x-coordinates) where the same 20px-adjacency pattern repeats, and
   whether the same fix class covers it (it should, since the fix isn't
   candle-specific — confirm that's actually true from the diff, not assumed).

## Task B — Stage 2 boss chase, numbers only

Founder: "The boss in stage 2 is still not chasing!!!!" — reported AGAIN
after a prior session's real-physics-gated fix (verified 0/30 desyncs, deployed
to itch.io, confirmed via CI logs that the butler push actually succeeded).

@include src/boss/distributor.gd

### Deliver
4. State every pursuing phase's speed constant/scale as currently written in
   this file (not from memory of an earlier version) and confirm each one
   is >= 240 px/s (player's top sprint speed, walk 200 * sprint 1.2). Flag
   any phase that is NOT, with the exact number.
5. Is there any DIFFERENT reachable state in this file — not the ones
   already covered by a prior fix — where the boss's effective speed could
   read as "not moving" to a live player? Look specifically for: states that
   brake/stop, states gated behind a condition that might rarely evaluate
   false in practice, or any speed value that's conditionally overridden
   lower elsewhere in the file.

Numbers and verdicts. No prose padding.
