# SESSION 9 SHARED FACTS — Lil Blunt Adventure (Godot 4.3 GDScript)
Co-worker model: terse, Godot-4.3-correct, concrete. Do not restate code.

## The one hard problem: Stage 2 boss (Distributor) "not chasing" — LIVE
Reported every session. Range fixed (projectile lifetime). Speed floors raised 3x.
HOVER_ACCEL 430->1600 (s7). Climb-lock band BODY*0.75->0.6 (s8, marginal).
Kimi K3 s8 root cause (accepted): in the REAL 700px arena (x 3700..4400) the boss
centre can only travel ~460px (half-body 120 inset each wall). The CLIMB LOCK
(`_hover_pursue`: while `too_low and could_touch`, set to.x=0 -> zero horizontal
closing) RE-ARMS on every player HOP: `too_low = body_bottom > player.y - 60`,
and a weaving+hopping player re-triggers it constantly -> boss hovers overhead,
never closes. Every prior headless chase gate used a GROUND-RUNNER that never
jumps, so the lock never fired -> headless-green / live-broken divergence.
Kimi's own conclusion: the proper fix is LOCK HYSTERESIS (a durable cooldown so
the lock can't re-arm every hop), NOT another band tweak.

Key constants (src/boss/distributor.gd):
- BODY 240; HOVER_ABOVE = BODY/2 + 130 = 250 (rides 250px above player centre)
- CLIMB_CLEAR_MARGIN 60; CLIMB_SPEED 400; HOVER_ACCEL 1600; MIN_PURSUE_SPEED 345
- climbing = too_low and could_touch; if climbing: to.x = 0.0 (no lateral move)
- level_02 sets arena_min.y = ay-320, arena_max.y = ay+120 (ceiling 320px up)

## What this session must deliver
- Lock HYSTERESIS so a hopping player can't perma-arm the lock (Kimi design).
- A REAL browser Playwright capture of the S2 fight proving (or disproving)
  sustained horizontal pursuit under player JUMPS — no headless-only "FIXED".
- S3 (Claim Jumper) horizontal-chase gate with a kite path.

## Constraints
- Web export non-threaded. No hardcoded addresses. Godot 4.3 `var x:=<Variant>`
  is a hard parse error. Never re-introduce the boss "sweep-kill on spawn" bug
  (the lock exists to stop the 240px body sweeping sideways through the player).
