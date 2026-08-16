=== DISPATCH PLAN ===
Model:          moonshotai/kimi-k3
Prompt file:    prompts/residuals-kimi.md
Files inlined:  0
Est. input:     ~456 tokens (context limit 1048576)
Rates:          $3/1M in, $15/1M out
Worst-case cost: $0.3614 (at max_tokens=24000)

=== DISPATCH COMPLETE ===
Input tokens:  641
Output tokens: 6919
Actual cost:   $0.1057

=== RESPONSE ===

**Not provided (needed to verify, currently reasoning from your prose only):** Gideon's dialogue-panel script, the Assay-Scale Area2D script (`_stake_at`), `GoldMineSystem`, the Claim Jumper state machine, and the headless gate test. Nothing below invents API; gaps are flagged inline.

## A — Fort Knox

**Recommendation: Option 2.** Fix Gideon's copy + make the altar a 2-step confirm. Keep `GoldMineSystem.stake_in_fort_knox` single-caller. Do not put a Button inside a dialogue panel whose input is polled in `_process`.

Why Option 1 is the riskier change: when a focused `Button` activates via `ui_accept`, `Input.is_action_just_pressed("ui_accept")` still returns **true** in the panel's `_process` poll that same frame — state polling ignores GUI event consumption (only `_unhandled_input` + `accept_event()` does). Result: stake fires **and** dialogue advances/closes on one keypress.

Pitfalls to handle regardless of option:

1. **Same-frame bleed on open/close.** If the altar opens/arm on `interact` and the panel also advances on `interact`, whichever `_process` runs second still sees `just_pressed == true` that frame. Closing Gideon with E while standing in the Area2D will instantly arm/fire the stake. Guard: ignore `interact` for ~2 frames after panel open/close (frame-counter timestamp), or require a fresh press after release.
2. **If you do add a CONFIRM button:** mouse-click is safe; keyboard focus is not (see above). Either don't let it grab focus, or have the dialogue's advance poll skip the frame the button activates.
3. **ESC during armed state:** define behavior — disarm-first-press vs. close-and-disarm — and ensure `ui_cancel` doesn't also reach a pause handler the same frame.
4. **Walk-away exploit:** armed confirm must disarm on `body_exited`, or the player arms, leaves, and presses E remotely.
5. **Guard verification (not visible in provided material):** confirm `stake_in_fort_knox` itself checks prerequisites (25% gold present, not already staked) rather than relying on the altar script — otherwise any second entry point or a same-frame double-poll grants double shares.

Copy: replace "Hit CONFIRM" with direction to the scale; altar prompt shows the numbers and a literal CONFIRM: `Stake 25% (N) gold → 2,888 shares — [E] CONFIRM / [ESC] CANCEL`. First E arms, second E calls `_stake_at()`. This directly answers the founder's "no CONFIRM" complaint at the place the mechanic already lives.

## B — Claim Jumper

**(1) Why headless passes, live fails — ranked suspects:**

1. **The gate tested the wrong link.** "Tracks the player 400px wall-to-wall" validates the drift math, not the PATROL→CHASE aggro chain. If the live complaint is "never leaves patrol," the defect is detection: Area2D collision mask not including the player's layer, `body_entered` not connected, or player-group lookup failing. Headless spawns typically bypass level collision setup. Confirm which state the gate asserted tracking in.
2. **Stale/null player ref.** If the boss caches the player in `_ready` or on first aggro, live spawn order or a player respawn leaves him chasing a freed node or old coordinates. Headless never respawns. Needs an `is_instance_valid` re-fetch (verify how the ref is obtained — not provided).
3. **Clamp inversion in your own constants:** `patrol_speed 290` > `MIN_CHASE_SPEED 280`. As stated, chase can be *slower* than patrol — that reads exactly as "doesn't chase." Verify whether the clamp is `max()` or `min()` (code not provided). Chase should be 320/360/400 by phase with floor 300.
4. **Frame-rate dependence.** Browser tabs run 30–45fps vs. headless fixed tick. If drift/chase uses a per-frame step without `delta`, or mixes `_process` movement with physics-frame timers (1.2s beat, vulnerable window), chase speed and timing desync live.
5. **Geometry.** Flat 400px corridor vs. live slopes/ledges — wall rays or an `is_on_floor()` gate flipping direction would abort chase live.

Fastest live diagnostic: on-screen debug print of current state + target position + FPS. One run settles whether it's detection (never enters CHASE) or movement (enters, moves wrong).

**(2) Retune — the actual defect is that VULNERABLE drifts *toward* the player, delivering him to the weapon, while being harmless.** Threat must come from offense, not the old freeze:

- **Dynamite continues (accelerates) during VULNERABLE** — cadence 1.4s / 1.1s / 0.85s per phase. Vulnerable = open to damage, not inert.
- **Per-window damage cap:** `vulnerable_damage_cap` 2 / 2 / 1, window ends early on cap. With HP 14 that forces ≥7 cycles — deterministic fight length, no burst-down. (Keep 18 HP only with cap 3.)
- **Shorten window:** `vulnerable_time` 0.75 / 0.6 / 0.45 (0.9 is a free combo).
- **Separation floor on the drift:** chase to ~56px, then hold distance — player must reposition between hits instead of point-blank wailing. Phase 3: lateral strafe instead of inward drift.
- **Punish whiffed windows:** window expires with no hit → 2s enrage (+15% speed, immediate dynamite throw). Keeps aggression demanded without any vx=0 state.
- **Check (not stated):** confirm contact damage stays ON during VULNERABLE; if the stagger disables his hitbox, that's the punching-bag source.

One-line summary: A is a copy/affordance defect — fix the words and add the confirm where the stake already happens; B is likely a detection-chain or clamp defect (not a drift defect), and the difficulty fix is offense during vulnerability, not immobility.
