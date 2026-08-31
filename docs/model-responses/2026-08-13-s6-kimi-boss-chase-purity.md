<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/s6-kimi-boss-chase-purity.md
     files inlined: 2
     tokens: 8234 in / 7397 out
     cost: $0.1357
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Q1 — S3 jump-in-place: mechanism + minimal fix

**Exact stationary-hop sequence (player overhead/above, |dx| < 34):**

1. `_ground_chase` runs every PATROL frame; `absf(dx) > TURN_DEAD_ZONE` fails → `direction` stays stale.
2. Player-above check `pl.global_position.y < global_position.y - 80.0` is true (player on ledge above / jumping over). `_gap_crossable(direction)` is **trivially true on flat ground**: probes start at `foot_y - 190` and cast 310 down → they hit the floor he is already standing on in *any* direction. Gate provides zero selectivity.
3. Hop fires: `velocity.y = -620`, `velocity.x = patrol_speed * direction` = **full 290 px/s committed even when the player is 5px away**.
4. Airtime = 2·620/980 = **1.265s** → ~**367px** horizontal per hop. He lands 367px *past* the player; `dx` flips sign, `direction` flips, next hop commits 290 back. **Ping-pong ±367px around the player's x, net displacement ≈ 0.**
5. `_hop_cooldown` 0.7 < airtime 1.265 → cooldown expired 0.565s before landing → **zero grounded chase frames between hops**; he never walks, only hops.
6. Truly-stationary variant: stale `direction` toward an arena wall → `_clamp_to_arena` snaps `centre_x` and zeroes `velocity.x` every frame → literal vertical hop in place at the wall.

**Root line** (PATROL hop block):
```gdscript
velocity.x = patrol_speed * direction
```

**Minimal fix — scale the commit to actual dx, clamped to patrol_speed:**
```gdscript
const HOP_AIRTIME: float = -2.0 * HOP_VELOCITY / 980.0  # ≈1.265s

# in the hop block, replacing the commit line:
var pdx: float = (pl.global_position.x - (global_position.x + HALF_BODY)) if pl else direction * HOP_REACH
velocity.x = clampf(pdx / HOP_AIRTIME, -patrol_speed, patrol_speed)
```
(`pl` is already in scope in the PATROL branch. Explicit `: float` typing per the 4.3 constraint.)

**Why this is sufficient:**
- Overhead player (pdx≈0) → near-vertical hop that lands *on* the player's x — correct, threatening, no overshoot, no ping-pong. Dead-zone staleness is bypassed entirely (uses `pdx`, not `direction`).
- Kiting player at sprint 240 px/s: once gap > 367px, commit saturates at 290 → gains 50 px/s per airborne frame and closes; below that he lands at the player, never past. Worst case he trails at the player's own speed.
- **Target: ≥1200px net horizontal travel over 6s of horizontal kiting** (≥200 px/s average; expect ~1440px tracking a 240 px/s sprinter). Pre-fix net ≈ 0px → gate fails pre-fix, passes post-fix.
- Ledge-suicide guards untouched: `at_ledge and _gap_crossable(direction)` still gates the hop, `_clamp_to_arena()` still runs after `move_and_slide()`. Gate must also assert boss `y` never exceeds arena floor and boss survives the 6s.

Do **not** "fix" by lowering `_hop_cooldown` or raising speed — that widens the ping-pong amplitude.

## Q2 — S2 projectile purity

**Minimal change:** in `_throw_shards()`, apply the exact two-step already used in `_throw_crystal_shards()` to every spawned orb:
1. `tint.a = 0.0` on the projectile (hides the fx_dot circle).
2. Add the angular Polygon2D shard/diamond child (diamond silhouette, ETH-blue or diamond-white).

Best done by extracting the Polygon2D-construction lines from `_throw_crystal_shards()` into one helper both throw functions call — single source for shard geometry, no divergence. The redirect/homing mechanic (Forced Distribution → Pool Drain) operates on the projectile node/script, not the dot visual, so hiding the dot cannot break it.

**Caveat / missing:** `distributor.gd` and the `boss_projectile` script were not provided — only `tint` is confirmed. If the redirect feedback recolors via `tint`, that recolor becomes invisible at alpha 0; mirror the same recolor onto the Polygon2D child (or its `modulate`) so the redirected state stays readable. Verify against `_throw_crystal_shards()` — if crystals already handle this, copy their approach verbatim.

**Gate assertion (the one check):** after any S2 volley, iterate every live S2 projectile and assert:
```
p.tint.a == 0.0  AND  p has >= 1 Polygon2D child
```
i.e. **no active projectile has a visible base dot**. Pre-fix, `_throw_shards()` orbs have `tint.a == 1.0` and no Polygon2D → fails; post-fix every projectile in the rotation carries shard geometry only → passes.