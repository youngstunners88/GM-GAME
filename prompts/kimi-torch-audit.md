ROLE: You are a verification engineer auditing new gameplay code in a Godot
4.3 2D platformer.

The complete current source of every file under discussion is inlined below.
Base every statement on the code as given.

CONSTRAINT (non-negotiable): Do not invent methods, file paths, node types, or
Godot APIs that do not appear in the inlined files. If you need something that
was not provided, name exactly what is missing instead of guessing.

## What changed this session

A third attack move was added to the main platformer's existing combat
system: when the "torch" power-up is active, tapping the attack button
throws a flame projectile instead of the base axe. This is NOT part of the
separate v1.2 shooter prototype (`src/shooter/weapon_base.gd`) — it's a third
branch alongside the existing axe/purple-fan/fire-breath moves in
`combat_handler.gd`.

1. **New `src/combat/flame_projectile.gd` + `.tscn`** — an `Area2D` thrown
   projectile, structurally mirroring the existing `axe.gd` (same collision
   layer/mask, same body_entered/area_entered/take_damage pattern), but with
   a shallow gravity arc instead of a flat throw, and a CPUParticles2D-driven
   visual (core sprite + envelope + trail particles, no sprite sheet) instead
   of a static sprite.
2. **`src/player/combat_handler.gd`** — added `_throw_flame()`, called when
   `GameManager.has_power_up("torch")` is true, sharing the existing `_axe_cd`
   cooldown timer under a new `TORCH_COOLDOWN` constant rather than adding a
   second timer (reasoning: torch and purple are mutually exclusive — a
   single-slot power-up system — so there's no case where both moves need
   independent cooldowns simultaneously).

## Ground truth about the codebase

- `EnemyBase` (not inlined here, unchanged) declares `take_damage(amount)`,
  checked via `has_method("take_damage")` and `is_in_group("enemy")`.
- `GameManager.has_power_up(type)` is a single-slot check
  (`current_power_up == type`) — only one power-up can be active at a time.
- `AudioManager.play_sfx()` / `play_sfx_at()` silently no-op on a missing
  file — new SFX keys (`torch_throw`, `torch_impact`, `torch_fizzle`) are
  named now with no asset yet, matching how `throw`/`hit`/`fire` were named
  ahead of asset delivery in the original combat system.
- The game targets HTML5 (non-threaded) and Android.

## Files

@include src/combat/flame_projectile.gd
@include src/combat/flame_projectile.tscn
@include src/combat/axe.gd
@include src/combat/axe.tscn
@include src/player/combat_handler.gd

## Tasks

1. **Collision / friendly-fire audit.** Confirm the projectile cannot hit
   the player who threw it, and that the collision layer/mask (64 / 36,
   copied from axe.gd) actually excludes the player layer. Cross-check
   against what layer/mask axe.gd itself uses to confirm the copy is exact.

2. **Lifetime / leak audit.** Every path that can end the projectile's life
   (impact, timeout, scene change mid-flight) — does each one actually free
   the node? Does `_spawn_burst()`'s reparenting to `get_tree().current_scene`
   leak if that scene changes between spawn and the 0.5s cleanup timer, or if
   `current_scene` is null at the moment of impact?

3. **Cooldown-sharing correctness.** `_throw_flame()` reads and writes
   `_axe_cd` (the same variable `_throw_axe()`/`_throw_fan()` use) under a
   new `TORCH_COOLDOWN` value. Trace what happens if a player's torch expires
   mid-cooldown (say, right after throwing a flame) and they still hold an
   axe-cooldown timestamp set to the LONGER or SHORTER torch value — does the
   next non-torch throw inherit an incorrect cooldown window, even briefly?

4. **Performance.** `_physics_process` runs on both the projectile and (via
   `_update_flicker`) touches `core.scale`/`core.modulate` every frame — any
   per-frame allocation or repeated texture generation? Confirm
   `_make_glow_texture()` is actually only built once per instance, not once
   per frame.

5. **The `_hit()` null-safety.** In `_on_area_entered`, `_hit(area.get_parent())`
   is called even when `area.get_parent()` could be the scene root or some
   non-enemy node — does `_hit()`'s own guards make this safe regardless of
   what's passed, matching axe.gd's identical pattern?

6. **Gate compatibility.** Anything about this file's syntax or structure
   that would fail `gdparse` or Godot's `can_instantiate()`? Look
   specifically at the `_glow_tex` caching pattern and the `static`-less
   per-instance caching — is this actually safe, or does something about
   `@onready var core: Sprite2D = $Core` (an empty `Sprite2D` node with no
   texture set in the `.tscn`) risk a null issue before `_ready()` assigns
   the texture?

7. **One-paragraph verdict**: is this safe to ship?

## Output format

Markdown. For every finding: `severity (high/med/low) — file:line-ish — claim
— why it matters`. No preamble.
