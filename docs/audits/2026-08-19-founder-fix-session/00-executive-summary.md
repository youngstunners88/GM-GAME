# Founder Fix / Forensic Repair Pass — 2026-08-19

Directive: `LIL_BLUNT_FORENSIC_REPAIR_PASS_20260819.md` + founder fix sheet
`Fixes_Needed.md` (11 screenshots preserved at
`artifacts/founder_shots_2026-08-19_fixes-needed/`).

## Method

Instrumentation FIRST, per the directive's §17/§19 ("automated tests are not
enough", "the burden of proof is on the implementation").

New reusable harness:
- `tools/boss_ai_diagnostic.gd` — records the whole pursuit pipeline per sample
  and derives the FAILURE MODE, not just a distance: frozen-fraction,
  clamped-against-the-arena-wall fraction, x-span vs reachable range, and a
  **tracking score** correlating boss movement direction with player movement
  direction (+1 follows, 0 uncorrelated, −1 flees).
- `tests/boss_chase_live_test.gd` — drives a REAL kiting player (240 px/s wall
  to wall) through all three real levels' real `_on_boss_trigger` path, in three
  vertical scenarios (ground / high platform / very high platform).

Why this matters: every earlier chase gate in this repo pinned the player at a
fixed x and asked "did the boss close the gap". A boss that only works against a
stationary target passes that and still reads as motionless in play.

## Measured baseline (before fixes)

| Boss | tracking | x_span | frozen | verdict |
|---|---|---|---|---|
| Stage 1 Auditor | **−0.20** | 250 px | 33% | BROKEN — moved *away* from the player |
| Stage 2 Distributor | +0.56 | 460/460 | 28% | tracks when player is inside the arena |
| Stage 3 Claim Jumper | +0.39 | 396/420 | 17% | tracks when player is inside the arena |

## Root causes confirmed

### 1. SHARED — the fight stays live while the player is OUTSIDE the arena (P0)

Photogrammetry on the founder's own screenshots (done by an independent
analysis agent, then checked against the level data):
- Stage 2 shot: player at world x≈3109 — **591 px WEST of `boss_arena.start_x`
  (3700)** — with the Distributor measured at x≈3813, i.e. welded to his west
  clamp (his reachable centre range is only `[3820, 4280]`).
- Stage 1 shot: player retreated ~900 px west; boss never left the arena mouth.

Every boss is clamped strictly inside its arena, but the seal wall DROPS when
the player walks back west (it has to — checkpoints sit west of every arena, so
a player who dies mid-fight would otherwise be locked out). Nothing ended the
fight, so the boss kept pursuing a target it was structurally forbidden from
reaching and sat frozen on a clamp. **No amount of speed/accel/standoff tuning
can fix a boss whose target is outside his permitted world** — which is exactly
why ~10 previous tuning attempts (all recorded in code comments) failed.

It also explains the companion complaint that Stage 3 is "way too easy": a
wall-pinned boss is a stationary target that can be shot from safety.

**Fix:** `LevelBase._end_boss_fight()` — leaving the arena now ENDS the fight
(boss freed, `_boss_arena_active` cleared) so walking back in starts a clean
one. Deliberately not "just re-seal the player in", which would reintroduce the
respawn soft-lock the drop behaviour exists to prevent.

Independent confirmation: GPT-5.3-Codex reached the same "encounter boundary
ownership" conclusion unprompted.

### 2. Stage 1 Auditor — three separate defects (P0)

- **Stale charge target.** `charge_target` was captured ONCE on entry to CHARGE
  and never refreshed; a 1.4 s charge against a 240 px/s player lands up to
  ~336 px behind, and against a reversing player it charges *away*. Confirmed
  independently by Codex, Qwen3 and Grok 4.6.
- **`VULNERABLE` hard-freeze.** `move_toward(velocity.x, 0.0, 200.0)` — **no
  `* delta`**, i.e. 12 000 px/s²: a dead stop within two frames, then perfectly
  still for the whole window. Instrumentation caught him parked at exactly
  x=3030.0 and x=3280.0 with vx=0.000 — the literal "cant get passed this point".
- **Aim bias + reversing hop** (found by Grok 4.6): CHARGE aimed from
  `global_position` (the body's TOP-LEFT, ~110 px off) through a 2D-normalised
  vector, and the periodic "reposition" hop blended toward
  `-patrol_direction * 150.0` — deliberately *away* from the player every 6 s.

### 3. Stage 3 — my own previous commit's standoff was making it worse (P0)

The preceding commit added `CHASE_SEPARATION = 200` with an ACTIVE RETREAT.
Measured cost: `s6_boss_projectile_chase_test` showed **217 px of boss travel
against ~360 px of player travel** — he was losing ground, because every time he
clipped the band he reversed to full speed and then re-accelerated from a stop.
Grok 4.6, Qwen3 and the directive itself ("DO NOT 'fix' boss chase by ONLY
ADDING STANDOFF ... it is NOT a substitute for correct pursuit") all objected.

Replaced with **velocity matching**: inside the band he holds the player's own
velocity (gap constant, no ground lost), with a gentle outward bias only when
well inside. Travel 217 → 298 px.

### 4. Stage 3 contact box was the whole body (P0, root of the "too easy"/"can't
   approach" contradiction)

The Claim Jumper was the only boss whose contact `Area2D` **shared the 280×280
physics shape** (auditor/distributor both use trimmed hurtboxes). Kill radius
~156 px — *wider than the 96 px his own VULNERABLE window closes to*. The one
moment the fight invites the player in was also the moment standing there wiped
the run. Now a 0.62×0.78 contact core (kill radius ~103 px, measured live by the
gate rather than hardcoded).

### 5. Spawn grace silently CANCELLED contact rather than delaying it

`body_entered` fires once. Returning during grace meant a player still inside
the boss when grace expired was permanently immune. All three bosses now
re-check the real overlap when grace expires.

## Result (after fixes)

All 9 boss-chase scenarios pass:

| Boss | tracking (was → now) | x_span (was → now) | frozen (was → now) |
|---|---|---|---|
| Stage 1 Auditor | **−0.20 → +0.54/+0.59** | 250 → 370 px | 33% → 17–22% |
| Stage 2 Distributor | +0.56 → +0.57/+0.79 | 460/460 | 28–42% |
| Stage 3 Claim Jumper | +0.39 → +0.39/+0.50 | 396–399/420 | 15–17% |

Suite: 46 pass. 2 pre-existing failures remain and were verified as failing at
HEAD before any of this work (`icp_contract_test` — ICP endpoint offline in this
container; `s11_vault_music_test` — vault theme drift). Security sentinel 18/18,
0 blockers.

## Other founder items fixed this pass

- **FIX-04 boss 2 too loud** — per-boss `BOSS_GAIN_DB` trim (Distributor −4 dB).
  Previous pass had moved the single SHARED gain 12→9 for all three bosses,
  which cannot satisfy a per-source complaint.
- **FIX-06 Gideon too quiet** — root cause: `_play_vo()` never set `volume_db`,
  so vault NPCs played at 0 dB while barks run +6 and boss VO +9. Now +9.
- **FIX-05 crystals faster** — 260/310/360 → 380/450/520 px/s. Safe because
  crystal shards are `redirectable = false`; the Forced-Distribution redirect
  window belongs to the ETH-orb volley, whose speed is untouched.
- **FIX-07 Assay text masking** — the real conflict was VERTICAL, against the
  2888-day pool plate (sign band y 300–405 vs plate band y 400–443), so the
  previous sideways move could never have fixed it. Raised to y 170–275.
  The gate now asserts band non-overlap instead of a magic coordinate.
- **FIX-08 vertical shading rect** — removed the 380×680 panel + trim; the
  circular halo is kept and strengthened (r 140→175, alpha 0.16→0.34).
- **FIX-10 axe impact** — root cause: the founder was comparing the PICKAXE
  (his HUD reads PICKAXE in image7) against the big axe ("hammer", image8).
  `_spawn_axe` only ever set `big` from the "bigaxe" power-up, so a pickaxe
  throw was byte-identical to the DEFAULT axe. Added a real middle tier
  (4 dmg / 1.5× / heavy SFX / medium shake), with pierce + hitstop still
  exclusive to the big axe.

## NOT done in this pass (honest)

- FIX-01 viewport / screen space — needs itch.io embed settings work; largely
  not repo-controllable (see below).
- FIX-11 Stage 3 mountain seam, FIX-13 Fort Knox "badly glued" background —
  require source-art analysis.
- FIX-12 Blaze Rush rectangle residue — identified the likely cause (the layer
  −2 full-rect `COLOR_VOID` ColorRect showing through below the forest art) but
  did not implement.

These are unstarted, not verified-and-deferred. The multi-agent workflow that
was to cover them died when the org's monthly Claude spend limit was reached
(13 of 15 agents failed); the OpenRouter consultations continued because they
bill separately.

## Model consultations (real dispatches, OpenRouter)

| Model | Role | Output |
|---|---|---|
| x-ai/grok-4.6 | adversarial chaos tester | `docs/model-responses/2026-08-19-forensic/grok46-boss-rootcause.md` |
| openai/gpt-5.3-codex | independent technical adversary | `codex-boss-rootcause.md` |
| qwen/qwen3-235b-a22b-thinking | architecture / root cause | `qwen3-boss-rootcause.md` |
| deepseek/deepseek-v4-pro | code forensics | `deepseek-boss-rootcause.md` |
| moonshotai/kimi-k3 | gameplay systems audit | dispatched |
| anthropic/claude-fable-5 | visual/UX audit | dispatched |

Consensus: all four returned models independently agreed the arena-clamp
hypothesis explains Stage 2/3 but NOT Stage 1, and independently identified the
stale `charge_target` and the missing `* delta`. Grok 4.6 additionally found the
origin-vs-centre aim bias and the reversing reposition hop, both of which were
fixed. Qwen3's proposal to let bosses chase outside the arena was REJECTED — the
Claim Jumper's ledge/clamp system exists precisely because he used to fall out
of the world.
