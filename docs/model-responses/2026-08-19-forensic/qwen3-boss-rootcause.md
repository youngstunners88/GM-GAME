<!-- dispatched: qwen/qwen3-235b-a22b-thinking-2507
     prompt: prompts/2026-08-19-boss-shared-rootcause.md
     files inlined: 4
     tokens: 37757 in / 2505 out
     cost: $0.0144
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
### 1. **Shared Root Cause Analysis**
The proposed root cause (player outside arena, bosses clamped inside) **partially explains** the issue but fails to account for **Stage 1's unique behavior** and **Stage 3's mixed tracking score**:
- **Stage 1 (Auditor)** has **no arena bounds** (`arena_min/arena_max = (0,0)`), so clamping cannot freeze it. Its negative tracking score (-0.20) indicates **active movement away from the player**, unrelated to arena walls.
- **Stage 2 (Distributor)** and **Stage 3 (Claim Jumper)** are clamped to their arenas. Photogrammetry confirms the Distributor is pinned at the west wall when the player retreats, but **Stage 3's 17% "frozen" time** suggests partial clamping issues, not complete immobility.

**What the hypothesis misses**:
- **Stage 1's CHARGE state**: The `charge_target` is captured **once on state entry** (line 314 in `auditor.gd`) and never updated. If the player moves after the charge starts, the boss charges in a straight line away from the player, creating the negative tracking score.
- **Stage 1's VULNERABLE state**: `velocity.x = move_toward(velocity.x, 0.0, 200.0)` (line 353) uses **fixed deceleration without delta scaling**, causing abrupt halts that break pursuit momentum.

---

### 2. **Stage 1's Negative Tracking Score**
The **Auditor's movement flaws** are rooted in:
- **CHARGE State**:  
  ```gdscript
  var dir := global_position.direction_to(charge_target)  # Fixed target from state entry
  velocity.x = dir.x * charge_speed  # No mid-charge updates
  ```
  If the player moves after the charge begins, the boss charges in a direction that may **actively move away** from the player.
- **VULNERABLE State**:  
  ```gdscript
  velocity.x = move_toward(velocity.x, 0.0, 200.0)  # No delta scaling
  ```
  This causes **abrupt stops** (e.g., 400px/s → 0 in 2 frames at 60 FPS), breaking pursuit continuity.

---

### 3. **Minimal Shared Fix**
**Goal**: Allow bosses to **chase the player outside the arena** while retaining arena bounds for level design.  
**Proposed Fix**:
- **Adjust `lock_camera_to_arena` in `BossBase`**:  
  Add a `chase_range` parameter to extend the boss's clamp when the player is outside:
  ```gdscript
  func lock_camera_to_arena(start_x: float, end_x: float, chase_range: float = 200.0) -> void:
      var player = get_tree().get_first_node_in_group("player")
      if player and absf(player.global_position.x - (start_x + end_x)/2) > chase_range:
          # Suspend boss movement or reset fight
          current_state = State.PATROL  # Example: Reset to PATROL
      else:
          # Clamp to arena
  ```
- **Modify arena clamp logic** in each boss's `_clamp_to_arena` to allow **partial movement beyond walls** if the player is outside (e.g., allow 20% of the boss's speed to "leak" past the clamp).

**Why this works**:
- Prevents the boss from freezing against walls when the player retreats.
- Avoids teleportation or infinite detection range.
- Shared logic in `BossBase` reduces redundancy.

---

### 4. **Boss Speeds and Fairness**
**Current speeds**:
- **Stage 1**: 430px/s (CHARGE) > player's 240px/s.
- **Stage 2**: 345px/s (MIN_PURSUE_SPEED) > 240px/s.
- **Stage 3**: 385px/s (Phase 3) > 240px/s.

**Survivability issues**:
- **Contact is instant death** (no hitstun or partial damage), making evasion binary.
- **Counter-play**:  
  - **Distributor's Hoard Gravity**: Pulls the player toward the boss, forcing precise movement.
  - **Claim Jumper's hop mechanic**: Allows the boss to reach raised platforms, but current code causes wall-ping-pong (line 612 in `claim_jumper.gd`).

**Recommendations**:
- **Reduce boss speeds** to 1.2–1.5x player speed (288–360px/s) to allow kiting.
- **Add hitstun** on player damage (e.g., 0.5s invulnerability after contact).
- **Tune Hoard Gravity** to push the player away instead of dragging them in.

---

### 5. **Stage 3's Contradiction**
**Reported "too easy" vs. "does not move"**:
- **Photogrammetry**: Player kiting at 240px/s vs. boss's 290–385px/s (Stage 3's speeds) should be challenging.
- **Code flaw**: The Claim Jumper's **VULNERABLE state** has `VULNERABLE_DRIFT = 250px/s` (line 104), but the boss **backs off to 96px separation** (line 110), creating **safe windows for attacks**.
- **Exploitation**: Players can **stay at the arena edge**, forcing the boss to clamp while attacking.

**Fix**:
- **Remove VULNERABLE_SEPARATION** or reduce it to 48px (half of 96px) to keep the boss in range for contact damage.

---

### **Summary of Key Fixes**
1. **Auditor's CHARGE State**:  
   - Update `charge_target` dynamically in `_physics_process`.
   - Apply delta scaling to `move_toward` in VULNERABLE.

2. **Shared Clamp Logic**:  
   - Extend arena clamps when the player is near the edge (e.g., allow 20% speed past the wall).

3. **Speed Balance**:  
   - Reduce boss speeds to 1.2–1.5x player speed.
   - Add hitstun on contact.

4. **Claim Jumper's Vulnerable State**:  
   - Remove or reduce `VULNERABLE_SEPARATION` to prevent safe kiting.

These changes address the root causes without violating constraints (no teleportation, infinite range, or state machine bypasses).