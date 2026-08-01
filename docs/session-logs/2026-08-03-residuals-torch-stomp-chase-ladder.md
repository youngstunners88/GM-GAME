# Residual verification: torch, stomp, Tax Collector chase, Level 3 ladder — 2026-08-03

Session type: residual verification, not new feature work. Per
`PROMPT_RESIDUALS_TORCH_STOMP_LIVE_AUDIO8.md` — last session (2026-08-02)
fixed camera limits, Blaze Rush lifecycle+ESC, the Level 1 ladder, redesigned
the Tax Collector/Auditor boss, and added stomp — but four things were still
open: torch-in-hand wasn't re-screenshotted, stomp and boss chase were
gate-green but never seen in a live fight, and the Level 3 ladder was still
flagged ambiguous. This session closes all four, plus an optional Audio8
spike that turned out to be blocked (see bottom).

## 1. Torch-in-hand — FIXED, with evidence (idle AND walking)

**Prior status**: code read as correct; never re-screenshotted.

Dispatched Kimi K3 for a findings-first audit of the attach hierarchy
(`lil_blunt_visual.gd`). It surfaced two real, previously-unknown bugs that
static reading in prior sessions had missed:

- **MEDIUM — walk-bob decoupling.** `_tool` (the held-item sprite) is a
  *sibling* of `_spr` (the body sprite), not a child. `_process()` bobs and
  leans `_spr` every walk frame but never touched `_tool`, so the torch
  visibly drifted relative to the hand *only while walking* — the exact
  kind of bug a single idle screenshot can't catch, and a plausible
  explanation for why the founder's complaint kept resurfacing after
  "fixes" that only ever got checked at idle.
- **MEDIUM — legs render 8px into the ground.** `feet_y` is the body
  sprite's *center*, but the leg-position formula treated it as the
  sprite's *top*, placing legs 8px below the established floor line on
  every frame (walking and idle). Provable by algebra, independent of any
  screenshot.
- **LOW — facing-flip rotation asymmetry.** `_tool.rotation` was set once
  at equip time and never re-mirrored on a facing flip (unlike `flip_h` and
  `position.x`, which were correctly re-computed).

Also independently re-verified the one thing Kimi flagged as unverifiable
from code alone: `sprite_item_torch.png`'s actual dimensions. Canvas is
10×36px with a fully opaque bounding box (no transparent padding) — matches
the code's long-standing comment, so the static grip math itself was never
the bug.

**Fixes applied** to `src/player/lil_blunt_visual.gd`:
1. Leg-position formula corrected at all 3 call sites
   (`feet_y + tex_height/2 - 8` instead of `feet_y + tex_height - 8`).
2. Added a cached `_tool_base_y`; `_process()`'s walk branch now applies
   the same bob/lean delta to `_tool` that `_spr` receives, and the idle
   branch resets it — the tool no longer drifts during the walk cycle.
3. `_tool.rotation` now mirrors on facing flip, matching `flip_h`.

**Evidence**: real browser build, real torch pickup (Area2D overlap, not a
faked grant), HUD showing "TORCH 96%/93%" active. Screenshots captured both
**idle** and **mid-walk** (previously only idle ever existed) — in both, the
torch is clearly held at hand/waist height with the flame rising above the
character, not dragging at the feet. The walking shot is the one that
matters: it's exactly the pose the walk-bob bug would have broken.

**Skill updated**: `.claude/skills/tool-hold-anchor/SKILL.md` gained a new
**Check 5 — Animation coupling**, documenting this bug class (idle-correct
static math is not proof against per-frame animation decoupling) so a
future audit doesn't have to rediscover it. Check 3 already required a
screenshot; Check 5 now also requires that screenshot include a moving
frame, not just idle.

## 2. Live stomp evidence — FIXED (code) + captured (visual)

**Prior status**: gate-green, never seen in a live fight.

Dispatched Kimi K3 to audit `_try_stomp()` edge cases (boss exclusion,
one-way platforms, ladder-climb interaction, ground-pound double-damage).
Findings, verified against the real files:

- **Non-issue**: every boss scene (`auditor.gd`, `claim_jumper.gd`,
  `bandit_boss.gd`, `distributor.gd`, `boss_base.gd`) already calls
  `add_to_group("boss")`. Kimi flagged this as unverified only because it
  didn't have those files; checked directly, all clear.
- **PASS**: one-way-platform pass-through can't fire a false stomp — the
  falling-velocity gate is false for the entire rise, and the position gate
  is origin-to-origin so a below-platform player never satisfies it.
- **PASS**: ground-pound and stomp can't double-damage the same enemy — the
  pound's own `is_on_floor()` check can't re-fire on the frame the stomp
  already cleared `_ground_pounding`.
- **CONFIRMED MEDIUM — stomp could false-trigger mid-climb.** Entering climb
  state zeroes `velocity` but not `_last_fall_speed`; a fall before
  grabbing the ladder left a stale high fall-speed for the whole climb, and
  climbing down itself exceeds the stomp threshold. Fixed: `_try_stomp()`
  now returns false immediately if `_climbing`, and climb entry resets
  `_last_fall_speed = 0.0`.
- **CONFIRMED MEDIUM — ground-pound AoE had no boss exclusion**, unlike the
  stomp path it sits next to — the exact VULNERABLE-window bypass the stomp
  guard exists to prevent. Fixed: added `and not enemy.is_in_group("boss")`
  to the AoE condition.
- **LOW — doc-only.** A comment in `level_03_gold_rush.gd` said "70px above
  its surface" where the real number is 90px. Fixed the comment; the
  applied offset was never affected.

**Evidence**: a temporary debug warp (reverted before commit) dropped the
player from just above a freshly-spawned Tax Collector with fall velocity
pre-set past the stomp threshold. Result: **score +40, lives unchanged**,
player captured mid-air in a bounce pose immediately after contact —
consistent with a clean stomp kill and no damage taken. Two earlier attempts
(a large blind drop, then a smaller one onto the level's *pre-placed*
enemy) both failed to land clean evidence — not because the stomp is
broken, but because this sandbox's headless/SwiftShader canvas runs
`requestAnimationFrame` far faster than real time when unthrottled (the
torch power-up timer, ~15s nominal, fully drained inside a single capture
window), giving the enemy's patrol AI effectively unlimited time to wander
off before any screenshot landed, and once turning a mistimed drop into an
actual player death. Spawning a fresh enemy in the same call as the warp —
zero elapsed time for it to move before contact — removed the dependency
on this sandbox's timing entirely.

Grok 4.5 feel check on the captured evidence: stomp read (bounce + score,
no damage) is correct; recommended confirming the death VFX isn't hidden
under the bounce timing in a future normal-speed playthrough — not treated
as a defect, just a follow-up glance.

## 3. Tax Collector / Auditor boss chase — captured live

**Prior status**: gate-green, never seen in a live fight.

Walked the player into the Level 1 `BossTrigger`; "THE AUDITOR" arena
loaded with a full health bar (screenshot). Then walked the player away —
the Auditor pursued and caught up: the player **lost a life (3→2)** from
boss contact while actively fleeing, confirming it closes distance and can
land a hit, not just stand and wait at its spawn.

Grok 4.5 feel check: losing a life within a couple of seconds of turning
away reads as too fast a punish window for a *first* encounter — "gotcha
close" rather than readable pressure. Suggested one number: ~0.6–0.8s of
telegraph/ramp-in before the chase reaches full speed, keeping top speed
the same. **Not applied this session** — this is a tuning suggestion, not a
defect, and the founder's instruction was "tune ONLY if evidence demands
it." Flagging for the founder's call on whether to schedule a follow-up.

## 4. Level 3 ladder — FIXED, independently verified

**Prior status**: flagged ambiguous.

Applied `ladder.top_exit_offset = Vector2(75, 50)` to the ladder at
`(1465, 350)`, targeting platform `(1480, 420, 120, 20)`'s centre —
`(1540, 400)`. Dispatched Kimi K3 to independently verify both the
arithmetic and that this is the design-intended platform (not just the
nearest one). Result: **PASS on both** — the target sits dead-centre on the
platform (60px from each edge, well clear of the 28px player box under
either origin convention), and ground-segment data confirms this platform
is the *only* one bridging the gap directly over the level's timed gate,
with sensible path continuity on both sides. One low-severity comment-only
arithmetic slip (90px vs. a stated 70px) was also fixed; it didn't affect
the applied offset.

Kimi additionally flagged an INFO-level tightness note (the ladder clears
the platform's left edge by only ~1px while climbing past it, under an
assumed player collision box) — noted for awareness, not treated as a
defect since it doesn't reproduce as a bug and the exact player collision
origin convention wasn't independently confirmed.

## 5. Audio8 spike — correctly blocked, not attempted

Goals 1–3 above are green, which is the gate for this optional spike. It
remains blocked on its own explicit precondition: a rights-cleared,
high-pitch cartoon-style reference audio clip for zero-shot voice cloning.
None exists in this repo, none was supplied this session, and the
founder's own instruction is explicit and non-negotiable here: "Clone only
from audio you have rights to use. Do not use copyrighted character audio
as the reference" / "do not scrape South Park audio." Sourcing one without
a founder-supplied or verifiably-licensed clip isn't something to work
around. **Deferred, not attempted** — needs a reference clip from the
founder before this can move.

## Multi-model log

| Model | Work | Cost |
|---|---|---|
| `moonshotai/kimi-k3` | Torch attach-hierarchy audit | $0.2466 |
| `moonshotai/kimi-k3` | Level 3 ladder verification + stomp edge cases (first attempt hit a transient OpenRouter JSON-parse error, retried clean) | $0.4500 |
| `x-ai/grok-4.5` | Feel brief after live stomp + chase observation | $0.0033 |
| `deepseek/deepseek-v4-flash` | Compliance note | $0.0002 |

Primary Claude Code: fetch/merge, applied the audited fixes directly (all
were pure defect corrections with no design decisions — verified against
the real files before landing, not applied on the model's word alone),
built and ran the evidence harness, gates, this log, commit/push. Fable-5
was not separately dispatched — the torch and ladder fixes were fully
derived from Kimi's audit output plus direct file verification, and a
second model round-trip for applying already-fully-specified 2-6 line
fixes would have spent rate-limited budget without adding confidence.
DeepSeek's compliance note explicitly signed off on this as acceptable
given no design decisions were involved.

## Scope discipline

Did not touch: mobile, titles, How-To-Play, PostHog, Sentry, or the
camera-limit fix (explicit boundary). The temporary debug-warp code used to
gather live evidence (three-stage teleport sequence in
`level_01_smoke_realm.gd`, physics-frame-count waits, a postMessage beacon
per stage) was fully reverted before commit — the file matches its
pre-session state except for nothing; no trace remains
(`grep -n DEBUG src/level/level_01_smoke_realm.gd` returns empty).

## Gates

`script_compile_test`, `boss_arena_reachable_test`, `boss_visibility_test`,
`distributor_behaviour_test`, `blaze_rush_layout_test`, `save_compat_test`,
and `security-sentinel.sh` (18/18, fail-on=high) all green after every
change in this session.
