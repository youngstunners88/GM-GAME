<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-chase-tune-audit-plan.md
     files inlined: 1
     tokens: 6587 in / 6838 out
     cost: $0.1223
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Top-line findings

- **Q1's stated risk is inverted:** `dx` is purely positional (`p.global_position.x - global_position.x`) — velocity never enters it, so the ramp can't desync the gate directly. The *real* risk is that `max_jump_gap = 110` was derived from full-speed reach (~149px at 170px/s × ~0.88s airtime). A jump taken mid-ramp has shorter reach, so the gate can approve a jump the ramped boss can't land.
- **Q2:** Nothing else in this file consumes `hitbox.monitoring` except the two signals, and the area path no-ops outside VULNERABLE anyway. The real risks are overlap-at-re-enable semantics and a grace timer outliving a PURSUE exit.
- **Q3/Q4:** Safe *iff* the tune is a pure multiplier on the `velocity.x` line with no new early returns.

### 1. Ramp vs. jump-gap gating
- Confirm `dx` stays positional — no velocity term added.
- Confirm the ramp composes multiplicatively with the existing `speed_scale := patrol_speed / _base_patrol_speed` (P3's +50% must survive): final form should be `toward * pursue_speed * speed_scale * ramp`.
- **Must-test:** `velocity.x` is rewritten every frame including mid-air, so reach ≈ ramped speed × 0.88s. A jump at 50% ramp ≈ 74px < 110px gate → shortfall into a pit. Test: boss at a ~100–110px gap, jump decision landing inside the ramp window. Acceptable outcomes: gate scaled by ramp fraction, jumps suppressed until ramp completes, or demonstrated clearance. Unmodified gate + mid-ramp jump is a fail.
- Verify `jump_force`, `max_jump_gap`, and `_jump_cooldown = 0.9` are untouched.

### 2. Hitbox grace delay
- In-file consumers of the hitbox: only `_on_hitbox_body_entered` (contact damage — intended suppression) and `_on_hitbox_area_entered` → `take_damage(1)`, which is independently state-gated to VULNERABLE, so suppressing it during grace is functionally free. Reflected-shard damage (`_take_reflected_damage`) is distance-driven, not hitbox-driven — unaffected.
- **Must-test:** player standing still, overlapping the boss when grace expires → contact damage must fire *without* exit/re-enter. Godot 4 should re-emit `body_entered` for pre-existing overlaps on monitoring false→true, but verify empirically; if it doesn't, the fix is a `get_overlapping_bodies()` sweep at grace end.
- **Grace cancellation:** every PURSUE exit (`p == null` → PATROL, `state_timer` → VULNERABLE, `take_damage` → PATROL, `die()`) must cancel or invalidate a pending grace activation — otherwise the hitbox turns on during PATROL, a state that currently has no contact damage. If implemented via `create_timer`, the callback must check `is_instance_valid(self)` and `current_state == State.PURSUE`.
- Assert `grace_duration < pursue_duration` (VULNERABLE entry enables the hitbox unconditionally and would silently truncate a longer grace).
- Enable via `set_deferred`, matching the existing pattern.
- **Not verifiable from this file:** `boss_projectile.gd` wasn't provided — if projectile despawn depends on the boss hitbox's `area_entered`, grace lets projectiles fly through. `take_damage` no-ops regardless, but confirm despawn behavior separately.

### 3. Throw cadence & jump logic
- `throw_timer -= delta` stays at the top of `_physics_process` (all states); PURSUE cadence `[0.0, 2.2, 1.7, 1.2][phase]` unchanged.
- **No new early return** above the throw or jump blocks — a ramp implemented as "return during ramp" would skip both. That's the primary fail signature.
- If a ramp-based jump condition is added (per Q1 fix), it must be an *additional* condition, not a moved or removed one.
- Diff signature: only the `velocity.x` assignment plus a new ramp var/reset should change inside PURSUE.

### 4. `_jump_cooldown` / `state_timer`
- `state_timer = pursue_duration` on ALERT→PURSUE and the forced VULNERABLE at exactly 4.0s must be unchanged. If the ramp derives elapsed time from `state_timer`, the denominator must be a dedicated ramp constant (`(pursue_duration - state_timer) / ramp_time`), not `pursue_duration` — otherwise the "ramp" spans the entire chase.
- Any new ramp-elapsed var must reset at the single PURSUE entry site (ALERT exit).
- `_jump_cooldown -= delta` stays the first line of PURSUE, unconditional; do not reset it on entry (≤0.9s carryover between chases is current behavior).
- `hop_timer`/`throw_timer` global decrements untouched.

**Second-pass note:** re-run against the actual diff. Pass signature = one new var + one modified line (ramp), or one state-checked timer/callback (grace). Any edit touching the jump block, throw block, or `state_timer` transitions is an automatic fail pending justification.