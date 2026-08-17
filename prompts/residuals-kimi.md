Kimi K3 — code-verification for a Godot 4.3 platformer. Concise, defects only.

CONTEXT A — Fort Knox stake "nowhere to CONFIRM":
- Diamond Vault (Mira) has a full panel with a CONFIRM button + clerk_confirm() -> GoldMineSystem.stake_diamonds/crush. Works.
- Fort Knox uses NPC "Gideon" whose dialogue says "Hit CONFIRM and we'll lock her down tight" but his panel only shows [E] next/close + [ESC] leave — NO confirm control. The real Fort Knox stake is a separate altar/Assay-Scale Area2D: walk in, press E -> _stake_at() -> GoldMineSystem.stake_in_fort_knox(25% gold, 2888) -> float "+N SHARES" + readout refresh. So staking works mechanically but the founder sees no CONFIRM and says "staking never occurs".
Q: Best minimal fix — add a CONFIRM button to Gideon's panel on the last dialogue line that stakes (reusing _stake_at logic) vs. rewriting Gideon copy + making the altar/assay path an explicit 2-step confirm? Flag input-handling pitfalls (the panel input is polled in _process: interact/ui_accept advance dialogue; ui_cancel closes).

CONTEXT B — Claim Jumper (stage-3 boss) "still doesn't chase" live AND "now too easy":
- Fix already shipped: VULNERABLE state now drifts toward player at 120px/s (was vx=0 freeze) + 1.2s opening chase beat. patrol_speed 290 (335 phase2, 385 phase3), MIN_CHASE_SPEED 280, vulnerable_time 0.9 (shrinks per phase), 18 HP, phase_thresholds [12,6].
- Real-level headless gate shows he tracks the player 400px wall-to-wall. But founder rejects it live and says he's too easy to kill.
Q: (1) What could make a headless-passing chase read as "not chasing" in a real browser? (2) If VULNERABLE drift made him a punching bag, what retune keeps chase+threat without a freeze — e.g. shorten vulnerable window, raise DPS gate, faster dynamite cadence? Give concrete constant suggestions.
