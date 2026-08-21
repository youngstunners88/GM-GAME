<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/prompts/deepseek-final-compliance.md
     files inlined: 3
     tokens: 19108 in / 9075 out
     cost: $0.0596
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
1. **State ownership** — `_air_hop_ready` appears only at its declaration and the three PATROL sites:
   ```
   var _air_hop_ready: bool = false
   _air_hop_ready = true
   if _air_hop_ready and not is_on_floor() and velocity.y > -120.0:
       velocity.y = AIR_HOP_VELOCITY
       _air_hop_ready = false
   if is_on_floor() and velocity.y >= 0.0:
       _air_hop_ready = false
   ```
   It is **not read/written in THROW/VULNERABLE** or `_throw_dynamite()`, `_begin_vulnerable()`, `_end_vulnerable()`. Those transitions do not clear it, so a stale true can survive `PATROL -> THROW -> VULNERABLE -> PATROL` and fire on the first resumed PATROL frame if he is still airborne and `velocity.y > -120.0`. No other freeze flag manages it.

2. **Entities in `level_01_data.tres` x 2350–2650, elevated (`y < 650`)**:
   - `collectible_spawns`: `ethereum_ring` `(2400,200)`, `coin_eth` `(2420,400)`, `coin` `(2620,300)`, `coin` `(2350,600)`, `health_pickup` `(2550,580)`
   - `powerup_spawns`: `purple_weed` `(2600,520)`
   - `enemy_spawns`: `rolling_boulder` `(2500,200)`
   - `platforms`: `Vector4(2600,350,100,20)`

   The removed `Vector4(2400,450,120,20)` was under/near the `coin_eth` and `ethereum_ring`, but `ladder2` now runs from `(2345,650)` to `(2345,250)`, so those are reachable from the ladder. `coin (2620,300)` is supported by `Vector4(2600,350,100,20)`. `rolling_boulder` falls to ground. No entry is left unreachable; no soft-lock found.

3. `ladder2.global_position = Vector2(2345, 650)`, `height = 400.0` → top `650 - 400 = 250`. Old base `(2345,450)` with `height = 200` → `450 - 200 = 250`. **Matches exactly.**

4. Minimal files:
   - A: `src/resources/level_01_data.tres` only.
   - B: `src/boss/claim_jumper.gd` only.
   - `src/level/level_01_smoke_realm.gd` ladder2 regrounding was **not required** by either demand; it is a follow-on adjustment for the removed platform’s old ladder exit.