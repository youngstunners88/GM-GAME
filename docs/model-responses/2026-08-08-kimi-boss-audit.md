<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-boss-audit.md
     files inlined: 4
     tokens: 15644 in / 18875 out
     cost: $0.3301
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## R7 — pit fall: REAL BUG, CRITICAL

**CRITICAL — distributor.gd:148-153 — PATROL applies gravity every frame (`velocity.y += 980.0 * delta`, line 149) and the ONLY direction reversal is `if is_on_wall()` (151). There is no `is_on_floor()` check, no ledge detection, no arena x-clamp, no y kill-plane anywhere in the file.** Gravity is also applied unconditionally in all four other states (167, 175, 191, 198), so nothing ever stops a fall. Once he walks off a ledge he falls forever; `die()` is reachable only via `_damage()` (459-460), which the player can't deliver to a boss below the arena. Founder is right: unrecoverable.

**Minimal fix (float — matches his original "float + ranged only" design, removes the pit risk categorically):**
```gdscript
# _ready():
_hover_y = global_position.y
# PATROL, replace lines 149-150:
velocity.y = 0.0
move_and_slide()
global_position.y = _hover_y   # belt-and-braces vs. knockback-style drift
```
Delete the other four `velocity.y += 980.0 * delta` lines (167, 175, 191, 198). No `is_on_floor()` consumer exists in this script, so nothing else breaks. (Alternative — x-bounds clamp + flip — does NOT fix it: a pit between the bounds still swallows him. Don't ship that alone.)

## R1 — both-way damage: NOT A BUG IN THIS CODE

**Player→boss works, two paths:**
- `_on_hitbox_area_entered` (~distributor.gd:524-526) → `take_damage(1)`, gated to VULNERABLE at 464-466. The window IS reachable: SHARD_THROW → `_begin_vulnerable()` (193-194) fires every second cycle in phase 1 and every gravity cycle in phase ≥2 (182-183), plus `_pool_drain()` → `_begin_vulnerable()` (339). `_damage()` decrements `health` (444).
- Redirected orbs bypass the window via `take_redirected_orb()` (303-317), capped at 1/volley.

**Boss→player works:** `hitbox.monitoring` is set true at 121 and never disabled until `die()` (488) — so `_on_hitbox_body_entered` (~518-522) fires on contact all fight and calls `body.take_damage(1)`.

**So the founder's live repro must come from wiring outside the provided files. Exactly what's missing:**
1. `distributor.tscn` — the `$Hitbox` Area2D's `collision_mask`: must include the player's layer (for `body_entered`) and the projectile layer (for `area_entered`). Not provided.
2. `src/combat/axe.tscn` / `flame_projectile.tscn` / `fire_breath.tscn` — the root Area2D must be in group `"projectile"` and on a layer the Hitbox mask sees. combat_handler.gd only instantiates the scenes; group membership is not visible anywhere in what you gave me.
3. Stomp: **no stomp→boss-damage path exists at all** in distributor.gd — body contact only ever damages the player. If the design expects stomps to hurt him, that path is absent (player-side stomp code not provided to confirm).

## R6 — Auditor facing: (a) REAL, MEDIUM; (b) unverifiable here

**(a) MEDIUM — auditor.gd:148 — in PATROL the sprite faces `patrol_direction` and updates ONLY on wall flip. `_throw_clipboard()` (256-260) aims clipboards at the live player but never updates facing.** Result: for the entire non-chase portion of the fight he can face away from the player while throwing clipboards at them from his back. ALERT faces the player once (165) and PURSUE tracks every frame (215) — so the founder's read is exactly right for PATROL.

**Minimal fix — face the player during PATROL (movement unchanged), after line 145's `move_and_slide()`:**
```gdscript
var pl := get_tree().get_first_node_in_group("player")
if pl:
    sprite.scale.x = 1.0 if pl.global_position.x > global_position.x else -1.0
```
(He may then moonwalk while retreating — standard boss behaviour, and it matches the ALERT/PURSUE facing contract already in the file.)

**(b) Inversion vs. native art: cannot be determined from the provided files.** The code's convention is "scale.x = 1.0 ⇒ facing right" (148, 165, 215), and boss_sprite.gd flips the texture child along with the node. Whether that matches the art depends on `texture_path` set in `auditor.tscn` and the source image's native orientation — neither was provided. To close this out I need: `auditor.tscn` (the BossSprite's `texture_path`) and the sprite asset itself. If the art is natively left-facing, all three assignment sites are inverted; nothing in the code can tell me that.

Note: distributor.gd:153 has the same patrol-direction-only facing, but it's cosmetic-only there (his attacks are radial/aimed, no visual throw-from-back).

**Fix priority: R7 (ship-blocker) → R6(a) → R1 scene-wiring check (masks + groups in the .tscn files above).**