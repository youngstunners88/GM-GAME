---
name: stomp-attack
description: Static audit of a head-stomp/jump-attack mechanic — fires only from above, damages the enemy not the player, bounces the player, and never double-fires with existing contact-damage/hazard/boulder paths. Run after implementing or editing any stomp logic.
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Stomp Attack Audit

**This is a static audit.** It reads code and reports; it does not fix.

## Context (why this exists)

Before this project had a stomp mechanic, EVERY enemy contact — including
landing squarely on an enemy's head — ran the player's normal
`deal_damage(self)` path and hurt the player. When adding a stomp check, the
single highest-risk mistake is inserting it WITHOUT an early `return`: the
same callback then falls through to the pre-existing contact-damage branch
on the same frame, so the stomp both kills the enemy AND still hurts the
player it just killed. The second-highest risk is a corpse mid-death-tween
(`is_dead = true` but not yet freed) still being stompable/collidable.

## Check 1 — Direction gate

1. Find the stomp check (likely in the player's hurtbox/body-contact
   callback).
2. Confirm it requires BOTH: the player is moving downward (falling speed
   above some minimum, not just `velocity.y > 0` which can be zeroed by
   `move_and_slide()` on the exact frame the signal fires — check for a
   fallback like a cached last-fall-speed) AND the player's origin is
   meaningfully above the enemy's origin (a real Y-margin, not `>=`).
3. **FAIL** if a side or below contact can satisfy the check.

## Check 2 — Return-before-fallthrough

1. Confirm the stomp branch calls `return` (or otherwise unconditionally
   exits the callback) on success, BEFORE any code path that would also
   apply contact damage to the player for the same touch.
2. **FAIL** if damage-to-enemy and damage-to-player can both fire from one
   contact.

## Check 3 — Player bounce

Confirm a successful stomp sets an upward `velocity.y` (a real bounce, not
just canceling downward velocity to zero) and ideally refreshes double-
jump/air-dash so a stomp chain feels good.

## Check 4 — Exclusions and corpse guard

1. Confirm bosses (or anything with its own gated damage-window contract,
   e.g. a VULNERABLE state) are excluded from stomp unless that's explicitly
   the design — a free stomp bypassing a boss's damage gate is a balance
   defect, not a feature.
2. Confirm the target enemy's death path (`die()`/`deal_damage()`) has an
   `is_dead` guard so a corpse mid-death-tween can't be damaged or deal
   damage again from a bounce-back re-touch.

## Check 5 — Cross-path stacking

Check for other systems that can ALSO fire on the same contact (a damage
aura, an AOE ground-pound, a hazard group membership) and confirm they don't
double-stack with the stomp on the same frame for the same enemy.
