<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/2026-08-19-boss-shared-rootcause.md
     files inlined: 4
     tokens: 37928 in / 21185 out
     cost: $0.4316
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
Verdict up front: the proposed root cause is **confirmed for the Stage 2 screenshot, plausible for Stage 3 live play, and structurally impossible for Stage 1** — so it is not the shared root cause. Note on citations: the source was provided without line numbers, so I cite file + exact quoted line.

## 1. The clamp hypothesis — confirm where it holds, refute where it doesn't

**Confirmed for Stage 2's screenshot.** `distributor.gd` `_clamp_to_arena()` clamps the body centre to `[arena_min.x + 120, arena_max.x - 120]` = [3820, 4280] for arena 3700–4400, and zeroes `velocity.x` on contact with the bound. The photogrammetry (boss at ~3813, player at ~3109, 591 px west of `start_x`) matches this exactly: `_hover_pursue` computes `target = p.global_position + Vector2(_standoff_side * standoff_now, -HOVER_ABOVE)` ~700 px beyond the wall, velocity rebuilds toward it every frame (`velocity.move_toward(to.normalized() * speed, HOVER_ACCEL * delta)`), and the clamp zeroes it every frame. He is pinned at the west clamp reading vx≈0 at any sample instant. The seal dropped because the player is west of `start_x - 40`. The fight never suspended. That is the screenshot, fully explained.

**Refuted as the shared cause, four ways:**

- **Stage 1 cannot have this cause.** `auditor.gd` contains no `arena_min`/`arena_max` and no `_clamp_to_arena` anywhere in the file — he extends `CharacterBody2D` directly, not `BossBase`. The boss with the *worst* score (−0.20) is the one boss the hypothesis cannot apply to.
- **It doesn't explain the in-arena freezes.** With the player *inside*, the harness still measured frozen 28% (S2) and 17% (S3). S2's 28% ≈ its clamped_at_wall 28%, so the clamp covers that one. But S3 shows clamped_at_wall **0%** with frozen 17% — that freeze is `claim_jumper.gd`'s own making: the PATROL hop sets `target_pdx = 0.0` whenever `absf(pdx) <= CHASE_SEPARATION` (a straight-up, zero-vx hop with 1.265 s airtime, re-armable on landing since `_hop_cooldown` 0.7 < airtime), plus `_ledge_ahead` zeroing `velocity.x` at lips.
- **A clamp produces zero correlation, not negative.** Stage 1's −0.20 needs an active away-from-player mechanism (section 2).
- **The clamp is the symptom-enforcer, not the defect.** The actual shared defect is one level up: **the fight has no lifecycle contract.** The seal explicitly drops at `start_x - 40`, nothing suspends or resets the fight when the player leaves, and each boss is left alone with an unreachable target — two of them park at a clamp, one (no clamp) wanders his own broken state machine. Fix the contract, not the clamp.

## 2. Stage 1's negative tracking score

First, a discrepancy I have to flag honestly: the pasted `auditor.gd` **does** re-read the player every frame in CHARGE (`var live := get_tree().get_first_node_in_group("player")` / `charge_target = (live as Node2D).global_position`) and **does** delta-scale VULNERABLE (`move_toward(velocity.x, VULNERABLE_DRIFT * drift_dir, WALK_ACCEL * delta)`). If the live build matched this source, those two mechanisms would be absent. The instrumentation says otherwise, and the fingerprints match the pre-fix code exactly:

- **Stale `charge_target` (as the live build behaves):** 1.4 s × 240 px/s = up to ~336 px of player travel after the snapshot. A player who reversed past him during the 2.5 s PATROL gets a charge fired 180° away — a hard negative-correlation pulse for ~28% of every cycle, usually ending on `is_on_wall()`.
- **Unscaled `move_toward(velocity.x, 0.0, 200.0)`:** 200 px/s bled *per call* = ~12,000 px/s² at 60 fps — dead stop in two frames, then parked for the whole 1.1 s window. That is ~22% of the cycle at vx=0, and with wall-ended charges and PATROL dead-zone it lands right on the measured frozen 33%. The file's own comment records the same signature ("parked at exactly x=3030.0 and x=3280.0 with vx=0.000").

Conclusion: the comments claim fixes the live build does not exhibit. Verify what actually shipped.

**And even with those fixes present, the pasted code still loses to a held sprint.** Phase-1 cycle-mean pursuit speed: (2.5 s × 140 + 1.4 s × 430 + 1.1 s × 120) / 5.0 s = **~217 px/s < 240**. `distributor.gd`'s `MIN_PURSUE_SPEED` comment does exactly this arithmetic for boss 2; nobody ever did it for boss 1. Phase 3 barely clears it (~262). Two more current-code negative contributors: the reposition hop deliberately moves him *away* — `velocity.x = lerpf(velocity.x, -patrol_direction * 150.0, 0.45)` with `patrol_direction` pointing *at* the player, every 6 s (3.5 s in P3) — and VULNERABLE's 34 px dead zone (`drift_dir = 0.0`) brakes him to a stop whenever the player is nearly overhead.

## 3. Minimal shared fix — one lifecycle, not three hacks

The missing piece is a **boss-fight lifecycle contract**, implemented once, in the level/seal layer (the level scripts and seal-wall code were **not provided** — `level_01_smoke_realm.gd` etc. are where this belongs; I can't cite integration points I haven't seen):

1. **Seal is un-droppable while boss lives and player lives.** Delete the `start_x - 40` drop during a live fight.
2. **Player death/respawn with boss alive → fight RESETS:** seal drops, boss HP/phase/state restored to fight-start. This is the exact soft-lock the drop was added for — note `boss_contact_restart()` reloads the whole level, so the lock only comes from *projectile* deaths (e.g. `_on_shard_body` calls `body.take_damage(1)`, a normal respawn at the checkpoint west of a raised seal). `StateMachine.is_dead()` already exists and is used by `distributor.gd._apply_pull` — hook respawn the same way. Respawned player walks in, seal rises, fresh fight. No lock possible: the seal only exists while a live player is inside with a live boss.
3. **Player exits while alive (over the seal, pre-seal, warp) → fight SUSPENDS:** boss stops throwing, returns toward arena centre under its own normal movement (real motion — reads as "the boss falls back," not a freeze, not a teleport), and never enters VULNERABLE while suspended, so it cannot be farmed from outside. Re-entry resumes.

Plus: **wire the Auditor into the same contract** — give him `arena_min`/`arena_max` + the same centre-inset clamp the other two already have, and have level 01 actually pass bounds. Do **not** let the clamp follow the player outside: that re-opens the exact bugs the clamps were added for (`claim_jumper.gd`'s "HARD ARENA BOX" comment — "he fell into the void below the arena"; `distributor.gd`'s "he fell in the trench"). Do **not** make the seal unconditional without rule 2 — that *is* the original soft-lock.

## 4. Faster-than-player + instant run-wipe: survivable?

Yes — but only just, and two current-code holes make it unfair. The intended counter-play is visible in the code: every fight is "dodge the telegraph, punish the VULNERABLE window." Speed forces positioning; the window is the kill. That loop is legitimate. The violations:

- **The Auditor's CHARGE is a homing instant-kill, not a commit.** `velocity.x = dir.x * charge_speed` re-aims every frame with an instant hard set — no turn-rate limit — at 430 vs 240. The comment claims "a re-aim, not a homing missile"; on the code's own terms it is one horizontally. A 240 px/s player cannot out-juke it; only vertical escape or wall-bait (`is_on_wall()` ends it) works. Fix within the rules: turn-rate-limit the re-aim, or commit at entry with a tell. Keep the speed.
- **Claim Jumper's surge can defeat his own separation.** `SURGE_SPEED_MULT` is applied inside `_ground_chase` *before* the separation logic. Margin is `CHASE_SEPARATION` 200 − contact reach ~156 = ~44 px, but braking overshoot at `TURN_DECEL` 1400 is v²/2a ≈ **53 px at 385, ≈135 px at surge 616**. A surge firing inside 200 px carries him through the standoff into a contact wipe the player cannot answer. Suppress surge (or cap closing speed) when the gap is within separation + braking distance.
- The Distributor is the clean one: `HOVER_CLEARANCE` 55 + the pull's `PULL_FLOOR_MARGIN` 72 cap mean contact requires the player to jump into him. Keep that pattern.

The full-run wipe is the founder's stated rule, so within it the fairness bar is: **the boss's own locomotion may never deliver an unavoidable touch.** (a) and (b) currently violate that. If the founder can be moved at all: contact outside an attack state should be death-and-checkpoint, not a zeroed run — flag for design, don't change unilaterally.

## 5. Stage 3: "too easy" and "does not move" are the same bug

Yes — the player is killing a wall-pinned boss from safety. Player stands west of the arena; the boss clamps at 3840 holding `CHASE_SEPARATION` 200; every ~2 s cycle he enters VULNERABLE and drifts to `VULNERABLE_SEPARATION` 96 px — inside axe range — where `MAX_VULN_DAMAGE_PER_WINDOW` 3 caps each window, so 18 HP = six free windows of plinking. His only offense, dynamite, is telegraphed ≥1.3 s (`maxf(1.3, 2.0 - 0.35 * (current_phase - 1))`) and aimed at the player's standing spot — trivially walked at 240. He can never touch the player (clamp + separation). The founder watching him pinned reports "does not move"; the founder plinking him reports "too easy." Same configuration, two reports. The harness confirms the shape: with the player *inside*, he uses 396 of his 420 px band — the statue only appears when the player is outside. The per-window damage cap, added to fix "too easy," just lengthens the farm without adding risk. The section-3 lifecycle (suspend on exit, reset on death) closes both reports at once.

## Not provided (needed, not guessed)

- `level_01_smoke_realm.gd` / level 02 / 03 scripts — seal raise/drop and arena-bound assignment; required to place the lifecycle fix and to verify why the Auditor never left the arena mouth (terrain vs. state machine).
- Player controller — jump velocity and axe/projectile range, needed to fully verify the dodge margins in section 4.
- `boss_projectile.gd` (clipboard lifetime/range) and `GameManager.boss_contact_restart()` (described, not shown).
- Line numbers for the pasted files.