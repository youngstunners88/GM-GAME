<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/rage-kimi-chase.md
     files inlined: 2
     tokens: 24908 in / 14652 out
     cost: $0.2945
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Audit: why the bosses *look* like they don't chase

**Citations:** I'm citing by exact symbol/constant name rather than line number — I can't verify precise line numbers from pasted excerpts, and inventing them would be worse than useless. Every symbol below is unique and searchable.

**Missing files (flagged, not guessed):** `player.gd` was not provided — I'm using the 200 walk / 240 sprint figures quoted in the boss comments, and I **cannot see the dash**. If the player has a dash burst, it widens every gap below. `level_02`/`level_03` arena scripts were not provided, so terrain-trap reachability is conditional.

---

## DISTRIBUTOR — the chase is real but it *terminates*

### 1. The chase self-terminates 250px above the player. This is THE cause.
`_hover_pursue()` — `var target: Vector2 = p.global_position + Vector2(0.0, -HOVER_ABOVE)`, with `HOVER_ABOVE = BODY/2 + HOVER_CLEARANCE` = 120 + 130 = **250px overhead**.

Once he arrives (seconds, at 345–400 px/s), `to` ≈ 0, so `to.normalized() * speed` ≈ 0 and he brakes to a **zero-velocity hover**, buzzing ±~37px around the anchor (overshoot = 345²/2·1600). His resting state for the entire fight is *floating motionless over your head*. Every speed fix shipped so far made him **arrive faster and hover more reliably**. The tests measure horizontal distance closing — they pass. The founder watches a boss that has arrived and is now parked. Both are correct; only one is visible.

Corollary: with clearance 130 + `PULL_FLOOR_MARGIN` 72 + contact = instant restart, **he can never touch the player and the player can never be touched except by jumping into him**. Pursuit with no possible payoff reads as "not pursuit."

### 2. His most visible moments are vertical-only movement, away from the player.
The climb lock (`too_low and |dx| < BODY*0.6`) forces pure vertical motion whenever he's at player height — which is **spawn, after every pull, and after low vulnerable windows**. The first thing the founder sees every fight is the boss rising straight up, away. First impression: retreat, not chase.

### 3. Close-range lock damping is admitted in-file to be below sprint.
The `to.x *= 0.5` block carries its own confession (S10 T6 comment): against a close + hopping player, `imminent` (`|dx| < LOCK_ARM_OVERLAP`) re-arms the lock every frame and horizontal closing is **~104 px/s vs the 240 sprint**. The founder's play pattern (close, hopping) is exactly the case that still fails.

### 4. HOARD_GRAVITY inverts who appears to move.
Every 3rd action, for 1.4–2.2s, `_apply_pull()` displaces **the player** while the boss anchors overhead. On screen: boss stationary, player yanked through the air. The signature mechanic visually argues he doesn't move.

### 5. Dead speed scales (not a cause, but it explains why 10+ "fixes" changed nothing).
`maxf(HOVER_MAX * speed_scale, min_speed)` with `HOVER_MAX` 330 < `MIN_PURSUE_SPEED` 345 means **every pursuing state runs at exactly 345** — the 0.62/0.55/0.70 scales and all the "he closes slower during the tell" comments are no-ops. And 345 − 240 = only **105 px/s net** against a kiting player: real, but slow to perceive.

**Checklist verdicts:** non-chase states — no (all states pursue; the problem is *arrival*); standoff — **yes, permanent 250px overhead**; stale targeting — no (player sampled every frame); speed below player — no; trap — partial (climb lock at close range). Conditional: the y-clamp in `_clamp_to_arena` has **no half-body inset** — if the arena ceiling is low, his 250px-above target is unreachable and he pins against the clamp, velocity zeroed, fully stationary. Unverifiable without the level file.

**Highest-impact change:** collapse the vertical standoff — pursue the player's position, not a point 250px above it (e.g., `HOVER_CLEARANCE` 130 → ~24–40, retune `PULL_FLOOR_MARGIN` to match, keep the climb lock for spawn safety). Yes, contact = restart makes this lethal — that is precisely the "stakes" the founder keeps demanding, and it's the only change that converts "closing" (a metric) into "coming at me" (a visual). Everything else leaves the resting state as a hover.

---

## CLAIM JUMPER — he chases, then stops, every 2 seconds

### 1. Full-stop VULNERABLE at point-blank range, ~36% of every cycle.
`State.VULNERABLE` branch: within `VULNERABLE_SEPARATION` (96px) he brakes to **zero** for up to 0.7s, flashing red. Cycle is ~1.95s (0.85 patrol + 0.4 throw + 0.7 vuln), so he's at 120 or 0 for ~36% of the fight — and the freeze happens **exactly when the player is closest and watching**. The founder's test ("is he chasing me?") is answered at melee range, where the answer is visibly "he stopped."

### 2. Phase-1 cycle-average speed is below player sprint.
(0.85·290 + 0.4·280 + 0.7·120) / 1.95 ≈ **227 px/s < 240**. Per-state speeds all beat sprint, but a player who simply holds run in phase 1 outruns him on average on open ground. "I held run and he never caught me" is arithmetically true in phase 1.

### 3. Terrain traps park him permanently.
- `at_ledge` with `_gap_crossable` false → `velocity.x = 0.0` every frame, **holds the lip forever** while the player is across the pit. Permanent standoff.
- `want_hop := is_on_wall() or ...` fires on *any* wall contact; with the commit sized to a small `pdx`, he pogo's near-vertically against interior walls. `_hop_cooldown` 0.7 < `HOP_AIRTIME` 1.265 means no grounded chase frame between hops — sustained pogo instead of pursuit.
- Reachability depends on Stage 3's interior geometry — **level file not provided, unverified**.

**Checklist verdicts:** non-chase states — **yes (~36%)**; standoff — yes, brief but frequent (96px hold); stale targeting — no (movement re-targets every frame; dynamite aims at fire-time position by design, it's telegraphed); speed below player — per-state no, **cycle-average yes in phase 1**; traps — yes, conditional on arena geometry.

**Highest-impact change:** delete the `VULNERABLE_SEPARATION` full-stop branch and raise `VULNERABLE_DRIFT` 120 → ~250. The hold is **redundant**: `MAX_VULN_DAMAGE_PER_WINDOW` (3) already caps the burst-down it was added to prevent — the comment above the cap says so itself. This one edit removes the close-range freeze (cause 1) and lifts the phase-1 cycle average above sprint (cause 2): (0.85·290 + 0.4·280 + 0.7·250)/1.95 ≈ 273 > 240.

---

## The meta-finding

Ten fixes failed because the tests and the founder measure different things. The tests measure **horizontal gap over time**; the founder watches **what the boss does after it arrives, and when the player is close**. The Distributor's chase terminates in an invisible "arrived" state 250px overhead where it can never threaten anything; the Claim Jumper's chase is interrupted by a full stop precisely at the distance the player is looking at. Neither is a speed problem, which is why every speed floor raised so far passed the gates and changed nothing on the couch.