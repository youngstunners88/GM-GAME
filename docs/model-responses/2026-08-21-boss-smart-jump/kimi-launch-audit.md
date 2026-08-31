<!-- dispatched: moonshotai/kimi-k3
     prompt: /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/prompts/kimi-launch-audit.md
     files inlined: 1
     tokens: 11385 in / 5736 out
     cost: $0.1202
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**The min_y=86 arithmetic is plausible — no infinite climb.** Single-leap apex: 620²/(2·980) = 196px. The air jump fires at `velocity.y > -120` (~0.51s in, ~189px up) and adds 560²/1960 = 160px → ~356px max per ground contact. From y=650 ground that's y≈294 — 86 is unreachable from ground. From the block top (y=350): 350−356 = −6, so 86 sits inside a block-launched arc. 564px of gain requires exactly one intermediate landing: the signature of real chaining. `_air_jump_ready` is armed only in the two `is_on_floor()`-gated leap branches, spent on use, cleared on ceiling/landing — no mid-air re-arm path. (One fuzz factor: the `hop_timer` block has no floor gate, so a mid-leap hop resets velocity.y to −300, adding ≤46px — immaterial here.) A hover bug would show unbounded negative min_y over 15s, and `is_on_floor()`-based resting can't be faked mid-air.

**Residual failures, frame-level:**

1. **East-biased sidestep.** `_ceiling_escape_dir()` tests dir +1.0 before −1.0 at every distance, so with open sky both ways he always commits east for a locked 1.2s (282px). Approaching the block from the east, a head-bonk under the terrace systematically walks him *away* from the launch pad. No memory, no steering toward the block — only toward the player's column.

2. **Sidestep/wall-leap ordering bug.** The wall-leap (`is_on_wall() and is_on_floor()`) is *not* gated on `_ceiling_sidestep <= 0.0`, but the air jump is an `elif` under `if _ceiling_sidestep > 0.0`. A sidestep driving him into the block's west face fires the 196px leap while the air jump is suppressed; unless the sidestep expires within ~0.5s of takeoff, the second jump never comes and he slides back down — repeatable every 0.55s.

3. **Time-based, not position-based, air jump.** It's spent ~0.51s after takeoff regardless of column. Take off >~200px west of the 100px block and the boosted ~455px arc overshoots it; horizontal steering tracks the player, so mounting happens only when the player's column aligns with the block's.