<!-- dispatched: moonshotai/kimi-k3
     prompt: /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/prompts/kimi-boss1-jump.md
     files inlined: 1
     tokens: 11094 in / 5462 out
     cost: $0.1152
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**Arithmetic: yes, barely.** The air-jump triggers when `velocity.y > -120.0`, i.e. ~0.51s after take-off at ~189px up (620→120 decay at 980). The -560 second impulse adds 160px, so the chain tops out at **~349px** above take-off. 250–340px is comfortably reachable; 345–350px is knife-edge (frame quantization costs ~2px, and that's measured from the block's stand surface with zero margin for the horizontal travel he still needs). Treat ~340px as the practical ceiling.

**Critical bug: the air jump can never fire at all.** Both arming paths require `is_on_floor()` to be true:

```gdscript
if is_on_wall() and is_on_floor() and _leap_cooldown <= 0.0:
    ...
    _air_jump_ready = true
```

But `is_on_floor()` reflects the *last* `move_and_slide()`, which ran earlier that same frame while he was still grounded. So on the arming frame itself, execution falls through to:

```gdscript
if is_on_floor():
    _air_jump_ready = false
```

and the flag is cleared **before he ever leaves the block**. Next frame he's airborne but `_air_jump_ready` is already false. This is almost certainly the real history behind "Why cant he double jump in any event!!!" — the player-gate removal didn't fix it because the gate was never the (only) thing preventing it.

**Fix (one line):** `if is_on_floor() and velocity.y >= 0.0:` — on the take-off frame `velocity.y` was just set to -620 so the clear is skipped; on a genuine landing `move_and_slide()` has zeroed/positivized `velocity.y`, so it still clears.

**Secondary risk:** the air jump spends itself at the fixed -120 threshold regardless of headroom — if the platform underside sits between ~190–350px, he fires the second jump straight into it (then ceiling-sidesteps, by design). If the founder wants reliable block-launches, gate the spend on an upward ray (reuse the `_ceiling_escape_dir` probe pattern) so he only air-jumps into open sky.