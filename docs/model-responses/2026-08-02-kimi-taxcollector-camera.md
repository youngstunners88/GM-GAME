<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-taxcollector-camera-audit.md
     files inlined: 4
     tokens: 12851 in / 20176 out
     cost: $0.3412
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Findings

1. **MEDIUM — auditor.gd:129 + 131–141 — `charge_target` is written exactly once (PATROL→CHARGE transition) and never re-read during CHARGE.** Only exits are `state_timer <= 0.0 or is_on_wall()` (line 136), so staleness = up to the full 1.4s. Player run speed isn't in the provided files (player.gd not given), but at any plausible 200–300 px/s that's 280–420px of drift — the boss charges a ghost. Fix: re-capture `charge_target` each frame in CHARGE (homing), or shorten the lock window (e.g. 0.5s) and re-aim on entry.
2. **MEDIUM — auditor.gd:133 — stale target is worse than "outdated": `direction_to` is a 2D-normalized vector but only `dir.x` is used.** A target above/below the boss shrinks horizontal charge speed (player directly overhead → `dir.x ≈ 0` → boss charges in place for 1.4s, then goes VULNERABLE). If the boss overshoots the stale point, `dir.x` flips sign and it oscillates around the spot until the timer ends. Fix: use `signf(charge_target.x - global_position.x)` for the horizontal drive, or home per-frame per #1.
3. **MEDIUM — auditor.tscn:14 — `collision_mask = 15` includes layer 2 (Player) and layer 4 (the boss's own/enemy layer).** CharacterBody2D collides with CharacterBody2D, so **the player is a wall to the boss**: first contact during CHARGE trips `is_on_wall()` (auditor.gd:136), ending the charge with the hitbox still off — the charge itself never deals damage. Any layer-4 enemy standing in the arena is likewise a physical blocker. Fix: mask = 1 (world only) + whatever layer 8 is if needed; let the Hitbox Area2D own all player interaction.
4. **LOW — level_base.gd:311–315 — `_setup_camera_limits()` fails silently** if the group lookup or `get_node_or_null("Camera2D")` misses; a renamed camera node silently resurrects the exact bug being fixed. Fix: `push_warning`/`push_error` in both null branches.
5. **LOW — player.tscn (not provided) — the hardcoded `limit_right = 3400` still exists as a landmine** for any scene that spawns the player but doesn't extend LevelBase / isn't secret_realm / prototype_room. Fix at source: set the .tscn default back to Godot's `10000000` and treat LevelBase's override as the single owner.
6. **LOW — auditor.gd:200 vs header auditor.gd:5 — phase 3 never starts at 33%.** `ratio <= 0.33` excludes health=2 (2/6 = 0.3333 > 0.33), so P3 begins at 1 HP (~16.7%), a one-hit enrage window. Fix: integer compare, e.g. `health <= maxi(1, max_health / 3)`. (The health-bar pips at 3 and 1 happen to match the *actual* switch points; the `_ready` comment "50% and 25%" is wrong, not the bar.)
7. **LOW — auditor.gd:23 — `state_timer` initializes to 0.0,** so the very first physics frame of PATROL satisfies `state_timer <= 0.0` → the boss charges immediately on spawn, targeting wherever the player stood that instant. Fix: initialize `state_timer` to a real patrol beat (e.g. 2.0).
8. **LOW — auditor.gd:175 and ~:333 — `hp_before` is assigned and never used** in both `take_damage` and `_take_reflected_damage`. Delete.

## 1. Camera fix completeness

**Correct and complete for the LevelBase path.** Call order at level_base.gd:28–30 is `_setup_boss_arena()` → `_spawn_player()` → `_setup_camera_limits()`. `_setup_boss_arena()` (221–226) only builds the far wall and never touches the camera, so its position relative to the camera step is irrelevant; what matters is that camera setup runs after player spawn, and it does.

**No race.** `add_child(player)` is synchronous: the child's `_ready()` and scene-file group registration complete before `add_child` returns, and `_setup_camera_limits()` executes on the next line of the same `_ready()` on the same thread. The secret-realm early return (286–290) also calls `add_child(player)` *before* returning, so that path is covered too. Two assumptions are unverifiable from the provided files: that player.tscn registers the `"player"` group (the kill zone at :175, the seal `_process` at :255, and token perks all already depend on it, so it's a safe bet) and that the camera is a direct child named exactly `"Camera2D"` — no provided file confirms the node name. That's what finding #4 guards.

**`limit_smoothed` is a non-issue.** Limits are applied exactly once, during `_ready()`, before the first frame is drawn, with the player at spawn or a checkpoint (checkpoints are west of every arena by design). `limit_smoothed` only animates when the camera is *outside* newly applied limits; nothing changes limits at fight time — `arm_boss_arena_seal()`, the seal `_process`, and `set_boss_background()` never touch the camera. The wall-raise/background-swap moment is visually unaffected.

## 2. Auditor arena obstacle

**Plainly: no placed obstacle is findable from the provided files.** auditor.tscn contains only the BossSprite ColorRect, the body shape, and the Hitbox Area2D (which can't block movement regardless). auditor.gd spawns no blocking geometry — Gold Rush platforms (≈:351) are one-way and holder-gated; diamond shards are layer-0 Area2Ds. The LevelBase arena walls are the intended far wall (:226) and the entry seal raised *behind* the player (:251–266).

What the arena actually contains comes from Level 1's **LevelData resource** (`platforms`, `breakable_blocks`, `enemy_spawns` in the arena x-range) — **not provided**. Also **not provided: enemy_base.gd**, so I can't confirm whether regular enemies share collision layer 4. The best in-code candidates for "something blocks the chase" are finding #3 (the player as a wall) and a layer-4 enemy parked in the arena via level data. To close this out I need: Level 1's LevelData (.tres/.gd) and `src/enemies/enemy_base.gd`.

## 3. CHARGE stale-target trace

Confirmed — see findings #1 and #2. Assigned once at :129, never updated; 1.4s maximum staleness; `dir.x`-only scaling makes vertical offset degrade the charge; overshoot causes in-place oscillation; and finding #7 means the first charge targets a player who just walked in. Additionally, CHARGE never updates `sprite.scale.x`, so a charge against `patrol_direction` moonwalks.

## 4. Merge regression risk — specific couplings

- **auditor.gd:173 + :190–191 — the sharpest coupling.** `take_damage` gates on `current_state == State.VULNERABLE`, then hard-codes `current_state = State.PATROL` with a charge-cadence timer. If the merge removes/renames PATROL this is a parse error at best, a boss stranded in a behaviorless state at worst. VULNERABLE's exit (:151–152) has the identical hardcode.
- **auditor.gd:136 — the VULNERABLE *entry* lives only inside CHARGE.** A merged chase with no charge-end = no damage window = `take_damage` early-returns forever = unkillable boss. And if the merged state keeps `is_on_wall()` as the vulnerability trigger, finding #3's mask means **every player contact trips VULNERABLE**. Fix the mask before or with the merge, not after.
- **`patrol_direction` ownership (:112–114 flip; consumed at :123 hop, :159 clipboard fallback, :114 sprite).** In a merged state nothing owns the flip; the hop's `-patrol_direction * 160` becomes "hop away from the player mid-chase" or dead code, and clipboard facing goes stale. `hop_timer`/`throw_timer` decrement globally (:95–96) so nothing crashes — it just silently changes behavior.
- **Phase `patrol_speed` scaling (:208/:213)** only matters in PATROL (:109). Merged chase at `patrol_speed` (90–135 px/s) is permanently kiteable; at `charge_speed` (320) the phase escalation is dead code. Pick deliberately.
- **Spectacle timers are safe.** `_shard_timer` ticks pre-`match` (:101–105), gold platforms spawn from `_update_phase` (:218–220), smoke is signal-driven (:82) — all state-independent. One interaction to note: the Gold Rush perch at boss+(±180, −90) currently *nerfs* the charge via the `dir.x` problem (#2); continuous tracking removes that, which is a holder buff.
- **Unrelated but merge-adjacent:** the difficulty retro-apply in level_base.gd (:380–386) skips the Auditor only because it lacks `analytics_id` — if anyone adds `analytics_id = "tax"` to the boss for metrics during this refactor, the 15% Tax Collector slow-down silently hits the boss too.