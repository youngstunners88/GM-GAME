<!-- dispatched: moonshotai/kimi-k2-thinking
     prompt: prompts/kimi-chase-numbers.md
     files inlined: 2
     tokens: 11213 in / 15149 out
     cost: $0.0446
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**1. Pursuit speed per state (px/s) vs sprinting player (240 px/s)**  

| State            | Speed scale | Effective speed | vs 240 | Verdict |
|------------------|-------------|-----------------|--------|---------|
| PATROL           | 1.00        | 330.0           | >240   | **PASS** |
| GRAVITY_TELL     | 0.62        | 204.6           | <240   | **FAIL** |
| HOARD_GRAVITY    | 0.55        | 181.5           | <240   | **FAIL** |
| SHARD_THROW      | 0.70        | 231.0           | <240   | **FAIL** |
| VULNERABLE       | 0.00        | 0.0             | <240   | **FAIL** |

---

**2. Fraction of a full attack cycle spent slower than 240 px/s**  

Full cycle = 2 × PATROL + GRAVITY_TELL + HOARD_GRAVITY + 2 × SHARD_THROW + 2 × VULNERABLE  

| Phase | PATROL (cadence) | GRAVITY_TELL | HOARD_GRAVITY | 2 × SHARD_THROW | 2 × VULNERABLE | Total cycle (s) | Slower time (s) | Fraction slower |
|-------|------------------|--------------|---------------|-----------------|----------------|-----------------|-----------------|-----------------|
| 1     | 1.5 × 2 = 3.0      | 0.65         | 1.4           | 0.9             | 3.2            | 9.15            | 6.15            | **0.672** |
| 2     | 1.2 × 2 = 2.4      | 0.60         | 1.8           | 0.9             | 2.5            | 8.20            | 5.80            | **0.707** |
| 3     | 1.2 × 2 = 2.4      | 0.50         | 2.2           | 0.9             | 1.8            | 7.80            | 5.40            | **0.692** |

Boss is slower than a sprinting player **≈ 67‑71 %** of the time.

---

**3. World‑x ranges and pinning points**  

- Arena (level data): `start_x = 3700`, `end_x = 4400`  
- Boss clamp (origin): `arena_min.x = 3790`, `arena_max.x = 4310`  
- Boss body size: `BODY = 240` → half‑width = 120  

**Boss visible centre** = origin + (120, 120)  

- Centre range: **[3910, 4430]**  
- Player viable range: **[3700, 4400]**  
- Overlap where both can meet: **[3910, 4400]**

**Pinning condition** – when the player’s x is outside the boss’s origin clamp:  

- Player **x ≤ 3790** → boss origin locked at **3790** (centre = 3910).  
- Player **x ≥ 4310** → boss origin locked at **4310** (centre = 4430).  

*Concrete pinning spots*  

- Left wall: player at **x = 3700** → boss stuck at origin = 3790, centre = 3910 (90 px gap).  
- Right wall: player at **x = 4400** → boss stuck at origin = 4310, centre = 4430 (90 px gap).  

Thus the boss **cannot close the final 90 px** to a player at either wall.

---

**4. Velocity zeroing on clamp**  

`_clamp_to_arena()` **does not** zero velocity. It only corrects `global_position`.  

*Consequence*: the boss continues to accelerate toward the player, burning CPU and retaining a large velocity vector. When the clamp is released (player moves back toward the centre) the boss may overshoot or snap violently.

---

**5. Minimum numeric changes to guarantee closure**  

Two changes are required:

**a. Widen the left clamp boundary** (level script)  
```gdscript
# In src/level/level_02_crystal_caverns.gd, _on_boss_trigger()
var ax0: float = float(arena.get("start_x", 0.0))          # remove the +90.0
var ax1: float = float(arena.get("end_x", 0.0)) - 90.0   # keep right inset as‑is or set to end_x - 240 if you want the boss’s right edge to stop at the wall
```
*Effect*: boss origin can now reach the left wall (origin = 3700), eliminating the 90 px dead‑zone.

**b. Increase pursuit speed in the three slower states** (boss script)  
```gdscript
# In src/boss/distributor.gd, adjust the speed_scale arguments:
_hover_pursue(delta, 0.73)   # GRAVITY_TELL  → 330 × 0.73 = 240.9 px/s
_hover_pursue(delta, 0.73)   # HOARD_GRAVITY → 240.9 px/s
_hover_pursue(delta, 0.73)   # SHARD_THROW   → 240.9 px/s
```
*Effect*: every active pursuit phase now exceeds the player’s sprint speed, so the boss gains ground whenever it is not in VULNERABLE.

With these two edits the boss can close distance on a sprinting player from any location inside the arena.