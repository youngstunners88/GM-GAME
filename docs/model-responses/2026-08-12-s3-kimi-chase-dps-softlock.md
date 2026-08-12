<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/s3-kimi-chase-dps-softlock.md
     files inlined: 4
     tokens: 26035 in / 32000 out
     cost: $0.5581
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Q1 — Stage 2 boss: re-derived from zero, real arena

## Setup arithmetic (everything downstream depends on these)

- Spawn origin (4050,550), origin = body top-left, BODY=240 → **spawn centre = (4170, 670)**.
- `_clamp_to_arena` clamps the CENTRE: x ∈ [3700+120, 4400−120] = **[3820, 4280]**, y ∈ **[230, 670]**. Spawn centre y = 670 = the clamp's bottom edge exactly. Body spans y 550–790 against a floor top of 650 → **he spawns 140px (58% of his body) buried in the floor** (cosmetic only; mask excludes World).
- Player origin is centre-of-box (vault facts: "feet 800 / centre 784"). On the y=650 floor: **player centre y = 634**. Jump apex (~92px, per protocol_vault.gd's own comment): centre ≈ 542.
- HOVER_ABOVE = 120 + 130 = **250** → hover target y = 634−250 = **384 standing**, **292 jumping**.

## Check 1 — y-clamp vs climb lock: no deadlock, provable as an invariant

Climb lock engages when `body_bottom > player.y − 60`, i.e. **centre.y > 454** standing (>362 jumping), AND |Δx| < 240.

- The hover target (384 / 292) is **never inside the lock band**, because HOVER_CLEARANCE (130) > CLIMB_CLEAR_MARGIN (60): at ride height his body bottom sits at player.y−130, which is 70px above the lock threshold (player.y−60). The lock is self-clearing by construction — climbing toward the target always exits the band.
- The clamp range [230, 670] contains both targets with ≥62px margin at each end (292−230=62; 670−384=286). The clamp never fights the targeting.
- Worst-case lock dwell: band edge 454 → target 384 = 70px at CLIMB_SPEED 400 ≈ **0.2s of no horizontal motion**, once per spawn/transient. Real cost, not a stall.

## Check 2 — fresh Phase-1 fight, frame by frame: no stuck path exists

`_ready()`: throw_timer=2.2, PATROL, _cycles=0. Every state exit is `state_timer ≤ 0`, and state_timer decrements unconditionally at the top of `_physics_process`:

| t (s) | event |
|---|---|
| 0.0 | PATROL, pursuing at full 345 from frame 1 (accel ramp 345/430 = 0.80s) |
| 2.2 | `_cycles%3==0` → GRAVITY_TELL (0.65s) |
| 2.85 | HOARD_GRAVITY (1.4s) |
| 4.25 | PATROL (throw_timer = `_cadence()` = maxf(1.2, 1.5) = 1.5) |
| 5.75 | `_cycles%3==1` → ETH-orb volley, SHARD_THROW (0.45s) |
| 6.20 | VULNERABLE (1.6s) |
| 7.80 | PATROL (1.5s) |
| **9.30** | `_cycles%3==2` → **first crystal-shard volley** (0.4s) |
| 9.70 | VULNERABLE (1.6s) → cycle repeats, period ≈ 10.65s |

Note: **all five states call `_hover_pursue`** (scales 1.0/0.62/0.55/0.70, VULNERABLE drift 120). There is no stationary state to get stuck in. Also note MIN_PURSUE_SPEED 345 > HOVER_MAX 330 makes `speed_scale` inert — every pursuing state runs at maxf(330·s, 345) = **345**.

## Check 3 — crystal reachability: reachable on paper, but structurally easy to never see

- First crystal volley at **t≈9.3s**, then every ≈10.65s → in a 15–20s window it fires **1–2 times**, and the Phase-1 volley is only **2 shards** (`[0,2,3,4][1]`), non-homing, 260 px/s, 0.12 rad fan.
- Compounding factor: with the chase working (345 vs player 240), he closes on the player in ~2–3s, and any contact = full stage restart. Engagements that end at 2–4s **never reach t=9.3s**. The founder's requested visual is third in the rotation behind two other attacks — in short engagements it is effectively absent even in a correct build.

## Check 4 — silent no-op paths: ruled out inside this file

- Parse-failure audit (the file's own warning: `var x := <Variant>` is a hard error): every variable touching a group-lookup result is either explicitly typed (`var target: Vector2 = ...`, all of `_hover_pursue`) or cast (`as CharacterBody2D` in `_apply_pull`). `claim_jumper.gd` uses the same `var pl := get_first_node_in_group(...)` + `pl.global_position` pattern and **works live** → this engine treats those as unsafe-access warnings, not errors.
- No state ping-pong: `_cycles` increments monotonically; no path resets throw_timer/_cycles except the designed ones.
- Player-group lookup can't be the cause: Claim Jumper lands dynamite on the player via the same group.

**Net chase, re-derived in the real arena (Phase 1):** pursuing 7.4s @345 (+105 px/s vs a 240 sprinter) = +777px; VULNERABLE 3.2s @120 (−120) = −384px → **+393px per 10.65s ≈ +37 px/s average, positive**. Phase 2 (cadence 1.1, HOARD 1.8, vuln 1.25): +577 − 300 ≈ **+277px per 8.0s**, also positive. In a 700px-wide arena he closes any gap in seconds. A build running this file **cannot** read as "doesn't chase."

## Verdict and fix

**Most likely explanation: the live build is not executing this code.** Four independently test-verified chase fixes plus a brand-new, unmistakable white-shard attack all reporting "completely unchanged" is not a tuning failure — the in-file mechanics re-derive clean (above). The fault is upstream of this file: a stale export (master `8371caa` vs export `804e81b` are different artifacts), the exported `distributor.tscn` not referencing this script, or the level gating the boss's processing and never re-enabling it.

Exact fix, in order:
1. **Provenance probe (one line):** add a build marker to `_ready()` — `print("DISTRIBUTOR BUILD: 345/3WAY")` (or an on-screen debug label) — rebuild the export from master, confirm the marker appears live. If it doesn't, the export/scene wiring is the bug; check `distributor.tscn`'s attached script and the export's PCK contents.
2. **Code-level guarantee for symptom 2 (3-line reorder):** put crystals FIRST in the rotation — `0: _throw_crystal_shards()`, `1: _begin_gravity_tell()`, `2: _throw_shards()`. First crystal volley moves from **9.3s → 2.2s** (4.2× sooner), inside even the shortest engagement. Zero mechanical risk: same functions, same timers, only order changes.

**Missing facts I needed:** the level_02 script's boss gating (when arena_min/max are set; whether the boss physics-processes before BossTrigger), `distributor.tscn` wiring, and which commit export `804e81b` was actually built from.

---

# Q2 — Stage 3 boss: the zero-gating math, and the fix

## Current time-to-kill

18 HP ÷ 2.5 DPS = **7.2s** (18 hits; first at t≈0, then 17 × 0.4s → dead at ~6.8s). From any range the axe reaches, in any state.

## Boss offense during those 7.2s

throw_timer = maxf(0.8, 0.85 − 0.3·(phase−1)) → **0.85/0.8/0.8s**; sticks 1/2/3; fuse maxf(1.3, 2.0 − 0.35·(phase−1)) → 2.0/1.65/1.3s; radius 100. Dodge requirement: clear 100+16 ≈ 116px within ≥1.3s → **≤90 px/s needed vs 200–240 px/s available**. A mostly-dodging player takes ≈ **0–1 of 3 HP** across the whole fight. Boss effective DPS ≈