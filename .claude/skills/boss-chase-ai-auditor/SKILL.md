---
name: boss-chase-ai-auditor
description: Static audit of a boss's aggressive-movement state — must re-read the LIVE player position every frame (never a stale snapshot), gate jumps on a landing-distance check, telegraph before aggression, and allow attacks while moving. Run after implementing or editing any boss CHASE/CHARGE/PURSUE state.
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Boss Chase AI Audit

**This is a static audit.** It reads code and reports; it does not fix.

## The defect that shipped (why this exists)

`auditor.gd`'s CHARGE state moved toward `charge_target`, a `Vector2`
captured ONCE when the charge began (`charge_target =
p.global_position`) — never updated again for the whole state duration. It
looked like a chase (the boss visibly moves toward where the player WAS) but
never actually tracked the LIVE player, so simply moving broke the "chase."
Separately, ranged attacks (PATROL only) and aggressive movement (CHARGE
only) were mutually exclusive states — the boss could never do both at once,
reading as "too easy, patrol only" despite having a phase system and ranged
attacks.

## Check 1 — Live tracking, not a snapshot

1. Find the aggressive-movement state's code.
2. Confirm the player's position is read INSIDE that state's per-frame
   update (`_physics_process` or equivalent), not captured once at state
   entry into a variable that then drives movement for the state's whole
   duration.
3. **FAIL** if a `Vector2` snapshot of the player's position, taken once,
   is used as the movement target for more than one frame.

## Check 2 — Jump/gap gate derived from real kinematics

1. Confirm any jump during the chase is gated by a maximum horizontal gap
   check (e.g. `max_jump_gap`), and that the value is DERIVED from the
   boss's own `jump_force`/gravity/speed (airtime × horizontal speed), not
   picked by eye. Compare against `tax_collector.gd`'s documented derivation
   as the house-style example.
2. **FAIL** if the boss can commit to a jump wider than it can physically
   complete (lands in the pit it was trying to cross).

## Check 3 — Telegraph before aggression

Confirm a visible/audible tell (a frozen beat, a color/pose change, a sound)
plays BEFORE the chase begins — matching this project's established
fairness contract (`tax_collector.gd`'s ALERT state: freeze, face the
player, THEN pursue). **FAIL** if the boss snaps into aggressive movement
with no warning, especially for a player's first-ever encounter with it.

## Check 4 — Attack availability during movement

Confirm the boss's ranged/melee attack can fire WHILE the aggressive-
movement state is active (or, if intentionally separate, that this is a
deliberate design choice stated in a comment, not an accidental side effect
of the state machine's structure). **FAIL** if attacking and chasing are
structurally mutually exclusive states with no comment explaining why.

## Check 5 — Untouched systems stay untouched

If phase scaling, the vulnerable damage window, or token-spectacle hooks
exist, confirm the chase/attack changes reuse them (e.g. speed scaling
derived from the same ratio `_update_phase()` already maintains) rather than
duplicating or bypassing them.
