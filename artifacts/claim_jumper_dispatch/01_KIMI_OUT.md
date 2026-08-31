<!-- dispatched: moonshotai/kimi-k3
     prompt: artifacts/claim_jumper_dispatch/01_KIMI.md
     files inlined: 1
     tokens: 15157 in / 18040 out
     cost: $0.3161
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Review: `already_high_enough` ceiling on Claim Jumper

**Verdict up front:** the patch genuinely fixes the *unbounded* half of the bug (there is now a hard ceiling on cumulative gain), but it leaves the *loop* half intact — the boss still never gets a grounded chase frame at the wall, he just pogos in a 400–600px band instead of climbing forever. Your own test proves it: 8 air-hops in 16s while pinned means the re-arm cycle is still running; only its altitude is capped. Ship it as a backstop, but don't call the root cause closed.

## 1. Root cause vs. symptom mask

The gate (`global_position.y < pl.global_position.y - 400.0`) eliminates divergence — cumulative climb is now capped at ~400px + one hop rise (~197px) + player-jump overshoot, regardless of how long the player camps the wall. That is a real fix for the specific defect class ("no ceiling on cumulative height gain").

**But the re-arm mechanism is untouched.** `_hop_cooldown = 0.7` is set at *takeoff*, and `HOP_AIRTIME ≈ 1.265s`, so on the landing frame both `is_on_floor()` and `_hop_cooldown <= 0.0` are already true → instant re-hop while `is_on_wall()` is still true. This is the exact "never gets a grounded chase frame" mechanism your own session-6 comment flags. At the wall he now bounces in place within the gated band, indefinitely. If the founder's complaint was "climbs away and never comes back," fixed. If it was "bounces at the wall instead of fighting," still live.

**False-negative vectors in the gate itself:**

- **`pl == null` fails OPEN.** The condition is `pl != null and ...`, so any playerless window (death/respawn, `boss_contact_restart`, scene transition) fully restores the unbounded chain. The file already caches `_last_player_x`; a cached `_last_player_y` fallback (or fail-closed) is a one-line hardening. I can't tell you how long that window is — `GameManager.boss_contact_restart()` wasn't provided, so I don't know if it reloads the scene (boss freed, hole irrelevant) or teleports the player (boss persists, hole real).
- **Player y is a live reference.** Player jumping raises the effective ceiling by the jump apex for the jump's duration. I worked the ratchet: each airborne window authorizes at most one ~196px hop cycle before the gate re-closes (the player must land; to re-arm the boss must first *fall* back under 400, which at a bare wall means falling to the floor). It cannot diverge unless there is real staircase geometry in the 400–600px band — and then he's climbing real platforms, which is legitimate. Player *falling* moves the ceiling down — fail-safe direction.
- **Sustained player ascent would break it.** Flight, ladders, vertical moving platforms, or knockback loops would let the boss ladder-climb alongside the rising reference. The player controller was not provided, so I cannot confirm the player's vertical kit is finite-jump-only. That's the missing file.
- `get_first_node_in_group("player")` can also return a stale/dying node sitting at a checkpoint y during a restart — the gate then references whatever that node's y happens to be.

## 2. Cleaner fix, or accept?

Accept the ceiling as a **backstop**, but the surgical root fix belongs at the **trigger**, not the altitude:

- The bare `is_on_wall()` branch is the only unconditioned hop source (the ledge branch requires `_gap_crossable`, the above-player branch requires `_higher_ground_ahead`). Suppress it when the wall is the arena boundary — the exact test already exists in `_ledge_ahead` (`probe_x >= arena_max.x or probe_x <= arena_min.x`) — unless `_higher_ground_ahead(direction)` finds a real interior ledge. With the player parked outside the arena, that probe finds nothing → no hop → he holds the wall grounded, which is the *correct* read for an unreachable player. Caveat: whether `_higher_ground_ahead` sees decorative geometry beyond the east wall needs `level_03_gold_rush.tscn`, not provided.
- Alternative one-liner: refresh `_hop_cooldown` in the landing-clear branch (`if is_on_floor() and velocity.y >= 0.0:`) instead of only at takeoff, guaranteeing grounded chase frames between hops. This slows legitimate climb cadence, so I prefer the boundary suppression.

**One false-positive the gate introduces:** it's direction-agnostic. It also blocks the `at_ledge and _gap_crossable(direction)` branch — his *only* descent/crossing verb, since `_ledge_ahead` forbids walking off ledges and `_gap_crossable` only accepts landings within +190/−120px of his feet. Sequence: player stands on a high ledge → boss climbs (legit) → player drops 400+ below and runs → every hop is now gated → he's marooned on the ledge with no descent path. Exempt the at_ledge branch from the ceiling (it's self-limiting by design) or only gate hops that don't reduce vertical separation. Whether level 3's "Hall of Blaze" geometry can actually produce a >400px player-below-boss split needs the level file — not provided.

## 3. `_clamp_to_arena()` × gate edges the single-point test won't catch

1. **Inconsistent reference points inside one function.** X clamps the *centre* (`global_position.x + HALF_BODY`); the Y floor clamps the raw *origin* (`global_position.y > arena_max.y`). The origin is the top-left of a 280px box. If `arena_max.y` is authored as a ground/feet line, his feet rest 280px below it. Worse: if he ever falls past it, he's snapped to `origin = arena_max.y` with `velocity.y` zeroed *every frame* → gravity never accumulates → `is_on_floor()` never true → ledge sense skipped, but `_ground_chase` still applies `velocity.x` — he **walks in mid-air along the clamp line**, below the arena, out of the fight. The gate is open down there (he's below the player), so hop/air-hop cycles just bounce ~356px off a floor he can't stand on. Your pinned-player test never exercises the floor clamp. I can't resolve the authoring convention — `level_03_gold_rush.gd`'s arena values weren't provided.
2. **`ARENA_EDGE_MARGIN` (24) < `HALF_BODY` (140) guarantees permanent wall contact at the clamp.** Clamped centre sits at `arena_max.x - 24`, putting his toe 116px past the line — so `is_on_wall()` is structurally *always true* at either wall, and the wall-hop branch re-arms on every landing the gate permits. The gate is the only thing between that and climbing, which is what makes the `pl == null` hole in §1 matter rather than theoretical.
3. **Mid-hop X-clamp zeroes the committed arc.** A hop taken toward a player beyond the wall has `velocity.x` zeroed by the clamp during the arc, so he lands on his takeoff tile with `is_on_wall()` still true — deterministic re-arm. Your test covers this at the *east* wall with a stationary player; it doesn't cover a player who re-enters mid-cycle, where the `CHASE_SEPARATION`-shrunk commit (`target_pdx = 0.0` within 200px) interacts with the clamp-zeroed x.
4. Minor: `_clamp_to_arena()` is called twice per frame in VULNERABLE (inside `_ground_chase` and explicitly) — harmless redundancy. And the `arena_max == Vector2.ZERO` unset path disables both the clamp and the `_ledge_ahead` boundary guard; the gate still bounds height, but nothing else does.

**Missing files I'd need to be definitive:** the player controller (vertical kit — jump apex, any sustained ascent), `GameManager.boss_contact_restart()` (scene reload vs. teleport → size of the null-player window), and `level_03_gold_rush.gd`'s `boss_arena` values (origin-vs-feet question in the floor clamp, and feasibility of an absolute `arena_min.y` ceiling, which would be immune to every player-y manipulation in §1 but can't be validated without knowing the arena's top is actually above all standable ground).