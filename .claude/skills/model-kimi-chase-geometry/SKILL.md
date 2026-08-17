---
name: model-kimi-chase-geometry
description: Explicit Kimi K3 skill for Stage 2 Distributor and Stage 3 Claim Jumper chase physics, real-arena geometry, and Stage 3 walk-path / functionless-prop audit. Use when founder reports bosses still do not move or chase after repeated prior fixes.
---

# Kimi K3 — Chase Physics + Geometry

Founder has reported the 2nd and 3rd bosses "still don't move / still don't chase" more than ten times. Prior headless gates and synthetic arenas have failed him. Your job is independent re-derivation from the live files with zero memory of previous "FIXED" claims.

## Mandatory inputs

- `src/boss/distributor.gd` + `distributor.tscn`
- `src/boss/claim_jumper.gd` + `claim_jumper.tscn`
- `src/boss/boss_base.gd`
- Real arena bounds from `level_02` and `level_03` data
- Player sprint speed (200 × 1.2 = 240 px/s)
- Any `?boss=N` warp or real-level probe already in the repo

## Questions you must answer (falsifiable)

1. In the **real** Stage 2 arena, can the Distributor close distance on a player who is moving (not standing still)? Measure travel over a full action cycle, not a 2-second window.
2. Does any state (especially VULNERABLE / THROW / HOARD) zero horizontal velocity or pin the boss against an arena wall so he appears frozen?
3. In the **real** Stage 3 arena, does Claim Jumper pursue, and does VULNERABLE_DRIFT + VULNERABLE_SEPARATION leave him able to kill a player who is not suicidal?
4. Are there invisible colliders, overhanging props, or 1px ledges on Stage 3 main path that force jumps where walking should work?
5. List every non-platform spawn on Stage 3 that has no clear gameplay function (enemy, collectible, power-up, interactive). Prefer deletion candidates.

## Output format (Claude must receive this)

- Root cause (1–3 sentences) with exact line / constant names
- Minimal numeric or state-machine change that fixes it
- A gate that fails on pre-fix code and passes on post-fix code (real arena preferred)
- Explicit "still open" items if any

Do not invent new boss states. Prefer fixing the existing state machine so it actually reaches the intended behaviour.
---
