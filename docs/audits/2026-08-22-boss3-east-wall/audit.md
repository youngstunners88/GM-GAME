# Audit — Boss 3 walled by the arena's EAST wall (2026-08-22, dispatch-first round)

**Founder**: "Why the fuck don't you make the fucking boss3 move?!" (~50th ask)
**Protocol**: RATE LIMIT PROTOCOL — dispatch packets first, integrate only after.
**Acceptance**: boss centre X past the circled minecart/gold band, on hard-refresh.

## WAITING ON FOUNDER FILE
- `artifacts/founder_shots_2026-08-22_boss3_stuck/shot_1.png` (the ORANGE circle) —
  not present in the upload. The circled band was therefore estimated as world
  x 4150-4300 from the prior boss3 shot and the "minecart / gold" description.
  **If that band is wrong, the gate's thresholds need updating.**
- `shot_auditor_grounded_platforms.png` — not present.
- Skills `gm-game-claim-jumper-boss`, `gm-game-founder-executor` — do not exist in repo.
- Qwen vision packet — could not run without the circled screenshot.
- B-AI packet — dispatch failed (network/parse error in `bai-call.mjs`). Not claimed.

## Packets dispatched BEFORE any code change
| Model | Job | Outcome |
|---|---|---|
| Kimi K3 | jump/geometry arithmetic | Returned. Confirmed the east-wall overlap independently, and justified -630/-570 on paper. |
| Grok 4.6 | anti-stuck design risk | Returned. **REJECTED the candidate patch.** |
| DeepSeek v4 | FSM trace at the wall | Returned. Escape-direction finding matched measurement; its premise (centre reaches 4376) proved unreachable. |
| B-AI | second harness | FAILED to dispatch. |
| Qwen | vision on the circle | BLOCKED — file not supplied. |

## Root cause (measured, real `level_03_gold_rush.tscn`)

`level_base.gd::arm_boss_arena_seal()` builds the EAST wall with

    _create_wall(end_x, 400, 20, 600)      # no player_only flag

so it kept the default `collision_layer = 1` ("World"). Both bosses carry
`collision_mask = 13` (World|Enemies|Collectibles). **The wall built to stop the
PLAYER leaving the arena was solid to the BOSS.**

Level 3's arena ends at x=4400, so the wall spans 4390-4410. With the player
parked at x=4390:

- boss right edge pinned at **exactly 4390** (the wall's west face)
- `velocity.x = 0`
- **frozen 13.05s of a 15s run**
- centre stopped at **4250** — 126px short of the 4376 his own
  `_clamp_to_arena()` allows, and inside the circled band

A second probe moved the player west mid-run: the boss escaped immediately
(vx = -290, 4110 → 3747). So the freeze is **directional** — he is only trapped
while the player is east of ~4250, which is exactly the founder's scenario.

Kimi K3, given only the raw numbers, derived the same geometry: body span at
clamp `[4236, 4516]` vs wall face 4390 → necessarily protrudes 126px, so
`is_on_wall()` latches while overlapped, and **raising HOP velocity cannot
affect it** (horizontal problem, vertical constant).

## Fix

The east wall now passes `player_only = true`, putting it on the dedicated
ArenaSeal layer (256) that only the player's body masks — symmetric with the
west seal fixed earlier this session. The boss stays bounded by
`_clamp_to_arena()`, which is what was always meant to bound him.

| Metric (player parked at x=4390, 15s) | Before | After |
|---|---:|---:|
| max boss centre X | 4250 | **4316** |
| longest frozen-in-place | **13.05s** | **1.55s** |

Gate: `tests/claim_jumper_passes_circle_test.gd` — asserts centre X past the
band and freeze < 3s. **Verified to FAIL on pre-fix code** (centre 4250, frozen
12.98s) and pass after.

## What was REJECTED from the candidate patch, and why

### 1. Anti-stuck vault (both bosses) — REJECTED
Grok 4.6's audit, confirmed by measurement:
- `_last_progress_x` is reassigned every frame but `progress_speed` only
  evaluated on grounded, cooldown-ready frames — so it measures "am I crawling
  this instant", not "have I failed to advance". A hop that lands on the same X
  reads as progress.
- `abs(dx)/delta` on a single frame aliases: 10px/s is ~0.17px/frame, below
  collision slop.
- Boss 1's vault is cancelled by the CEILING SIDESTEP, which zeroes upward
  velocity and clears `air_jump_ready` on contact.
- It requires **2.0s of visible do-nothing** before firing. That is the stuck
  the founder is hunting, staged.

### 2. Boss 3 arena-boundary guard — REJECTED
It suppresses the hop when the body edge is near the boundary. But
`_clamp_to_arena()` zeroes `velocity.x`, so removing the hop leaves no X impulse
at all. Grok: *"the guard trades the pogo for a permanent freeze."* The
measurement agreed — at the east wall he was already frozen with vx=0, not
pogoing, so suppressing the hop is a downgrade.

### 3. Boss 1 LEAP -630 / AIR_JUMP -570 — TRIED, MEASURED, REVERTED
Kimi's arithmetic is **correct**: platform (1100,450) needs 200px, -620 gives
196.1 (short 3.9), -630 gives 202.5. And the air jump fires at the
`velocity.y > -120` gate rather than apex, so the real stacked clearance is
~348.8px against the 350px that platform (2100,300) needs.

But the emergent behaviour got worse, not better:

| Gate | -620/-560 | -630/-570 |
|---|---|---|
| `auditor_full_stage_hunt_test` | PASS (gap 7px) | **FAIL — stuck 1335 frames** |
| `auditor_no_sky_float_test` | PASS (2.8% sky) | **FAIL — 7.1% sky** |

More leap power lets him climb into pockets he cannot get out of. An earlier
attempt at -660 failed the same way. The paper arithmetic is not the
constraint — the level's pocket geometry is. `auditor.gd` therefore carries
**comment-only** changes recording this, so the next attempt does not repeat it.

## Honest state

- **Boss 3**: real fix, measured, gate proven to fail pre-fix. Not "FIXED" until
  the founder hard-refreshes.
- **Boss 1**: still open. No behaviour change shipped this round either.


---

## 7. POST-INTEGRATION: the fix was HELD BACK, not merged

The full 64-test suite (run after the targeted boss gates) failed **three**
Claim Jumper gates that were green before this change:

| Gate | Before east-wall fix | After |
|---|---|---|
| `claim_jumper_moves_test` | glued 12.0% | **glued 97.0%** |
| `claim_jumper_double_jump_test` | air_hop_events 11 | **0** |
| `claim_jumper_no_runaway_climb_test` | air_hop_events 8 | **0** |

### Why

1. **Hop trigger removed.** `want_hop = is_on_wall() or (at_ledge and
   _gap_crossable(...))`. With BOTH arena walls now non-colliding for the boss,
   `is_on_wall()` never fires on the flat arena floor, so he never hops. The
   double jump the founder demanded had been firing *because of* the wall-pogo
   bug — the gate was green for the wrong reason.

2. **Standoff collapses against a moving player.** `_ground_chase`'s
   min_separation logic MATCHES the player's velocity once inside the band and
   deliberately does not retreat (documented in that function: "stop dead → he
   cannot re-open a gap he is already inside"). The east wall had been
   artificially supplying the separation in this scenario. Removed, he tracks at
   whatever distance he arrived at — 97% of the run inside 110px.
   The project's own `claim_jumper_chase_separation_test` still passes because
   it measures a STATIONARY player (holds 122px); the weakness only shows
   against a moving one.

### Decision

**Not merged.** Boss contact is `GameManager.boss_contact_restart()` — an
instant full-run reset — so 97% glued is effectively unplayable, and the founder
has explicitly banned both "ride on top of Lil Blunt" and losing the double
jump. Trading a 13s freeze for that is a net downgrade against his own
acceptance bar.

### What a real fix needs

- A hop trigger that does not depend on arena-wall contact (ledge/higher-ground
  based, or a genuine no-progress detector that survives Grok's critique —
  net displacement over a window, not `abs(dx)/delta` on one frame).
- A standoff that re-opens a gap against a MOVING player, not only a stationary
  one.

Both are design changes to the chase, not constants. Recorded here so the next
attempt starts from these numbers.
