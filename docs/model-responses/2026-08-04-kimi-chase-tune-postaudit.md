<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-chase-tune-postaudit.md
     files inlined: 1
     tokens: 7119 in / 10156 out
     cost: $0.1737
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Findings

**LOW** — src/boss/auditor.gd:231 (gate) + :223 (ramped `velocity.x`) — The ramp silently undercuts the kinematic premise of `max_jump_gap`. The 110px gap was derived at full `pursue_speed` (170 → ~149px reach over ~0.88s airtime), but `velocity.x` is ramp-scaled *every frame, including airborne*, so a jump triggered early in PURSUE has reduced horizontal reach (worst case ~0.55×170 ≈ 94 px/s at launch, ramping to 1.0 mid-flight → ~106px average reach < 110px gate). A jump fired in roughly the first ~0.2s at a gap near the limit can now fall short — the gate condition is unchanged, but its "he never commits to a leap he can't land" guarantee is voided during the ramp. **Fix:** scale the gate by the current ramp: `absf(dx) <= max_jump_gap * ramp` (or suppress gap jumps until `_pursue_elapsed >= 0.7`).

No other regressions found. Per-question verdicts:

**1. Hitbox state on early PURSUE exit — PASS.**
- Player-null exit (:209–210) defers `false/false`. If the grace fired on that same frame (grace block runs before the null check), the deferred `true` then `false` apply in call order at frame end — last write wins, hitbox ends disabled. If grace hadn't fired, the `false` writes are redundant but harmless.
- VULNERABLE entry (:245–246) unconditionally sets `true/true`, matching pre-tune behavior. With `pursue_duration = 4.0` the grace has always fired by then; even if a designer tuned `pursue_duration < 0.35` (skipping the grace entirely), the end state is still correct.
- `take_damage()` and `die()` both force `false/false`. No stuck-enabled or stuck-half-configured path exists.
- Note: during the grace window `monitorable` is also false, so player attack areas can't overlap the hitbox — but `take_damage()` is VULNERABLE-gated anyway, so zero functional change.

**2. Reset on every ALERT→PURSUE — PASS.** :185–186 reset both vars unconditionally, and ALERT is the *only* PURSUE entry point (verified: no other `current_state = State.PURSUE` assignment in the file). Every re-chase — later phase, post-VULNERABLE, post-player-null — gets a fresh ramp + grace.

**3. Jump gating / throw cadence — PASS (with Finding 1 caveat).** `dx` is a pure position delta, `max_jump_gap` untouched, `throw_timer` decremented globally and reset from the same per-phase tables. Conditions are byte-identical; only the jump *outcome* is affected (Finding 1).

**4. Ramp expression float edges — PASS.** Divisor is the constant 0.7 (no div-zero), `_pursue_elapsed` is monotonic from 0.0, `clampf` caps t at [0,1] so a frame hitch can't overshoot, and `lerpf(..., 1.0)` returns exactly 1.0. No NaN path.

**5. Jump velocity not ramped — PASS.** `velocity.y = jump_force` (:232) has no ramp factor; `ramp` appears only in the `velocity.x` expression (:223).

**Missing file (unverifiable, pre-existing — not a tune regression):** `auditor.tscn` was not provided, so the hitbox's *spawn-time* `monitorable`/`monitoring` defaults can't be confirmed. `_ready()` never explicitly disables them; if the scene ships them enabled, contact damage is live during the initial PATROL until the first PURSUE exit disables it. Worth a one-line `hitbox.set_deferred(...)` pair in `_ready()` if the scene default is on.