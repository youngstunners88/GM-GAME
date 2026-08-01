# DeepSeek — three-layer compliance note (defects + aesthetics phases)

You are the process compliance auditor for a Claude-run Godot 4.3 game
session, replacing a "Gemini 3.5 Ultra" role that does not exist on
OpenRouter (confirmed previously via live catalogue lookup). Assess whether
this session followed the founder's routing law: **defects first, permanent
guard-skills second, aesthetics only after — never reversed.**

## What actually happened, in order

**Router:** Two founder prompts (a defect-list prompt + a routing addendum
that took priority on conflict) named 11 defects in strict priority order,
mandated `anthropic/claude-fable-5` as lead implementer via OpenRouter to
conserve primary Claude Code's own rate limit, `qwen/qwen3.7-flash` for
screenshot vision analysis, and heavy Grok/Kimi/DeepSeek dispatch. No
screenshot images were actually attached to the session (only two markdown
prompt files) until the user supplied 4 screenshots mid-turn — Qwen vision
was never dispatched; Claude analyzed the provided screenshots directly
instead (native vision), stated as a deviation, not hidden.

**Workspace Context:** Read STATUS.md-adjacent code directly (blaze_rush.gd,
blaze_portal.gd, ladder.gd, player.gd's climb/hurtbox code, auditor.gd,
tax_collector.gd, coin.gd/gold_token.gd + .tscn, lil_blunt_visual.gd,
level_02_crystal_caverns.gd, level_base.gd, level_01/02/03 resource .tres
files) BEFORE writing any fix, and before dispatching Grok/Kimi/Fable
prompts (each dispatch inlined real file contents via @include, not
descriptions).

**Root causes found by direct code reading, before/alongside dispatch:**
1. `blaze_rush.gd::_exit_to_level()` hardcoded `save_checkpoint(1, ...)`
   regardless of launch level — one-line fix, found by Claude directly.
2. `player.tscn`'s Camera2D hardcoded `limit_right=3400` (matched Level 1's
   width by coincidence; Level 2/3 are 4400 wide with boss arenas beyond the
   clamp) — found by Claude directly, fixed via a new
   `LevelBase._setup_camera_limits()`.
3. Level 1's second ladder used the untuned default `top_exit_offset`,
   landing short of its platform — found by Claude directly by cross-
   referencing ladder position against the level's `platforms` array.

**Dispatches (all landed, none silently dropped):**
- Fable-5 (`anthropic/claude-fable-5`): stomp-attack implementation +
  Auditor boss chase/attack redesign, $0.7952. Its code was reviewed, not
  applied blind — a real Godot 4.3 parse-error trap was caught (`var p :=
  get_first_node_in_group(...)` returns untyped `Node`, so `p.
  global_position` is a Variant and `var x := <Variant>` is a hard parse
  error; Fable's draft had this bug, Claude fixed it before landing).
- Grok 4.5 x2: Tax Collector chase/jump/attack feel brief ($0.0034), Blaze
  Rush art direction ($0.0050). Both used directly — Grok's "one vertical
  slice" recommendation (a parallax forest treeline) became the actual
  aesthetics implementation via Muapi.
- Kimi K3 x2: ladder/token/stomp audit ($0.4179), Tax Collector AI + camera
  audit ($0.3412). Both surfaced additional REAL bugs beyond what was asked
  — a stale `is_on_wall()` collision-mask bug (player physically blocked the
  boss), an uninitialized `state_timer` (boss aggro'd on the very first
  frame), and a float-rounding bug in the phase-3 threshold (`ratio <=
  0.33` excluded exactly 33.3%) — all confirmed against the real file and
  fixed.
- DeepSeek (`deepseek/deepseek-v4-flash`, NOT the dated `-0731` variant,
  which is blocked by an OpenRouter account data-policy guardrail — a
  repeat of an issue from a prior session, flagged again here): drafted the
  7 defect-guard skills, landed under `.claude/skills/` with the project's
  real frontmatter format (adapted from DeepSeek's draft, not copy-pasted
  verbatim).

**Evidence gathered (not just claimed):** A full gate battery
(script_compile, distributor_behaviour, boss_arena_reachable,
security-sentinel) run repeatedly through the session. Real browser
evidence via temporary, fully-reverted debug warps: (1) Level 1 organic
15-90s playthrough — reached PLAYING, zero script errors, though the
scripted "player" died too fast to observe every mechanic cleanly (reported
honestly as inconclusive for that specific run, not claimed as a pass); (2)
Level 2 boss-visibility fix — direct screenshot proof the Distributor boss
and Lil Blunt are now BOTH visible and stay visible while moving right
(previously neither ever appeared in this project's screenshots across
multiple sessions); (3) Blaze Rush — direct screenshot proof of the new
treeline art rendering correctly, and a state-transition trace proving ESC
exit correctly returns to the originating level and reaches PLAYING there.

**Aesthetics phase:** Only started after all defect fixes above were
applied and gate-battery-verified. One vertical slice only (a Muapi-
generated forest-treeline parallax layer for Blaze Rush, per Grok's #1
recommendation) — rotating protocol logos (also in Grok's brief) were
scoped but NOT implemented this session, stated as deferred, not silently
dropped.

**Temporary debug code:** Three separate debug-warp edits were made across
the session (Level 2 boss-visibility warp, Blaze Rush direct-route warp) —
each was git-diffed to confirm isolated scope, then `git checkout --`
reverted immediately after evidence was captured, confirmed via a second
`git diff` showing zero remaining changes, BEFORE the final commit.

## Your task

Answer plainly, under 250 words total:
1. Was the founder's strict order (defects → guard-skills → aesthetics)
   actually followed, or was it reversed/interleaved improperly at any point?
2. Was Fable-5 used as intended (lead implementer, primary conserving its
   own tokens by delegating reasoning), and was its output verified rather
   than trusted blindly? Cite the specific catch (the parse-error trap) as
   evidence either way.
3. Was Qwen's absence (no screenshots were attached until mid-session)
   handled honestly, or should it have blocked more of the session than it
   did?
4. Any violation of "do not rebuild a working layer" — did any fix touch
   the mobile overlay, titles, How-To-Play, or observability wiring from
   prior sessions?
5. One-line verdict: COMPLIANT / COMPLIANT WITH NOTES / NON-COMPLIANT.
