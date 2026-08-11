<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-claimreset-chase-numbers.md
     files inlined: 2
     tokens: 14313 in / 14061 out
     cost: $0.2539
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Task A — stale-pickup distance fix

## 1. Stale-signal distance vs 50px claim radius

- Player position after `_reset_player()`: x = 0.0
- Diamond token centre: x = 440
- Horizontal separation: `440 - 0 = 440px`
- `distance_to()` ≥ 440px exactly (equal-y case; any y difference only increases it)
- Claim radius: `26 + 24 = 50px`
- **440 > 50 by 390px — 8.8× the claim radius.** Rejected.
- Even granting the one late physics frame with the player already running again at max speed: `440 - 7.17 = 432.83px`, still > 50 by 382.8px. At 430px/s the player needs `390 / 430 ≈ 0.91s ≈ 54 frames` to re-enter the claim radius; the stale signal is 1 frame old.

## 2. Worst-case legitimate pickup

Constants: player half-extent h = 12 (24px box), token radius r = 26, claim R = 50, max displacement = 430/60 = **7.17px/frame**.

- Head-on edge contact, centre distance at detection: `26 + 12 = 38px` ✓
- Maximum possible centre distance at first overlap — corner graze, player's corner touching the circle: `26 + 12·√2 = 26 + 16.97 = 42.97px` ✓ (margin 7.03px)
- Penetration on the detection frame (leading edge up to ~7px past the boundary) *reduces* centre distance along the approach axis — it cannot increase it. Worst case for rejection is near-zero penetration: 42.97px.
- Conservative bound: even if processing slipped a full frame (it does not for a legit same-flush signal) with the worst motion the game allows (autorun forward-x + vertical away, 7.17px): corner graze at (30.39, 30.39) → `√(30.39² + 37.56²) = √2334.4 ≈ 48.32px` — still < 50, margin **1.68px**.
- The only arithmetic that beats 50 is a full radial reversal (`42.97 + 7.17 = 50.14`), which requires horizontal velocity reversal. The runner doesn't reverse; the only reversal is the candle bounce, which is the crash case — and that teleports the player to 440px away, correctly rejected.

**Verdict: 24px slack is sufficient.** Realistic worst case 42.97px (margin 7.03px); paranoid worst case 48.32px (margin 1.68px). Caveat: if jump/fall vertical speed exceeds 432px/s (>7.2px/frame) the conservative margin shrinks — jump velocity / max fall speed were not provided, so I can't close that last variable.

## 3. Other hazard+collectible pairs

**Missing input: the course layout file(s) with x-coordinates were not provided** — only the `blaze_rush.gd` diff. I cannot grep or enumerate pairs.

What the diff alone confirms:
- The check lives in `_make_smoke_token`'s `body_entered` handler — the shared token factory. Every token gets it, regardless of which hazard precedes it. `claim_radius` is derived per-token from its own `shape.radius` (26) + 24 = 50 for all tokens.
- So the fix class is **hazard-agnostic and confirmed from the diff**: any candle/fud_wall/anything + diamond pair is covered, as long as the token is >50px from the crash respawn point.
- The diff comment asserts "every candle and every fud_wall in every level layout is followed by a diamond ~20px later" — unverifiable without the layout data.
- One gap the distance check cannot cover by construction: a stale pickup for a token whose centre is within 50px of the respawn point (x=0). Whether such a pair exists requires the layout file.

---

# Task B — Distributor chase numbers

## 4. Pursuing-state speeds as written

`HOVER_MAX = 330.0`, `MIN_PURSUE_SPEED = 265.0`, `HOVER_ACCEL = 430.0`, `VULNERABLE_DRIFT = 120.0`. Effective speed = `maxf(330 × scale, min_speed)`; player sprint = `200 × 1.2 = 240px/s`.

| State | Scale | 330×scale | Effective | ≥240? |
|---|---|---|---|---|
| PATROL | 1.0 | 330.0 | **330.0** | ✓ (+90) |
| GRAVITY_TELL | 0.62 | 204.6 | **265.0** (floor) | ✓ (+25) |
| HOARD_GRAVITY | 0.55 | 181.5 | **265.0** (floor) | ✓ (+25) |
| SHARD_THROW | 0.70 | 231.0 | **265.0** (floor) | ✓ (+25) |
| VULNERABLE | 0.0 + override | 0.0 | **120.0** | ✗ **(−120)** |

- Without `MIN_PURSUE_SPEED` the middle three states would be 204.6 / 181.5 / 231.0 — all below sprint. The floor is load-bearing.
- **Flag: VULNERABLE = 120px/s = 50% of sprint.** This is deliberate and documented in the file (damage window, "half a sprint"), and he still closes — it is not a stop. But it is the one state where a fleeing player gains ground: `240 − 120 = +120px/s` for up to 1.6/1.25/0.9s = up to **−192px per window** from the boss's perspective.

## 5. Other reachable "reads as not moving" conditions

- **Climb-clear lock** (`too_low and could_touch → to.x = 0.0`): horizontal chase = 0 whenever he's low and within `|Δx| < 240px` of the player. From spawn-at-player-height he must climb 180px (`body_bottom` from `p.y+120` to `p.y−60`) before closing horizontally — ≈ **0.9s** of zero horizontal pursuit at fight start (accel 430 → 330 takes 0.77s). A sprinting player opens ~216px during it. By design (anti-cheap-kill), but it is the most "not chasing" the current file can look, and it re-triggers after any low close pass.
- **Arena clamp velocity zeroing**: if the player camps a wall, the boss's centre clamps at `arena_max.x − 120`. He pushes into the clamp, `velocity.x` is zeroed every frame, re-accelerates to 7.17px/frame, gets clamped back — net x-motion ≈ 0, pinned ~120px horizontally off the player. Vertical positioning continues. Reachable; reads as hovering in place.
- **VULNERABLE net-loss math (open runway, player holds sprint)** — phase-1 double cycle (7.1s): `+90×3.0 + 25×(0.65+1.4+0.45) − 120×1.6 = 270 + 62.5 − 192 = +140.5px` ≈ **+19.8px/s average closing**. Phase-2 cycle (8.2s): `216 + 15 + 45 + 22.5 − 300 = −1.5px` ≈ **0px/s — net wash**. Phase 3 (7.8s): `216 + 12.5 + 55 + 22.5 − 216 = +90px` ≈ +11.5px/s. Against a perpetual sprinter in phase 2 he mathematically never closes; the hoard pull (≥78px/s displacement for 1.8s) and arena walls are what actually deliver him. If the founder is kiting in phase 2, "still not chasing" is numerically accurate on open ground.
- **No-player branch**: `get_first_node_in_group("player")` null → brakes to 0 at 430px/s². Only reachable during player respawn/scene teardown, not live play.
- **`_hover_brake()`**: defined, **never called anywhere in this file** — dead code, currently zero effect, but it is a full stop if ever wired in.
- **Accel transient**: from standstill or full reversal, reaching 265/330 takes 0.62/0.77s at 430px/s². Brief sluggishness after each sharp turn, not a stop.

No other conditional speed overrides exist in the file — the only sub-sprint values are the three documented above (VULNERABLE 120, climb lock, clamp pin), of which only the phase-2 net-wash cycle and the wall-camp pin are reachable in normal play without a player-caused trigger.