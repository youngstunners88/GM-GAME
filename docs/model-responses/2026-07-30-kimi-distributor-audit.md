<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-distributor-audit.md
     files inlined: 6
     tokens: 10938 in / 13941 out
     cost: $0.2419
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Q1 — State reachability

All five `Phase` values are reachable and all have exits. No claim-jumper-class dead states.

- `PATROL`: initial value; also entered from `HOARD_GRAVITY` exit (phase < 2 branch) and `_end_vulnerable()`.
- `GRAVITY_TELL`: `_begin_gravity_tell()`, called from `PATROL` on even `_cycles`.
- `HOARD_GRAVITY`: `_begin_hoard_gravity()`, from `GRAVITY_TELL` timeout.
- `SHARD_THROW`: `_throw_shards()`, from `PATROL` (odd cycles) and from `HOARD_GRAVITY` exit (phase ≥ 2).
- `VULNERABLE`: `_begin_vulnerable()`, from `SHARD_THROW` timeout and from `_pool_drain()`.

Every state exits via `state_timer`/`throw_timer` or `take_damage` → `_end_vulnerable()`. No soft-lock.

## Q2 — Timers

`throw_timer` is reset on **all three** paths into `PATROL` (`_ready`, `HOARD_GRAVITY` exit, `_end_vulnerable`), so it never goes stale negative when `PATROL` reads it. `state_timer` is set on every state entry and only read by the state that set it; `take_damage` interrupting `VULNERABLE` leaves it harmlessly decrementing in `PATROL`, which never reads it. Clean.

## Q3 — Damage paths

Both paths route through `_damage()`, which does health bar + phase check + death, and both check `is_dead` first. The Auditor desync class is not present. Cap cannot be bypassed: `_volley_damage` is reset per volley and enforced before `_damage(1)`; the POOL DRAIN bonus is separate and intended (max 3 dmg/volley cycle: 1 window + 1 redirect + 1 drain).

## Q4 — POOL DRAIN

Cannot double-fire (`_volley_size = 0` zeroes the guard; later flips increment `_volley_redirected` but the `_volley_size > 0` check fails). Stale orbs are rejected on both paths by volley id (`bind(_volley_id)` captures the int by value at connect time; arrival passes `orb.volley_id`). Airtight.

## Q5 — Pull field

Works: `move_toward` only clamps per-frame delta, so injected velocity partially survives regardless of whether boss or player physics runs first; holding away genuinely resists. Player is a `CharacterBody2D` on solid floor with no pits, so no tunneling/ledge risk; dead-player guard exists via `StateMachine.is_dead()`. **Caveat:** whether the pull is meaningful at all depends on the player's acceleration value, which is in the player controller file — **not provided**. If player accel ≫ 520, the pull is fully negated even with no input.

## Q6 — Redirect wiring

Group guard is sufficient: boss orbs are in `"boss_projectile"` and explicitly rejected, and they are never in `"projectile"`. Double-redirect is blocked by `_redirected`. Redirected orbs pass through the player (`_on_body_entered` early-returns). Correct.

## Q7 — Signal/lifetime

Godot auto-disconnects connections whose target is freed, so `redirected.emit()` after boss death/scene change is a safe no-op; the arrival path is guarded by `is_instance_valid(owner_boss)`. Orbs are parented to the level, so they die with the scene. One real gap — see F6 below.

## Findings

```
SEVERITY: MEDIUM
FILE: src/boss/distributor.gd
SYMBOL: _damage()
CLAIM: The damage-flash tween targets `sprite`, which is null on this boss.
WHY: EnemyBase sets `sprite = get_node_or_null("Sprite")`; distributor.tscn has no "Sprite" child (art is the ColorRect/BossSprite). tween_property(null, ...) errors every hit and no flash plays — error spam on every damage instance in the fight.
FIX: Point the tween at `boss_sprite` instead of `sprite`.
```

```
SEVERITY: MEDIUM
FILE: src/boss/distributor.gd
SYMBOL: _begin_vulnerable / _end_vulnerable (hitbox.monitoring toggling)
CLAIM: Contact damage (_on_hitbox_body_entered) is only active during VULNERABLE, so HOARD GRAVITY drags the player into the boss with zero consequence.
WHY: hitbox.monitoring = false except inside the vulnerable window, so body_entered never fires during the pull; in phase 1 (no follow-up volley) the pull is completely toothless, and the "mock" contact-damage path is near-dead code. The area path is already double-gated by take_damage's VULNERABLE check, so always-on monitoring is safe.
FIX: Set hitbox.monitoring = true once in _ready and never toggle it; keep only `monitorable` gated on VULNERABLE.
```

```
SEVERITY: LOW
FILE: src/boss/distributor.gd
SYMBOL: take_redirected_orb()
CLAIM: ScreenShake.medium() and the "DISTRIBUTED" float text fire before the volley-id and damage-cap checks.
WHY: A stale-volley or over-cap arrival plays full success feedback while dealing 0 damage — the same "looks real, does nothing" lie as the dynamite bug, cosmetic edition.
FIX: Move the volley/cap checks above the shake/text.
```

```
SEVERITY: LOW
FILE: src/boss/distributor.gd
SYMBOL: _damage()
CLAIM: `_update_health_bar()` is called without `hp_before`, so `flash_damage()` never runs on this boss.
WHY: hp_before defaults to -1, so the `hp_before > health` branch in BossBase._update_health_bar never triggers; the pip-flash feedback is silently skipped on both damage paths.
FIX: Capture `var before := health` at the top of _damage and pass it: `_update_health_bar(before)`.
```

```
SEVERITY: LOW
FILE: src/boss/distributor.gd
SYMBOL: die()
CLAIM: Live orbs are not cleared on death and can still damage the player during the ~4s victory sequence.
WHY: die() disables the boss but in-flight projectiles (4s lifetime, still monitoring layer 2) keep flying through the death tween + 3s timer and can hit the player after LEVEL_COMPLETE.
FIX: In die(), `get_tree().call_group("boss_projectile", "queue_free")` (or a dedicated despawn).
```

```
SEVERITY: LOW
FILE: src/boss/distributor.gd
SYMBOL: _on_phase_changed()
CLAIM: The promised "visible escalation" is a no-op: phase 2 sets modulate to white (unchanged), phase 3 changes nothing visual.
WHY: `boss_sprite.modulate = Color(1,1,1,1)` is the identity; only _tell_duration actually changes. Comment claims a palette shift that never happens.
FIX: Set an actual per-phase color/modulate.
```

```
SEVERITY: LOW
FILE: src/boss/distributor.gd
SYMBOL: _throw_shards()
CLAIM: `orb.global_position` is set before `get_parent().add_child(orb)`.
WHY: If the parent (arena/level) ever has a non-identity transform, orbs spawn offset from the intended muzzle position. Works today only if the parent sits at origin.
FIX: Move the global_position assignment after add_child.
```

**Unverifiable (files/API surface not provided — not counted as defects):** `BossVoiceSystem.set_active/clear_active`, `StateMachine.is_dead()/.State.LEVEL_COMPLETE`, `ScreenShake.medium/heavy/zoom_to`, `GameManager.has_power_up/next_level_scene/save_session`, whether world geometry is in group `"world"` (orb `_on_body_entered` despawn depends on it), the two prism texture paths in `_spawn_prism_pools`, and the player controller's acceleration (determines whether the pull is resistible-but-real or fully negated).

## VERDICT

SHIP — the hunted bug class is absent: all states reachable, both damage paths route through health bar + phase check, volley-id bookkeeping is sound. Fix F1 (null `sprite` tween — one line, currently error-spamming on every hit) and decide F2 (whether the pull is allowed to be toothless in phase 1) before merge.