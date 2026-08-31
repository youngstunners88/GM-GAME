<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/s4-kimi-boss-only.md
     files inlined: 3
     tokens: 21633 in / 11184 out
     cost: $0.2327
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Q1 — Distributor

**Crystal visual: confirmed.** All three attacks (`_throw_crystal_shards`, `_throw_shards`, Stage-1 clipboard) are the same `boss_projectile.tscn` dot with different `tint`. Tint is the only differentiator, so they read identically. Fix: give the shard its own geometry. Asset-free, consistent with this file's procedural surfboard/telegraphs — add in `_throw_crystal_shards` after configuring each shard:

```gdscript
var poly := Polygon2D.new()
poly.polygon = PackedVector2Array([
    Vector2(16, 0), Vector2(2, 6), Vector2(-14, 3),
    Vector2(-14, -3), Vector2(2, -6),
])
poly.color = Color(0.85, 0.98, 1.0, 1.0)
poly.rotation = shard.direction.angle()
shard.add_child(poly)
```

Then hide the base dot. **Missing:** `boss_projectile.tscn`/`boss_projectile.gd` were not provided, so I can't name the sprite node to set `visible = false`, nor confirm whether `tint` drives `modulate` (if it does, `shard.tint.a = 0.0` hides the dot). Send that file and I'll give the exact line; alternatively author a dedicated `crystal_shard.tscn`.

**Kiting arithmetic: positive as shipped, not just vs. stationary.**
- Player sprint: 200 × 1.2 = **240 px/s**.
- Every pursuing state runs at `maxf(330 × scale, 345)` = **345** (330×0.62/0.55/0.70/1.0 all < 345 — note `HOVER_MAX` is currently inert; the floor governs everything). Net vs. kiter: **+105 px/s**.
- VULNERABLE: 120 px/s → **−120 px/s**, 1.25s/window in phase 2.
- Worst case (phase-2 super-cycle, 8.2s = 5.7s pursuing + 2×1.25s vulnerable): 5.7×105 − 2.5×120 ≈ **+298 px/cycle (~+36 px/s avg)**. Positive on open ground; arena walls only help him.

The one remaining zero-progress window is the climb lock (`climbing` → `to.x = 0`): horizontal closing is exactly 0 while a kiter gains 240 px/s (~0.45s ≈ 108 px lost per engagement). `PULL_FLOOR_MARGIN = 72` stops the pull re-arming it, but if the founder still reports "not chasing," this is the residual cause. Minimal fix: tighten `could_touch` from `< BODY` to `< BODY * 0.75` (contact needs only ~120px + player half-width, so 180 keeps the sweep-kill margin) — shrinks the lock's trigger band without touching the lock itself.

## Q2 — Claim Jumper

**(a) Back-facing: confirmed.** `set_facing` is gated on `absf(velocity.x) > 12.0` inside `_ground_chase`; the ledge hold, the arena clamp, and VULNERABLE all zero `velocity.x`, freezing the last facing while the player walks behind him. Fix — face the player every frame, in `_physics_process` after the `is_dead` check, and delete the gated block in `_ground_chase`:

```gdscript
var pl := get_tree().get_first_node_in_group("player")
if pl:
    boss_sprite.set_facing(pl.global_position.x > global_position.x + HALF_BODY)
```

**(b) Vertical-hop stall: root cause.** `_ground_chase`'s ledge hold sets `velocity.x = 0` whenever `_ledge_ahead` is true and `_gap_crossable` is false (or `_clamp_to_arena` zeroes it at a wall) — but PATROL's hop rule `pl.global_position.y < global_position.y - 80.0` ignores both and still fires `velocity.y = HOP_VELOCITY`. vx=0 + vy=−620, re-armed every 0.7s = jumping straight up in place. It triggers constantly because `_gap_crossable`'s rays start at `foot_y - 8` and cast only **down** 120px — ground *above* his feet (a higher far ledge, exactly where a player above him stands) is invisible, so every upward pursuit reads "uncrossable."

Minimal fix, no ledge-death regression (the `velocity.x = 0` hold and the landing-required rule stay):

```gdscript
# _gap_crossable: probe within hop envelope (620^2/2/980 ≈ 196px rise)
var from := Vector2(global_position.x + HALF_BODY + dist * facing, foot_y - 190.0)
var params := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 310.0))
```

```gdscript
# PATROL: don't hop to nowhere
if pl and pl.global_position.y < global_position.y - 80.0 and _gap_crossable(direction):
    want_hop = true
```

Higher far ground now reads crossable → the existing at_ledge hop fires and in-air accel carries him across/up (horizontal pursuit restored); with no landing anywhere, he holds instead of hopping in place or falling in.

**(c) Dynamite: confirmed.** `SceneTree.physics_frame` is emitted *before* the physics step runs, so after `await get_tree().physics_frame` the new Area2D's overlaps have not yet been computed — `get_overlapping_bodies()` reads pre-registration state and returns empty. Replace the temp Area2D + await with a synchronous shape query (works from both the timer callback and `body_entered`):

```gdscript
var space := get_world_2d().direct_space_state
var shape := CircleShape2D.new()
shape.radius = explosion_radius
var params := PhysicsShapeQueryParameters2D.new()
params.shape = shape
params.transform = Transform2D(0.0, global_position)
params.collision_mask = 2
params.collide_with_bodies = true
params.collide_with_areas = false
for hit in space.intersect_shape(params):
    var body: Object = hit["collider"]
    if body.is_in_group("player") and body.has_method("take_damage"):
        body.take_damage(1)
```

Delete the `explosion` Area2D/`CollisionShape2D` creation, the `await`, and the trailing `explosion.queue_free()`; keep the burst/SFX/shake and death tween as-is.