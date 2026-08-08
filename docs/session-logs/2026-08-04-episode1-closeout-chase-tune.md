# Episode 1 closeout: chase tune + PR readiness — 2026-08-04

Session type: Episode 1 polish + ship readiness, per
`PROMPT_EPISODE1_CLOSEOUT_CHASE_TUNE.md`. Rate-limit mode: Fable-5 led
implementation via OpenRouter; primary Claude Code did fetch, verification,
gates, and docs only. Companion doc `PROMPT_LAYER_STRATEGY_EPISODE2.md`
(Episode map + voice system architecture) was read and produced as a
roadmap note — not implemented, per its own explicit non-goals.

## 1. Residuals acknowledged closed, not reopened

Torch-in-hand, stomp, Level 3 ladder, and Stage 2/3 camera limits — all
closed 2026-08-02/03 — were not touched this session. Confirmed via
`git log` and the prior session's readiness notes before starting.

## 2. Auditor chase punish-window tune

**Problem**: the ALERT state already telegraphs the chase (0.6s freeze,
face player, SFX) before PURSUE begins, but at the instant PURSUE starts
the boss moves at full `pursue_speed` (phase-scaled) AND the contact
Hitbox goes live on the exact same frame — "he's now chasing" and "he can
now hurt you" were simultaneous, with zero grace. A founder feel review
last session found this read as an instant, unfair punish on a first
encounter.

**Process**: dispatched Grok 4.5 with the real current ALERT/PURSUE code
(not a description) for concrete numbers. Got: speed ramp 55%→100% over
0.7s, hitbox-activation grace of 0.35s after PURSUE starts. Dispatched
Fable-5 (session lead per the rate-limit law) to produce the exact GDScript
diff against the real file, with explicit constraints (no change to top
speed, live tracking, jump gating shape, or throw cadence; frame-rate-
independent elapsed-time driver). Verified Fable-5's output line-by-line
against the actual file before applying — it correctly used a
`_pursue_elapsed` accumulator reset on every ALERT→PURSUE transition, and
correctly did NOT touch `jump_force`, `max_jump_gap`'s raw value, or the
phase-scaling math.

**Regression caught and fixed**: dispatched Kimi K3 against the actual
applied diff (not the plan) for a post-tune audit. It found one real LOW-
severity issue: `max_jump_gap = 110` was derived from the boss's kinematics
at FULL `pursue_speed` — but the new ramp means a jump attempted in the
first ~0.2s of a chase launches with as little as 55% of that speed,
reducing horizontal reach below what the gate assumed. A jump gated as
"guaranteed landable" during the ramp window could now fall short. Fixed
by scaling the gate itself: `absf(dx) <= max_jump_gap * ramp`. Kimi's other
four checks (hitbox state correctness on early PURSUE exit, reset on every
re-entry, throw cadence untouched, jump *velocity* not accidentally
ramped) all passed clean on the first attempt — also independently
confirmed the scene file's Hitbox already defaults to
`monitorable/monitoring = false`, closing the one "unverifiable" note in
Kimi's audit.

**Final verification**: ran this project's own `boss-chase-ai-auditor`
skill checklist (live tracking / jump-gap derivation / telegraph / attack-
while-moving / untouched systems) against the finished code — all 5 checks
pass with the jump-gap fix in place.

**No fresh browser evidence gathered** for this specific tune — a
deliberate scope call given the thickness of the static/multi-model audit
trail above and this session's explicit rate-limit-conservation mandate,
not an oversight. Flagged explicitly in the readiness doc as the one item
worth a human playthrough before merge, since feel is the one thing a code
audit can approximate but not fully replace.

**One correctness risk was empirically tested, not just reasoned about**:
the pre-implementation Kimi pass flagged that Godot 4.3's behavior when
`Area2D.monitoring` flips false→true while a body is ALREADY overlapping
it — the exact shape of the hitbox-grace transition — "should" re-fire
`body_entered` but needed verifying, not assuming. Built a throwaway
headless probe scene (`tests/_tmp_monitoring_probe.{gd,tscn}`, deleted
immediately after, not part of this diff) with an Area2D and an
already-overlapping body from frame 0, toggled `monitoring` on after a
delay, and confirmed `body_entered` DOES fire correctly (and
`get_overlapping_bodies()` populates) the moment monitoring is enabled —
first attempt used a mismatched collision mask and correctly showed no
detection, second attempt with the mask fixed to include the body's layer
confirmed the real behavior. Cross-checked against `auditor.tscn`'s actual
Hitbox mask (70) to confirm it includes the player's layer, so the
result transfers to the real scene, not just the probe.

## 3. PR #12 Episode 1 readiness

Wrote `docs/pr12-episode1-readiness.md`: Green (all residuals + this
session's full gate battery + security sentinel 18/18 + the chase-tune
skill checklist), Soft (the chase tune itself, explicitly recommended for
one human playthrough before merge), Deferred (Audio8, full companion
voice, Episode 2 guests, NFT, action-VO synthesis). Merge recommendation is
stated explicitly as a founder call — PR #12 stays in draft.

## 4. Layer strategy / voice system architecture note

Wrote `docs/roadmap/episode-strategy-and-voice-system.md` per the
companion prompt: the canonical Episode 1 vs Episode 2 table, the two-
channel Lil Blunt voice system definition (companion conversation,
deferred; action onomatopoeia, hook-names-only this session), a proposed
action-VO hook list reusing the existing `AudioManager.play_voice()`
single-slot mechanism (no new audio system needed), a read-only companion
state API sketch for future StreamCore work, and the layer-placement table
for other roadmap items (AgentMail, PostHog/Sentry, NFT sinks, meme
guests). No synthesis, no wiring, no StreamCore deploy — names and
placement only, per the prompt's explicit non-goals.

## Multi-model log

| Model | Work | Cost |
|---|---|---|
| `x-ai/grok-4.5` | Concrete chase-tune numbers from the real code | $0.0039 |
| `anthropic/claude-fable-5` | Implemented the exact GDScript diff | $0.1489 |
| `moonshotai/kimi-k3` | Post-tune audit — found + specified the jump-gap fix | $0.1737 |
| `deepseek/deepseek-v4-flash` | PR readiness checklist + compliance note | $0.0003 |

Total OpenRouter spend this session: ~$0.33. Primary Claude Code: fetch/
merge, verification of every dispatched model's output against the real
files before applying, gate battery, skill-checklist pass, both docs, this
log, commit/push.

## Scope discipline

Out of scope and untouched: Episode 2 guests, NFT mint, Agent-Reach
deploy, Polygres, Freebuff, Audio8 synthesis, Smoke Lounge video, mobile/
titles/How-To-Play/PostHog/Sentry/camera-limit systems, full StreamCore
companion implementation.

## Gates

`script_compile_test`, `boss_arena_reachable_test`, `boss_visibility_test`,
`distributor_behaviour_test`, `blaze_rush_layout_test`, `save_compat_test`,
`security-sentinel.sh` (18/18, fail-on=high), and the `boss-chase-ai-
auditor` skill checklist — all green after the tune.
