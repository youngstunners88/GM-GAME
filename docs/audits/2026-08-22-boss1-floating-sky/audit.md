# Audit — Stage 1 boss "floating in the sky" (2026-08-22)

**Founder report**: "The fucking 1st boss is still floating in the fucking sky!!!!"
**Evidence**: `artifacts/founder_shots_2026-08-22/shot_1.png` — the Auditor
suspended near the top of the screen, above all platforms, player far below.
**Severity**: P0, presentation blocker. Third consecutive round reporting a
boss stuck/float defect; two prior sessions claimed it fixed and were wrong.

---

## 1. Why the previous round's fix did not work

The previous round added a height ceiling to `auditor.gd`: don't leap again
once already >400px above the player. It lowered peak altitude, and the gates
written for it passed — but the founder's report did not change, because
**altitude logic was never the cause**. The boss was not choosing to fly. He
was stuck, and the pogo that follows being stuck is what reads as floating.

Fixing the symptom's altitude while leaving the trap in place is exactly why
this came back a third time.

## 2. Root cause — two independent blockers, both measured

Method: instantiate the real `level_01_smoke_realm.tscn`, trigger the real
boss via `_on_boss_trigger()`, disable his Hitbox monitoring so contact does
not reload the scene, park the player, and log every
`get_slide_collision()` collider (name, class, node path, layer, shape size)
each frame.

### Blocker 1 — the checkpoint's invisible `StandSurface`

`checkpoint.tscn` carries a solid 32×48 `StaticBody2D` named `StandSurface`
on collision layer 1. `level_01_data.tres` places checkpoints at
`Vector2(1100,500)` and `Vector2(2200,500)`.

Measured: the boss's **x froze at exactly 2200** and never moved again,
pogoing between y=90 and y=280. His collision shape is `pos=(110,110)
size=(220,220)`, so his origin is the body box's top-left and
**feet = origin.y + 220** → feet reached 310, above the level's highest
platform top (y=300). Genuinely in the sky, exactly as screenshotted.

This body was **invisible**: an earlier session (Block_Fixes_1, 2026-08-20)
hid the checkpoint's blue `ColorRect` by setting alpha to 0 but deliberately
kept `StandSurface` solid, commenting "The StandSurface stays solid so the
Auditor can still launch off it." The result was an invisible wall at every
checkpoint in every level.

### Blocker 2 — a breakable block

With blocker 1 addressed, the boss advanced only to **x=1882** and froze
against a 32×32 `breakable_block` at `(1850,500)` (layer 129 = World |
Destructible). `level_01_data.tres` lists blocks at x=850, 950, 1350, 1750
and 1850 — all directly on his ground-level chase lane.

In both cases a 32px prop permanently walls a 220px boss, latching
`is_on_wall()` true forever, which re-arms his wall-leap every cooldown.

## 3. Attempted fixes — BOTH REVERTED

> **Outcome: the sky-float cause is proven, but no fix shipped.** Every change
> below removed the pin and then stranded the boss somewhere worse, so the
> branch was reverted to baseline rather than ship a regression. What follows
> is recorded so the next attempt does not repeat it.

### 3.0 Why they were reverted

`auditor_full_stage_hunt_test` (fleeing player, full level route) passes
reliably on baseline — measured twice, gap=7 and gap=6. Each fix broke it:

| Change | Sky-float pin | Full-stage hunt |
|---|---|---|
| baseline | frozen 46.8s | **PASS** (gap=7) |
| StandSurface removed | fixed | FAIL — strands at x=1882 (2572 frames) |
| StandSurface one-way | fixed | FAIL — strands at x=1882 |
| + boss smashes blocks | fixed | FAIL — strands at x=1200 (1849 frames) |
| + smash only as last resort | fixed | FAIL — strands at x=1376 |
| + LEAP_VELOCITY 620→660 | fixed | FAIL — strands at x=1882 |

**The finding that matters:** the checkpoint's solid `StandSurface` and the
breakable blocks are the Auditor's **staircase**. His own leap clears 196px,
and mounting the platform at (1100,450) from ground at y=650 needs **200px** —
he is four pixels short, so he physically cannot traverse level_01 under his
own power and has been relying on level furniture the whole time. Remove any
of it and he strands. Raising the leap to 222px did not rescue it either,
because he then hits the pocket at x=1200: walled west by (1100,450) at torso
height and capped above by (1400,350), which his right shoulder clips.

A real fix is a general anti-stuck behaviour (detect no-progress, then vault or
reroute), not another prop tweak. That is a larger change than this residual,
and shipping a half-version of it is what caused this regression.

## 3bis. What the reverted changes were

### 3.1 Checkpoint → `StandSurface` removed

The founder had explicitly demanded on 2026-08-20 (shot_1) that this block be
solid:

> "The 1st boss need to be able to jump on the block that i have circled so
> that he can launch himself onto the platform. Why did you make the block
> something that he can just walk through!!!!"

So the first attempt was to honour that by making the shape
`one_way_collision = true` — landable from above, not a horizontal wall. Gates
went green. **That was wrong, and Grok 4.6's audit caught it before it
shipped.**

The reason it was wrong: Block_Fixes_1 — also the founder's instruction — had
already required this block to stop being a *visible* object, so its ColorRect
alpha is 0. One-way collision therefore preserves a body that can be **rested
on** while being invisible, 150px above the ground. A boss standing on an
invisible box renders as a boss standing on thin air — which is the exact
complaint being fixed. The previous revision of
`checkpoint_solid_platform_test` actively *asserted* that a boss-mask body
comes to rest on it, i.e. the project had a passing gate guaranteeing a way to
reproduce the bug.

The 2026-08-20 request is therefore superseded, and deliberately so: a launch
pad nobody can see is not a launch pad. `StandSurface` is gone and the
checkpoint is a pure `Area2D` save trigger. Save, audio and snapshot feedback
are untouched.

### 3.2 The Auditor demolishes breakable blocks

`auditor.gd` gained `_smash_blocking_breakables()`, called from PATROL when
`is_on_wall()`. It calls the existing `break_block(false)` — the block is
destroyed with its normal effect, and **no score is awarded**, since the
player did not earn it.

He smashes rather than ignores deliberately. Making blocks non-colliding for
him would have read as the boss phasing through solid geometry, which the
founder has explicitly rejected ("make it so that the boss does not walk
through this block"). Demolishing is legible, in character for a Tax
Collector, and permanently clears the lane.

**Secret walls are excluded.** `secret_wall.gd` joins the same `"breakable"`
group and exposes the same `break_block()` contract, so a plain group check
would have had the boss casually demolishing the level's hidden routes on his
way past. The filter matches the concrete `breakable_block.gd` script path.

### 3.3 `breakable_block.gd` hardening

`break_block(award_score := true)`, guarded by a `_breaking` flag so repeated
contact frames cannot stack tweens, and collision is disabled on the **first**
frame of the break instead of when the 0.25s tween finishes — otherwise the
boss stayed walled for a quarter second after the block was already dying and
re-triggered his own leap.

## 4. What the reverted attempt did achieve (parked-player case only)

These are the numbers the reverted changes produced on the sky-float gate. They
are real, and they show the diagnosis was right — but they are NOT shipped,
because the same changes broke the full-stage hunt (see 3.0).

| Metric | Baseline (shipped) | Reverted attempt |
|---|---:|---:|
| Max frozen-in-place streak | **46.82s** of 60s | **1.32s** |
| Frames with feet above every platform | 101 / 3600 | **0 / 3600** |
| Highest feet reached | 256 (above all platforms) | 493 |
| Distance travelled toward player | 1373px | 1520px |

Gate: `tests/auditor_no_sky_float_test.gd` (new, permanent).

`tests/checkpoint_solid_platform_test.gd` was **rewritten to assert the
opposite contract** and now locks the checkpoint down from both directions:
nothing may perch on it, and it may not wall horizontal travel. Overturning a
gate is not something to do quietly, so the reasoning above is recorded in the
test's own header. `tests/visual_trap_damage_test.gd` carried the same stale
"StandSurface still present" assertion and was updated with it.

## 4b. Multi-model review

| Model | Verdict |
|---|---|
| Grok 4.6 (truth audit) | **Changed the outcome.** Rejected "one-way collision" as a fudge that keeps an invisible perch, and rejected writing FIXED on headless evidence. Both accepted — see 3.1 and §5. |
| Kimi K3 (geometry) | First dispatch exhausted its output budget on reasoning and returned nothing; re-dispatched with a narrowed prompt. Second run **independently confirmed the diagnosis** — see below. |

Kimi K3's second run, given only the raw rectangles and jump numbers (no
source, no conclusions), reproduced the result from first principles:

- `feet = origin.y + 220` confirmed correct for the given collision shape.
- Jump arithmetic: rise₁ = 620²/(2·980) ≈ 196px, rise₂ = 560²/(2·980) ≈ 160px,
  total ≈ 356px, against only 150px needed to clear a block whose top is at
  y=500 from ground at y=650. Its verdict: *"he clears it easily, even on
  jump₁ alone. **Something other than rise is failing.**"* That is the
  independent confirmation that two rounds of jump-height tuning were aimed at
  the wrong variable.
- Asked to enumerate every x where a 220×220 body walking at ground level is
  stopped by a solid it cannot step onto, it produced exactly the blockers
  measured in-engine — including **x=1882 for the block at (1850,500)**, the
  precise value the probe logged.
- It also ruled out a whole class I had not tested: none of the ground gaps
  (all 100px) can trap a 220px-wide body, since it always overlaps a floor
  edge.

Its blocker list is fully covered by the two fixes: all five breakable blocks
are now smashed, both checkpoints are non-solid, and the only remaining entry
is the legitimate platform at (300,500).

**Grok dissent NOT accepted — recorded deliberately.** Grok argued the
boss-smashes-breakables change is scope creep and should be reverted, doing it
"in the level (move, layer, or one-way that tile)" instead. Rejected because
breakable blocks are *visible*, so making them non-colliding for the boss
produces literal clipping through solid art — which the founder has explicitly
rejected — and because the block is destructible by design, not structural
cover. The smash only fires when he is genuinely blocked (`is_on_wall()`), so
he destroys only what physically stops him, and secret walls are excluded.
Flagged here so the disagreement is visible rather than buried.

## 5. Honest remaining gap

After 60s the boss is still **~480px short** of the parked player. He is not
stuck (max stall 1.32s) and he is not in the sky (0 frames), but he ends up
shoving a patrolling enemy `CharacterBody2D` ahead of him down the corridor
at roughly a quarter of his walk speed.

Boss-vs-enemy collision was **not** changed — that is a different defect from
the reported residual, and this round deliberately avoided scope creep. It is
logged here and in STATUS.md rather than being quietly passed off: the new
gate asserts *progress* (>1000px travelled), and the "closes to within 400px"
claim remains owned by `auditor_full_stage_hunt_test`, which drives a moving
player over the whole route.

Per Grok's audit and the founder's own hard rule ("No FIXED while Auditor is
airborne on hard-refresh"), this residual is reported as **root-caused and
measured, but NOT FIXED — no behaviour change shipped.** The remaining
enemy-shove slowdown is the most likely thing to still read as "stuck" to a
viewer who is hunting for stuck, and is called out to the founder directly
rather than left to be discovered.

## 6. Lesson recorded

An invisible solid body is the worst possible failure mode: the founder can
see the *consequence* (a boss in the sky) but never the *cause*, and three
rounds of screenshots pointed at the symptom. The general rule this earns:
**when a report says an entity is behaving impossibly, log the actual
colliders before theorising about the entity's own logic.** Two rounds were
spent tuning jump arithmetic for a boss who was simply pressed against a post.

Second lesson, and the expensive one this round: **check the OTHER gate before
believing your fix.** Five successive variants each made the reported symptom
go away and each silently broke `auditor_full_stage_hunt_test`. The sky-float
gate and the hunt gate disagree because they model different player behaviour
(parked vs fleeing), and the boss's traversal is only viable in one of them.
Any future attempt must run BOTH before claiming anything.

Third lesson: **a green gate can be the bug.**
`checkpoint_solid_platform_test` passed for two rounds while asserting that a
boss-mask body comes to rest on an invisible box 150px above the ground. It
was not a missing test — it was a test actively defending the defect, written
from a founder request whose premise a later founder request had already
removed. When a report keeps recurring, re-read what the passing gates
actually guarantee.
