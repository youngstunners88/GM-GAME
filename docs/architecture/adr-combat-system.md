# ADR: Combat System — Axe Throw + Purple-Power Attacks

**Date:** 2026-07-12
**Status:** Accepted
**Files:** `src/player/combat_handler.gd` (new), `src/combat/axe.gd` + `axe.tscn` (new), `src/combat/fire_breath.gd` + `fire_breath.tscn` (new), `src/player/player.tscn`, `project.godot` (input + no code change to `player.gd`)

## Context

Lil Blunt could run, jump, double-jump, and dodge, but enemy encounters were
pure obstacle-avoidance — no way to *fight back*. The client wants active
attacks, with the Purple Weed power-up unlocking a visibly stronger "power
fantasy": throw one axe normally, throw *multiple* axes on purple, and a
signature ETH-flask fire-breath move. Attacks must feel weighty and work on
both keyboard and touch.

## Decision

A self-contained `CombatHandler` node on the Player, mirroring the existing
`InputHandler`/`PowerUpHandler` split — `player.gd` is untouched, so movement
and combat evolve independently.

**Input:** new `attack` action — `J` and `Enter` on keyboard; a press/hold-aware
`ATK` button on the mobile overlay (`button_down`/`button_up` so the hold
channel works on touch). Routed through `MobileInputHandler` signals like every
other mobile action.

**Move set:**

| Move | Trigger | Cooldown | Effect |
|---|---|---|---|
| **Axe throw** | tap (no purple) | 0.4s | One spinning axe, flat throw in facing dir. Kills a 1-HP minion, shatters boulders (`smash()`) |
| **Three-axe fan** | tap (purple active) | 0.5s | Three axes: straight + two drifting ±0.28·speed vertically. Mob-clear; the purple flex |
| **ETH-flask fire breath** | hold ≥0.28s (purple active) | 1.4s | Swig + exhale: a ~150px flame cone, ticks 1 dmg every 0.15s to enemies inside, fire particles |

**Projectile design:**
- `Axe` is an `Area2D` on the Projectiles layer (7), masking **Enemies (bit 3) +
  Hazards (bit 6, the boulder layer)** = mask 36 — deliberately **not** World,
  so a low throw skims the floor instead of despawning on the first tile.
  Reuses the pickaxe sprite (an axe-shaped tool already in the atlas); a bespoke
  throwing-axe sprite is a later art pass, not a blocker.
- `FireBreath` is an `Area2D` **child of the player** (tracks his position) with
  a convex cone collider; `direction` sign + `scale.x` orient it to facing.
  Ticks via `get_overlapping_bodies()`.

**Cooldown philosophy:** fan > single-throw so purple isn't strictly-better
spam; fire breath gates hardest as the heavy hitter. Hold and tap share no
cooldown, so a purple player can fan *and* breathe in one press-hold.

## Consequences

- Enemies already expose `take_damage()` (EnemyBase) and boulders `smash()`, so
  no enemy code changed — combat is purely additive.
- Damage only fires while `StateMachine.is_playing()`, matching the guard that
  protects the boss-victory window elsewhere.
- SFX keys `throw`/`hit`/`fire` are referenced now; `AudioManager.play_sfx`
  silently skips missing files, so they light up for free when the SFX pass adds
  them (STATUS gap #3).
- Purple Weed is now a triple-threat (speed/jump + multi-axe + fire breath),
  strongly reinforcing it as the flagship strain.

## ADR Dependencies

Builds on the power-up system (`purple` state) and the feel pass
(`adr-gameplay-feel.md`) — hitstop already lands on damage the player takes;
enemy-hit hitstop is a candidate follow-up.

## Engine Compatibility

Godot 4.3 (pinned). Uses only stable engine calls — Area2D's body_entered
signal and get_overlapping_bodies, SceneTree create_timer, CPUParticles2D,
ConvexPolygonShape2D points, and the Input is_action_just_pressed / pressed
polling.

## GDD Requirements Addressed

CLAUDE.md Game Identity — expands "Core Abilities" with attacking tools
(pickaxe/axe throw) and ties the Purple Weed power-up to a distinct combat
upgrade, per the client's "give him attacking features too" direction.

## Future hooks (not in this cut)

Shockwave stomp (jump+attack slam), airborne spin attack with i-frames, and
per-level axe-ammo economy were scoped and deferred — the handler's cooldown
structure leaves room to add them without touching `player.gd`.
