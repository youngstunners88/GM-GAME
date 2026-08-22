# Grok 4.6 — DESIGN RISK AUDIT ONLY. Do not rewrite logic. Be blunt.

Founder has rejected ~50 prior "fixed" claims on these two bosses. He rejects any
metric that shows bounded Y while X is frozen. Acceptance is ONLY: boss centre X
moves past the spot he circled, on his own hard-refresh.

A candidate patch (written by another model, NOT yet shipped) proposes for BOTH bosses:

  ANTI-STUCK VAULT:
    const STUCK_TIMEOUT = 2.0
    every PATROL frame, if player exists AND is_on_floor() AND _vault_cooldown <= 0:
        progress_speed = abs(x - _last_progress_x) / delta
        player_dx      = abs(player.x - (x + HALF_BODY))
        if progress_speed < 10.0 and player_dx > 120.0: _stuck_timer += delta
        else: _stuck_timer = 0.0
        if _stuck_timer >= 2.0:
            _stuck_timer = 0.0; _vault_cooldown = 3.0
            velocity.y = LEAP/HOP_VELOCITY; air_jump_ready = true
            velocity.x = patrol_speed * 1.3 * sign(player.x - centre)
    _last_progress_x = x   # updated EVERY frame, outside the guard

  BOSS 3 ARENA-BOUNDARY GUARD:
    at_arena_boundary = (x + BODY >= arena_max.x - 24) or (x <= arena_min.x + 24)
    want_hop = (is_on_wall() and not at_arena_boundary) or (at_ledge and gap_crossable)

Context you need:
- Boss 3's centre is clamped to [arena_min+24, arena_max-24]; BODY=280, so at full
  east clamp his right edge is 140px PAST the arena_max line. The east wall is real
  World-layer collision at that line.
- `_clamp_to_arena()` sets velocity.x = 0 whenever it clamps.
- Boss 3 hop cooldown 0.7s; hop airtime ~1.27s.
- Boss 1 has a CEILING SIDESTEP that on ceiling contact does velocity.y = max(velocity.y, 0)
  AND air_jump_ready = false, and locks horizontal direction for 1.2s.
- Boss 1's PATROL also runs a CHARGE state every ~2.5s (state_timer), and the whole
  anti-stuck block lives in PATROL only.

## Deliver 8-10 numbered failure modes. For each: one line trigger, one line why it still freezes/pogos. Then answer:

A. `_last_progress_x = x` is assigned every frame but `progress_speed` is only evaluated
   inside `if pl and is_on_floor() and _vault_cooldown <= 0`. What happens to the
   measurement while airborne or during the 3s cooldown? Is the timer measuring what
   it claims to measure?
B. Is `progress_speed < 10.0` computed per-frame from a single frame's delta reliable,
   or does it alias? What would you use instead?
C. Boss 1: the vault sets air_jump_ready = true, but CEILING SIDESTEP clears it and
   zeroes upward velocity on contact. If he is stuck UNDER a platform, does the vault
   actually help? Trace it.
D. Boss 3: with the boundary guard, at the east clamp `is_on_wall()` is true but hop is
   suppressed and `_clamp_to_arena` zeroes velocity.x. What now moves him off the wall?
   Is the guard trading a pogo for a permanent freeze?
E. Does 2.0s of visible do-nothing before the vault read as "stuck" to a founder who is
   hunting for stuck? What number would you use?
F. Reject or accept: is this candidate patch shippable as-is? One paragraph.
