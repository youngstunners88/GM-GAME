# Stuck-Boss / Runaway-Climb Residuals Audit — 2026-08-22

Founder screenshots: inline Level 1 screenshot (translucent block circled, no file
attachment) and `artifacts/founder_shots_2026-08-22_claim-jumper/image1.png`
(Level 3, blue annotated erratic path near Hall of Blaze / minecart / TNT).

## Issue 1 — Level 1: "the boss just automatically kills Lil Blunt from walking
through the block... the boss seems to linger in the air at times"

**Founder, verbatim:** "I told you to make it so that the boss does not walk
through this block!!! The game is unplayable now because The boss just
automatically kills Lil Blunt from walking through the block. Also the boss
seems to linger in the air at times."

**Root cause (measured, not guessed):** A real-physics probe (the real
`level_01_smoke_realm.tscn`, real `_on_boss_trigger`, no player interference —
the worst case) found the Auditor's leap+air-jump combo re-arms on **every**
wall/ledge contact with **no ceiling** on cumulative height gain. Landing near
one ledge just handed him a fresh `is_on_wall()+is_on_floor()` trigger to leap
again from that new height. Across the platform-dense stretch of Level 1 this
chained into a runaway climb — measured **min_y = -170.0**, with the highest
real platform in the level at y=300, and **347 of 3600 frames (9.6% of a 60s
patrol) spent above the visible screen top** before gravity eventually
returned him. That reads exactly as "lingers in the air", and an unpredictable
landing spot when he finally descends is what put his hitbox on the player
without warning — `GameManager.boss_contact_restart()` (pre-existing, not
changed this round) makes ANY boss contact a full run-reset, so an
unpredictable landing is catastrophic, not merely annoying.

Ruled out via A/B test: temporarily disabled the checkpoint's `StandSurface`
collision and re-ran the identical probe — the bug persisted at a different
location, proving the checkpoint prop was not the cause.

**Fix:** Added a height-sanity ceiling, `already_high_enough` (true once the
boss is more than 400px above the player's y), gating all three trigger
points that can chain a climb: the wall-leap, the "player above" hop, and the
air-jump fire condition itself. Gating only the wall-leap was tried first and
measured **insufficient** (`min_y` unchanged at -169.6) — a leap armed the
frame before crossing the threshold could still legally fire its own already-
armed air-jump moments later, adding another ~160px on top. All three sites
needed the gate.

**Frame proof:** headless — `tests/auditor_no_runaway_climb_test.gd` (new
permanent gate, converted from the ad-hoc probe used to find and verify this).
60s unattended patrol in the real level: **min_y = -58.4** (down from -170.0,
a bounded single overshoot rather than a repeating unbounded chain),
**100/3600 frames above the screen top** (down from 347, a 71% reduction).
Existing regression tests unaffected — `auditor_full_stage_hunt_test.gd`
(gap=34px, max stuck streak 213 frames), `auditor_platform_intelligence_test.gd`
(x-span 285px, 2 ceiling hits), `auditor_real_arena_climb_test.gd` (579/900
frames resting on real platform surfaces) all still pass with no regression.

## Issue 2 — Level 3: Claim Jumper stuck near minecart/TNT/Hall of Blaze,
double jump not resolving it

**Founder's file, verbatim (`PROMPT_CLAIM_JUMPER_STUCK_DOUBLE_JUMP.md`):** "The
final boss (Claim Jumper / Stage 3) is stuck. He cannot move beyond the
current platform/ledge point. He also needs double jump so vertical gaps and
higher ledges do not strand him." Locked requirements: never permanently
stuck; double jump must fire in real chase paths; keep the Stage 2-style
standoff behavior (no re-introducing "ride on top of the player" lock-on); no
speed-only fix; proof required in the real Stage 3 arena, not an empty test
box.

**Root cause:** The same bug class as Issue 1, specific to this boss's own
arena mechanics. `_clamp_to_arena()` clamps the boss's X at the arena wall but
deliberately does **not** clamp the Y ceiling (its own comment: "pinning his
maximum height would cancel the hop mid-air"). A hop taken right at the
clamped wall re-armed every `_hop_cooldown` (0.7s) with X pinned by the
clamp, climbing in place instead of ever getting a grounded chase frame —
reading as "stuck" even though he was technically airborne and "jumping".
Kimi K3's review (dispatched this round) additionally identified a structural
amplifier: `ARENA_EDGE_MARGIN` (24px) is smaller than the boss's own
`HALF_BODY` (140px), so his clamped centre sits with his collision box ~116px
past the wall line — meaning `is_on_wall()` is **structurally always true**
at either arena wall, which is exactly why this bug was so persistent there.

**Fix:** Same `already_high_enough` height ceiling (>400px above the player),
applied to both the outer hop-arm condition and the air-hop fire condition —
gating only the former was proven insufficient for the Auditor's identical
bug, so both were gated here from the start. Hardened per Kimi K3's review:
the gate originally read `pl.global_position.y` directly and failed **open**
(gate disabled, unbounded climb returns) on any frame the player node is
momentarily null (death/respawn, scene transition). Added `_last_player_y`
(mirroring the existing `_last_player_x` pattern already in this file) so the
gate falls back to the last known player height instead of disabling itself.

**Multi-model dispatch (Kimi K3, DeepSeek v4 Pro, Grok 4.6 — per the
founder's own directive table):**
- **Kimi K3** confirmed the ceiling genuinely fixes the *unbounded* half of
  the bug, flagged the `pl == null` fail-open gap (fixed, see above), flagged
  the `ARENA_EDGE_MARGIN < HALF_BODY` structural amplifier (documented, not
  changed — re-tuning arena movement extents is out of this residual's
  surgical scope), and flagged that the gate is direction-agnostic and would
  also block a legitimate downward gap-crossing hop if the level ever grows
  a >400px vertical drop inside the boss arena (currently **inert**: the real
  Stage 3 arena is one flat 700px ground segment with no elevation change).
- **DeepSeek v4 Pro** raised the same "gate blocks legitimate gap-crossing"
  risk independently, and raised a claim that `if throw_timer <= 0:
  _throw_dynamite()` was nested inside the gated block (which would have
  broken his attack while gated) — **checked against the real file and
  refuted**: that line sits at the same 3-tab indentation as the gate's own
  `var already_high_enough` declaration, a sibling statement, not nested
  inside it. Dynamite throwing is unaffected by the gate.
- **Grok 4.6**, tasked with a truth-audit against the founder's own
  definition-of-done checklist, correctly rejected the first test scenario
  (player parked *beyond* the arena wall, unreachable by design) as proof of
  "leaves the stuck point and continues pursuit" — it only proved the climb
  is *bounded* while permanently pinned, not that pursuit resumes. This
  directly produced Issue 2's second gate below.

**Frame proof (headless, real `level_03_gold_rush.tscn` arena, not an empty
test box):**
- `tests/claim_jumper_no_runaway_climb_test.gd` (new gate) — player pinned
  beyond the arena's east wall for 16s (the exact geometry that used to
  produce endless in-place climbing): **min_y = 29.3** from a spawn y of 500
  (bounded, not unbounded), **8 air-hop events** fired while pinned, 0 frames
  spent past the height ceiling + tolerance.
- `tests/claim_jumper_escapes_and_pursues_test.gd` (new gate, written in
  direct response to Grok's audit) — flees the player, over real time, to
  BOTH reachable arena extremes (east toward the old wall-pogo point, west
  toward the entry seal) and confirms the boss actually **reaches the
  player** (`min_gap_seen = 0` in both directions — he physically closes to
  zero distance, not just "moves in that general direction"), starts closing
  within 5s (`gap_at_5s` 100px and 18px respectively, both well under the
  400px "not abandoned early" bar), and ends within/near the intended
  `CHASE_SEPARATION` standoff (final gap 260px east, 20px west).
- Existing regression tests unaffected — `claim_jumper_double_jump_test.gd`
  (11 real air-hop events, 400px arena span covered),
  `claim_jumper_chase_separation_test.gd` (holds standoff, no lock-on
  regression, still approaches), `claim_jumper_difficulty_test.gd`, and
  `claim_jumper_pressure_test.gd` (fight remains completable, 23.3s
  time-to-kill under perfect fire) all still pass.

**Live verification:** fresh non-threaded web export built locally with both
fixes, served, and driven with Playwright via the existing `?boss=1` and
`?boss=3` debug warps — `artifacts/founder_shots_2026-08-22_claim-jumper/
live_boss1_auditor_after_fix.png` and `live_boss3_claim_jumper_after_fix.png`.
Both bosses boot, render correctly, and are visibly grounded/present in their
arenas (not off-screen, not frozen mid-air). This confirms the build boots
correctly with both fixes; it is a static confirmation of a healthy boot, not
a substitute for the headless coordinate-trace evidence above or for the
founder's own hard-refresh confirmation on the shipped build.

## What still matches the founder's complaints vs what does not

- Both root causes (Auditor Level 1 runaway climb, Claim Jumper Level 3
  wall-pogo/stuck) are fixed at the same underlying defect class — an
  unbounded height-chaining loop with no ceiling — verified with real-physics
  headless gates and before/after numbers, and reviewed by three independent
  models per the founder's own dispatch table.
- Per Grok 4.6's own truth-audit standard, applied honestly here: this audit
  does **not** claim "founder hard-refresh confirms" — that checkbox is
  definitionally not satisfiable by Claude alone and stays open until the
  founder verifies on the shipped itch.io build.
- Known, documented, currently-inert limitation (Kimi K3 + DeepSeek,
  independently): the height gate would also block a legitimate downward
  gap-crossing hop if the Stage 3 arena ever grows a >400px vertical drop.
  The real arena today is flat, so this is not exploitable in the current
  level, and is called out here rather than silently left for someone to
  discover later.
- Re-tuning `ARENA_EDGE_MARGIN` vs `HALF_BODY` (Kimi K3's structural
  amplifier finding) was deliberately left alone — surgical, scoped fix per
  the founder's own "no scope creep" rule; noted here as a real observation
  for a future pass if arena movement extents are revisited.
