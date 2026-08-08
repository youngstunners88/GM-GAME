# 2026-07-31 — Distributor feel observation (Three-Layer System)

Session type: product-layer observation + feel, per
`PROMPT_DISTRIBUTOR_FEEL_THREE_LAYER.md`. Video work stayed deferred. No
infrastructure (CI, Sentry, PostHog, PixelLab) was touched. Fetched and
fast-forwarded the branch first; confirmed `tests/distributor_behaviour_test.gd`
green before any implementation, per the router's gate.

## Goal 1 — real feel observation of The Distributor

Chose the founder's first-preference option: a temporary debug warp in a
real browser, reverted before commit. Two files were touched temporarily and
both are fully reverted in this commit (`git diff` against the prior commit
shows neither file changed):
- `src/level/level_02_crystal_caverns.gd` — a guarded `_debug_warp_to_boss()`
  placed the player just inside the boss arena and fired the same trigger a
  real approach would.
- `src/ui/main_menu.gd` — PLAY routed to Level 2 instead of Level 1 for this
  session's export only.

### What was actually launched, run by run

**Run 1 (unguarded warp):** LIVES dropped from 3 to 0 in ~3 seconds of
observed time. Root-caused, not boss evidence: `Player.die()` with no
checkpoint set (`GameManager.reset_session()` had just run) falls through to
`get_tree().reload_current_scene()` — which re-ran `_ready()` and re-fired
the unguarded warp, throwing the player back at a **freshly full-health**
boss on a tight loop with zero ramp-up each time. Fixed by gating the warp
with `Engine.set_meta(...)` so it fires exactly once, surviving scene
reloads (`Engine`, unlike the scene tree, persists across
`reload_current_scene()`).

**Run 2 (guarded warp, blind "hold Left" input policy):** Still hit
GAME_OVER, this time in ~11 seconds. Root-caused, again not boss evidence:
the observation script held one direction continuously to "resist the pull,"
which walked the player directly off the west edge of the arena's ground
segment into a **previously-unmapped ~200px pit** — `level_02_data.tres`'s
`ground_segments` array has a gap between `Vector4(3100,650,400,70)` (ends at
x=3500) and `Vector4(3700,650,700,70)` (starts at x=3700), and the boss
arena's own wall sits at that same x=3700 boundary. `pit_death()` correctly
fired, cost a life via the pit path, and repeated because the script kept
holding the same direction. This is a real, standalone level-geometry
finding — a player standing at the arena's west edge and stepping/getting
pushed further west than expected falls into an unintended pit — but it is
**Crystal Caverns level data, not a Distributor mechanic**, and is
**documented here rather than fixed**, to stay inside this session's scope
(boss feel, not level redesign). Fixed the *script's* policy (short 300ms
alternating bursts instead of a sustained run) and moved the debug-warp
offset from -300 to -200 (comfortably clear of the pit) so the harness
itself would stop tripping it.

**Run 3 (guarded warp, oscillating input, safer spawn offset):** This run
produced the session's real evidence:
- Full pipeline confirmed live: menu boot → PLAY → Level 2 loads → the boss
  arena instantiates → "THE DISTRIBUTOR" health bar appears at 7/7 → a real
  attack landed and dealt damage (**7/7 → 6/7** health pips) → score
  increased to 75 → **zero Godot script errors** across all three runs.
- The first hit landed within the first ~11-14 seconds of the encounter,
  consistent with the coded initial cadence (`throw_timer` starts at
  `throw_cooldown = 2.0`) — the fight opened on schedule.
- **Not resolved this session:** the remaining ~35 seconds of the
  observation window went visually static — identical enemy positions and
  identical boss health across multiple screenshots taken 3+ seconds apart,
  before `GAME_OVER` eventually fired. The most likely explanation is a
  headless-browser input-focus artifact (synthetic keyboard events not
  reliably reaching a canvas that lost focus, common with Playwright driving
  a canvas-only page with no explicit re-focus between actions) rather than
  a real engine soft-lock, but this was **not conclusively isolated** — I am
  stating that plainly rather than guessing. The player sprite itself was
  also never clearly visible in any of the 20+ screenshots across all 3
  runs, despite the boss health bar, damage, and score all confirming the
  player was present and acting — possibly a camera-follow smoothing edge
  case specific to the instant-teleport debug harness (a real player walking
  in would never trigger an instant, non-interpolated jump), also not
  isolated this session.

### Honest bottom line on feel

**Stronger than unit tests alone, but not a full feel validation.** Real,
new evidence obtained this session: the boss fight is reachable and playable
in an actual exported browser build, the arena/UI/audio pipeline all engage
correctly, and the very first exchange happens on schedule with zero
errors. **Not validated**: Forced Distribution's redirect-window
readability, orb cadence beyond the first throw, POOL DRAIN in a live
session, and pace across a full multi-phase fight. These remain exactly
where the prior session's honest-gaps section left them — this session
narrowed HOW to get evidence (the warp technique now works and is
documented) without yet producing the deeper feel data, because the
observation window was consumed by harness debugging and then went static
for unexplained reasons.

**No Distributor mechanic values were changed.** Per "tune only what the
evidence proves wrong": nothing observed this session contradicts any
specific coded number. Grok's dispatch below flags `max_health = 7` as a
*comparative design opinion* (higher than the other two bosses' 6), not
something this session's live play proved wrong — recorded as a named
hypothesis for the next real human playtest, not acted on.

## Goal 2 — flush-error monitoring item

Not touched, per instruction. No re-hunt was performed; it remains a
monitoring item per `docs/session-logs/2026-07-31-distributor-evidence-and-flush-recheck.md`.

## Multi-model

**Kimi K3 — correctly skipped.** Its mandatory-dispatch condition is a
change to the Distributor's state machine/damage/pull/redirect/test-harness
code. No such change was made to `distributor.gd` this session (only to
level/menu files, both reverted before commit) — dispatching would have
been paying to audit a diff that doesn't exist.

**Grok 4.5 — dispatched, matched its role.** `x-ai/grok-4.5` via OpenRouter,
$0.0099. Brief and response: `prompts/grok-distributor-feel-observation.md`,
`docs/model-responses/2026-07-31-grok-distributor-feel-observation.md`.
Findings: flagged `max_health = 7` as a mid-game boss being tankier than
both other bosses (Auditor and Claim Jumper are both 6) — a comparative
opinion, not proof, recorded as a hypothesis. Recommended the single next
playtest focus: Forced Distribution redirect readability specifically at
the phase-3 1.1s vulnerable window, since that's the fight's main skill
verb and the one system this session's live observation never reached.

**Gemini 3.5 Ultra — attempted, does not exist.** The founder prompt names
this exact model as the new standing process/specs-compliance role. Queried
OpenRouter's live model catalogue directly: no `google/gemini-3.5-ultra` (or
any "Ultra" tier of any Gemini generation) exists in it. Confirmed via
`or-call.mjs`'s own catalogue check rather than assumed. Per the founder
prompt's own explicit fallback ("Gemini, or Claude if Gemini call fails"),
Claude authored the compliance note below directly. **This is a standing
gap worth flagging back to the founder**: "Gemini 3.5 Ultra" is not a real,
callable model ID today — a future prompt naming this role should either
name a real Gemini tier (e.g. `google/gemini-3.1-pro-preview`) or expect the
Claude fallback every time.

## Three-layer compliance note (Claude-authored — see above for why)

1. **Router intent clear? Anything out of scope touched?** Yes, clear.
   Nothing named out-of-scope (CI, Sentry, PostHog, PixelLab, Stage 3,
   Thirdweb) was touched. The only files modified during the session were
   two level/menu files for the temporary warp (fully reverted before this
   commit) and the multi-model prompt/response docs.
2. **Was Workspace Context loaded before implementation, in the specified
   order?** Yes — fetched/fast-forwarded first, then read STATUS.md,
   `distributor.gd`, `distributor_behaviour_test.gd`, the prior session's
   SIGSEGV/flush-error log, `gdscript-gotchas.md`, and used
   `scripts/bootstrap-godot.sh` rather than re-deriving the engine download,
   in that order, before writing any code.
3. **Were Skills/models used only in their defined roles?** Yes. Kimi was
   correctly skipped (no mechanic-code change occurred). Grok was correctly
   the one dispatched, and only after real observation existed for it to
   react to. Gemini's role was attempted exactly as specified before
   falling back.
4. **Any violation of "do not rebuild a working layer"?** No new debug,
   telemetry, or observation *system* was built — the browser-verification
   harness (`scripts/verify-game.mjs`, the Playwright pattern) and the
   existing StateMachine postMessage beacon were reused as-is. The one-off
   observation script lives in `/tmp` (session scratch), not committed as a
   permanent project script, specifically so it doesn't become a second,
   competing playtest tool alongside the existing `playtest-*.mjs` scripts.
5. **Overall verdict: COMPLIANT WITH NOTES.** The one note: Goal 1's
   deliverable ("evidence about Distributor feel is stronger than unit
   tests alone") is met only partially — real, new, positive evidence was
   obtained (live boot-to-combat, on-schedule first exchange, zero errors),
   but the deeper feel questions (redirect readability, full-fight pace)
   remain unvalidated because the observation window was consumed by
   harness debugging (two self-inflicted, now-documented, now-fixed bugs)
   and then went unexplained-static for the remainder. This is reported
   honestly rather than papered over, per the founder's explicit standard.

## Gates (final, this session)
| Gate | Result |
|---|---|
| distributor_behaviour | ALL PASS (13 checks, unchanged from prior session) |
| script_compile | ALL PASS — 113 scripts, 75 scenes |
| boss_arena_reachable | ALL PASS — all 3 levels |
| security-sentinel | 18/18, 0 blockers |

## Open items carried forward
1. Forced Distribution redirect readability and full multi-phase pace
   remain unvalidated by feel — Grok's recommended focus for the next real
   human (not scripted) playtest.
2. `max_health = 7` on the Distributor is a flagged, unconfirmed comparative
   hypothesis (Grok), not acted on.
3. A genuine, previously-unknown level-geometry gap: Crystal Caverns has an
   unmapped ~200px pit in `ground_segments` at x=3500–3700, immediately west
   of the boss arena's own wall. Out of this session's scope to fix
   (boss-feel session, not level redesign) but worth a level-design pass.
4. The mid-observation "static" period and the player sprite's invisibility
   in every screenshot both remain unexplained — flagged as harness
   artifacts, not confirmed as such.
5. "Gemini 3.5 Ultra" is not a real OpenRouter model ID as of this session —
   flagged back to the founder for the process role's model reference to be
   corrected.
