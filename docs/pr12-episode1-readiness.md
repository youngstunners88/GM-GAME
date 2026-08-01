# PR #12 — Episode 1 readiness

Honest snapshot as of 2026-08-04. This is a readiness report, not a merge
request — **whether to merge PR #12 to `master` is a founder decision**,
made explicitly below and not implied by anything else in this doc.

## Green — verified, not reopened this session

- **Torch-in-hand**: fixed and evidenced (idle + walking) 2026-08-03. Walk-
  bob decoupling and leg-clip bugs fixed in `lil_blunt_visual.gd`.
- **Stomp**: live-evidenced (+40 score, zero life loss) 2026-08-03. Climb-
  state false-trigger and ground-pound boss-AoE gap both fixed.
- **Level 3 ladder**: fixed and independently re-verified (Kimi K3, PASS on
  arithmetic and design-intent) 2026-08-03.
- **Stage 2/3 camera limits / boss visibility**: fixed 2026-08-02, not
  touched or re-litigated since.
- **Blaze Rush lifecycle + ESC exit**: fixed 2026-08-02.
- **Seven defect-guard skills** (`.claude/skills/`): landed 2026-08-02,
  actively used this session (`boss-chase-ai-auditor` ran against this
  session's own change).
- **Full gate battery** (this session, post chase-tune):
  `script_compile_test`, `boss_arena_reachable_test`, `boss_visibility_test`,
  `distributor_behaviour_test`, `blaze_rush_layout_test`, `save_compat_test`
  — all PASS.
- **Security sentinel**: 18/18, 0 blockers at fail-on=high.
- **Boss-chase-ai-auditor skill checklist** (live tracking, jump-gap
  derivation, telegraph, attack-while-moving, untouched systems) run
  against the Auditor chase tune below — all 5 checks pass.

## Soft — tuned this session, judgment-based, not re-litigated defects

- **Auditor chase punish window**: PURSUE now ramps speed 55%→100% over
  0.7s and delays the contact hitbox by 0.35s, per a Grok 4.5 feel review
  reading the actual code (not a guess). A Kimi K3 post-tune audit caught
  one real regression this introduced — the jump-gap gate
  (`max_jump_gap`) was derived at full speed and needed to scale with the
  same ramp factor, or a jump attempted in the first ~0.2s of a chase
  could fall short of a gap it was supposed to clear safely. Fixed in the
  same pass. Top speed, live player tracking, throw-while-chasing cadence,
  and jump gating logic itself are all unchanged in shape — only the
  approach curve and the contact-damage grace window changed.
- **No fresh browser evidence gathered for the tune.** This is a
  deliberate scope call, not an oversight: the change is fully covered by
  (a) a concrete numeric brief from Grok read against the real code, (b) a
  Fable-5 implementation verified line-by-line against the actual file
  before being applied, (c) a Kimi K3 audit of the *actual applied diff*
  that found and led to fixing one real regression, and (d) this project's
  own `boss-chase-ai-auditor` skill checklist run clean against the final
  code. Given this session's explicit rate-limit-conservation mandate, a
  browser evidence pass was judged lower value than the static/multi-model
  trail already gathered. One specific correctness risk an earlier Kimi
  pass flagged as "must verify empirically, not assume" — whether Godot 4.3
  actually re-fires `body_entered` when the Hitbox's `monitoring` flips
  false→true while the player is ALREADY overlapping it (the common case:
  the boss catches up and they stay touching through the whole 0.35s
  grace) — was tested directly with a throwaway headless probe scene
  (built, run, confirmed, deleted — not part of this diff). Result: it
  fires correctly, and the real Hitbox's collision mask (70) does include
  the player's layer, so this isn't a "works in theory" risk. **Recommended
  before merge, not before this PR stays open**: one real playthrough of
  the first Auditor encounter to confirm the tune *feels* right, since feel
  is inherently something code audits can approximate but not fully
  replace.

## Deferred — explicitly out of scope, not attempted

- **Audio8 synthesis**: blocked on a rights-cleared reference clip that
  doesn't exist yet (2026-08-03 finding, unchanged).
- **Full companion conversation (StreamCore or equivalent)**: sequenced
  after Episode 1 residuals per the Layer Strategy doc; not started.
- **Episode 2 guest characters, NFT mint, Agent-Reach deploy, Polygres,
  Freebuff, Smoke Lounge video**: all explicitly out of scope for this
  closeout session per the founder's router; none touched.
- **Action VO synthesis**: hook *names* were proposed this session
  (`docs/roadmap/episode-strategy-and-voice-system.md`), but no ElevenLabs
  batch generation or code wiring was done — that needs an explicit scope
  expansion from the founder first.

## Merge recommendation

**Founder call.** PR #12 stays in draft unless the founder says otherwise.
Everything in the Green section above is genuinely ready; the Soft item is
a real gameplay change that would benefit from one human playthrough before
merge, not because anything failed, but because chase-feel is the one
category of change this session's static/multi-model audit trail can't
fully substitute for.

## Session multi-model log

| Model | Work | Cost |
|---|---|---|
| `x-ai/grok-4.5` | Concrete chase-tune numbers from the real code | $0.0039 |
| `anthropic/claude-fable-5` | Implemented the exact GDScript diff (lead, per rate-limit law) | $0.1489 |
| `moonshotai/kimi-k3` | Post-tune audit of the applied diff — found the jump-gap regression | $0.1737 |
| `deepseek/deepseek-v4-flash` | This readiness checklist + compliance note | $0.0003 |

Primary Claude Code: fetch/merge, verified and applied Fable-5's diff
against the real file, applied Kimi's fix, ran the gate battery + skill
checklist, wrote this doc + the roadmap note, commit/push.
