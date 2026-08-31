# Kimi K3 — Claim Jumper stuck/double-jump patch review

## Context
Godot 4.3 GDScript. The final boss (Claim Jumper, Stage 3) was reported stuck
near a minecart/TNT/"Hall of Blaze" area, unable to move past a ledge. He
already has a hop; a double-jump (air-hop) mechanism was added in a prior
session. This session found the SAME bug class already fixed on a sibling
boss (the Auditor, Stage 1): every wall/ledge contact re-arms a fresh
hop+air-hop with NO ceiling on cumulative height gain. On Claim Jumper
specifically, `_clamp_to_arena()` clamps X at the arena wall but deliberately
does NOT clamp the Y ceiling (comment: "pinning his maximum height would
cancel the hop mid-air"), so a hop taken right at the clamped wall re-fires
every `_hop_cooldown` (0.7s) with X pinned — he climbs in place forever
instead of getting a grounded chase frame. Reads as "stuck" even though he's
technically airborne and jumping.

## The applied patch (already integrated, not a proposal)
Added a height-sanity ceiling identical to the Auditor's fix: don't arm a
fresh hop, or fire an already-armed air-hop, once already well above where
the player could plausibly be (>400px above player.y).

@include src/boss/claim_jumper.gd

(Search for `already_high_enough` — two gate sites: the outer hop-trigger
`if is_on_floor() and _hop_cooldown <= 0.0 and not already_high_enough:`,
and the air-hop fire `if _air_hop_ready and not is_on_floor() and velocity.y
> -120.0 and not already_high_enough:`.)

## Measured proof (headless, real level_03_gold_rush.tscn arena)
Player parked at x=4500 (beyond the arena's east wall at x=4400) for 16s —
the exact geometry that used to produce endless in-place climbing:
- min_y = 29.3 (spawn_y=500, so ~470px climb max, well within the intended
  ~400-520px envelope) — NOT unbounded.
- 8 air-hop events fired in 16s while pinned at the wall.
- frames_far_above_ceiling (>620px above ground) = 0.

Existing regression tests (chase_separation, double_jump, difficulty,
pressure) all still pass — no lock-on regression, no TNT/dynamite identity
change.

## Your job
1. Does the patch actually eliminate the root cause you'd expect from this
   code, or does it just mask the symptom in this one test geometry? Look
   specifically at whether `already_high_enough` can be false-negative gated
   in a way that still permits chaining (e.g. does the player's OWN y ever
   get manipulated by something that could make the gate ineffective mid-fight,
   like the player also jumping/falling)?
2. Is there a cleaner/more robust fix you'd recommend instead, or is this
   surgical patch acceptable given the constraint "surgical changes only,
   preserve TNT/minecart identity"?
3. Any edge case in `_clamp_to_arena()` interacting with this gate you can
   spot from reading the code that the headless test (player pinned at ONE
   spot) wouldn't catch?

Be concrete and cite line-level behavior. This is a review of an ALREADY-SHIPPED-CANDIDATE patch, not a request to design one from scratch.
