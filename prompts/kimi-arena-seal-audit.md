# Kimi K3 — NARROW audit: boss arena seal + deferred hitbox toggles

**Output rules: emit ONLY the findings block below. No preamble, no restated
code, no long reasoning. If you find nothing in a section, write `NONE`.
Keep the whole reply under 400 words.**

## Engine facts (assume these, do not correct)

- Godot 4.3, GDScript, tabs.
- Layers: 1 = World, 2 = Player, 4 = boss body, 64 = projectiles.
- `Area2D.set_deferred("monitorable", x)` applies at the end of the frame.
- Writing `area.monitorable` directly from `_physics_process` throws
  "Can't change this state while flushing queries" (`set_monitorable`).
- `LevelBase._process` runs in the idle frame, not the physics step.

## What changed (audit ONLY these two things)

### Change A — boss arena entry wall is no longer built at level load
Previously `_setup_boss_arena()` built walls at BOTH `boss_arena.start_x` and
`end_x` during `_ready()`. The `start_x` wall sat directly across the
approach and made every boss unreachable (proven: player stopped at x=2758
against a wall spanning 2790..2810).

Now: `_setup_boss_arena()` builds ONLY the `end_x` wall. Each level's
`_on_boss_trigger` calls `arm_boss_arena_seal()`, which sets `_seal_x` and
enables `_process`; `_process` builds the `start_x` wall once the player is
more than 60px past it, then disables itself.

### Change B — every boss `hitbox.monitorable/monitoring` write is now `set_deferred`
Applied to distributor.gd, auditor.gd, claim_jumper.gd. Some of these writes
happen inside `_physics_process` state transitions (e.g. entering/leaving the
VULNERABLE window).

## Questions — answer each in one or two lines

1. **Seal correctness.** Can the player end up sealed OUTSIDE the arena, or
   get the wall spawned on top of them? Can `_seal_x` leak so `_process`
   never stops, or fire twice and create two walls?
2. **Death/respawn.** If the player dies inside the arena and respawns at a
   checkpoint far to the WEST, the entry wall already exists. Are they now
   permanently locked out of a boss fight that is already in progress? Is
   that a soft-lock?
3. **Deferred monitorable timing.** The vulnerable window now opens and
   closes one frame late. Can that let a hit land while the boss is NOT in
   VULNERABLE, or drop a hit that should have landed? Note that
   `take_damage()` independently checks the state, so answer whether the
   deferral can actually change the damage outcome.
4. **Any remaining direct physics-state write** in the three boss files that
   would still throw during a flush.

## Findings format

```
SEVERITY: CRITICAL|HIGH|MEDIUM|LOW
FILE: <path>
CLAIM: <one sentence>
WHY: <the runtime mechanism, one or two lines>
FIX: <minimal change>
```

Then `VERDICT: SHIP` or `VERDICT: DO NOT SHIP` plus the single most important item.

---

@include src/level/level_base.gd
@include src/boss/distributor.gd
