---
name: collectible-walkthrough
description: Static audit that a collectible Area2D is claimable by walking through it, not only by jumping onto it — checks collision signal type, mask, and vertical placement vs. the player's standing collision box. Run after adding any new collectible scene, or when a founder reports "tokens only work if I jump on them."
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Collectible Walk-Through Audit

**This is a static audit.** It reads scene/script files and reports; it does
not fix.

## Context (why this exists)

An audit of this project's existing collectibles (`coin.gd`, `gold_token.gd`)
found the CODE path is already correct: both use `Area2D.body_entered`
against the player's real physics body (not a jump-only or velocity-gated
check), and `collision_mask` correctly matches the player's body layer. If a
"only works when jumping" complaint recurs, the most likely cause is LEVEL-
DATA token height placement — the token's Y position sits above where a
standing/walking player's collision shape reaches, so only a jump's upward
arc overlaps it. This skill checks BOTH possibilities so a placement bug
isn't misdiagnosed as a code bug (or vice versa).

## Check 1 — Signal and mask (code-level)

1. Confirm the collectible's `.gd` script connects `body_entered` (not
   `area_entered` alone, and not any manual `velocity`/`is_on_floor` gate
   before granting the pickup).
2. Confirm the `.tscn`'s `collision_mask` includes the player's main body
   collision layer (check `player.tscn`'s root `CharacterBody2D` layer, NOT
   the Hurtbox Area2D's layer — those can differ).
3. **FAIL** if either check doesn't hold.

## Check 2 — Vertical reachability (data-level)

1. Read the collectible's `CollisionShape2D` position/size in its `.tscn`.
2. Read the player's main body `CollisionShape2D` size/position in
   `player.tscn` to establish standing height.
3. For each `collectible_spawns` entry in a level's data resource, compute
   the token's world Y and compare against the nearest `ground_segments`
   surface Y directly below it: if the gap exceeds the player's standing
   collision height (i.e. only a jump's arc reaches it), **FAIL** and report
   the spawn position — recommend lowering the Y or leaving it as an
   intentionally jump-only bonus (state which, don't assume).

## Check 3 — Double-collection guard

Confirm `monitoring` (or an equivalent one-shot guard) is set to `false`
(preferably `set_deferred`) at the START of the collect handler, before any
`queue_free()` — `queue_free()` alone doesn't prevent a same-frame double
trigger from a physics hitch.
