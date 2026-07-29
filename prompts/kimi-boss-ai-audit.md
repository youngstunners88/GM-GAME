ROLE: You are a verification engineer auditing new gameplay code in a Godot
4.3 2D platformer.

The complete current source of every file under discussion is inlined below.
Base every statement on the code as given.

CONSTRAINT (non-negotiable): Do not invent methods, file paths, node types, or
Godot APIs that do not appear in the inlined files. If you need something that
was not provided, name exactly what is missing instead of guessing.

## What changed this session

1. **New `src/ui/boss_health_bar.gd`** — a screen-anchored `CanvasLayer` boss
   health bar using discrete pips (one per HP; bosses have 6-10 max HP).
   Replaces a raw `ProgressBar` that was previously parented to the boss body
   in world space.
2. **`src/boss/boss_base.gd`** — `_setup_health_bar()` now builds the new bar.
   Note `health_bar.set_boss.call_deferred(...)` — deferred because
   `BossHealthBar` builds its child nodes in `_ready()`, which has not run at
   `add_child()` time.
3. **`src/boss/auditor.gd`** — this boss extends `CharacterBody2D` directly,
   NOT `BossBase`, so it had no health bar at all. It now creates one manually
   in a member named `_health_bar` (deliberately not `health_bar`: it has no
   inherited member to match, and shadowing an inherited member is a hard
   parse error in GDScript that silently leaves the whole script unattached —
   that exact bug previously left three bosses with no script).
4. **`src/boss/claim_jumper.gd`** — bug fix: it set `max_health = 6` but never
   set `health`, and `EnemyBase.health` defaults to 1, so this boss died in one
   hit. Now sets `health = max_health`.
5. **`src/enemies/tax_collector.gd`** — rewritten from pure patrol to a
   PATROL → ALERT → PURSUE state machine with jumping.

## Ground truth about the codebase

- `EnemyBase` declares `health`, `is_dead`, and `sprite` (typed `CanvasItem`,
  resolved via `get_node_or_null("Sprite")`).
- `BossBase extends EnemyBase`. `distributor.gd`, `claim_jumper.gd`,
  `bandit_boss.gd` extend `BossBase` and each call `_setup_health_bar()` from
  their own `_ready()` WITHOUT calling `super()`.
- Bosses call `_update_health_bar()` with no arguments in their own
  `take_damage()` overrides; the signature has a default parameter.
- The game targets HTML5 (non-threaded) and Android.

## Files

@include src/ui/boss_health_bar.gd
@include src/boss/boss_base.gd
@include src/boss/auditor.gd
@include src/enemies/tax_collector.gd
@include src/enemies/enemy_base.gd

## Tasks

1. **Null-reference and lifetime audit.** Every place these can crash or leak.
   Pay specific attention to: the `call_deferred` configuration path in
   `BossBase._setup_health_bar()` (what if the boss dies or is freed before the
   deferred call runs?); `flash_damage()` indexing into `_pips`; and health-bar
   cleanup in each `die()`.

2. **Tax Collector state machine correctness.** Can it get stuck in any state?
   Can it oscillate between states? Is the `lose_interest_time` hysteresis
   actually sufficient? Can the jump logic launch it into a pit despite the
   `max_jump_gap` guard — consider that the guard tests horizontal distance to
   the PLAYER, not the width of the gap in front of the enemy.

3. **Performance.** These run in `_physics_process` for potentially several
   enemies at once. Flag anything doing per-frame allocation, per-frame scene
   tree searches, or unbounded tween creation. Note `set_phase()` and
   `flash_damage()` both call `create_tween()`.

4. **The `_pips` index contract.** `set_health()` lights pips `i < current`.
   Callers pass `flash_damage(health)` after `set_health(health)`. Verify this
   is correct for all cases including the killing blow (health reaching 0) and
   multi-point damage in a single hit.

5. **One-paragraph verdict**: is this safe to ship?

## Output format

Markdown. For every finding: `severity (high/med/low) — file:line-ish — claim
— why it matters`. No preamble.
