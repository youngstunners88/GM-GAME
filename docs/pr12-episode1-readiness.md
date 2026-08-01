# PR #12 — Episode 1 readiness

Honest snapshot as of 2026-08-06. This is a readiness report, not a merge
request — **whether to merge PR #12 to `master` is a founder decision**,
made explicitly below and not implied by anything else in this doc.

## Green — verified, not reopened

- **Torch-in-hand** (idle + walking), **stomp**, **Level 3 ladder**,
  **Stage 2/3 camera limits / boss visibility**, **Blaze Rush lifecycle +
  ESC**, and the **seven defect-guard skills** — all fixed and evidenced in
  earlier sessions, untouched since.
- **Lil Blunt's real custom voice is LIVE** on all five action barks
  (`ELEVENLABS_API` key). The earlier `voice_not_found` 404 was a
  wrong-key problem, not a missing voice: the environment carries two
  ElevenLabs keys and only `ELEVENLABS_API` belongs to the workspace that
  owns the custom "Lil Blunt" voice. The stand-in is gone.
- **Engine-level bark verification**: all 5 barks load from exported
  paths, create a live player on the SFX bus, per-id cooldowns suppress
  repeats, and a missing file is a silent no-op. Clip lengths 0.84–1.53s;
  every cooldown exceeds its own clip length, so no bark can cut itself
  off.
- **Companion offline lines rotate** for the two states a struggling
  player hits most (last life, died-to-Auditor) — 3 extra variants each
  instead of replaying one sentence.
- **Companion main-menu entry browser-verified**; pause-menu entry
  structurally verified (button present, connected, scene instantiates).
- **Full gate battery + security sentinel 18/18**, re-run after this
  session's changes.

## Soft — real, but unverified by a human

- **The founder has still NOT run
  `docs/playtest/episode1-human-checklist.md`.** This is the single
  biggest open risk on the project and the gate for calling Episode 1
  complete. Nothing below substitutes for it.
- **The Auditor chase tune is still CODE-ONLY** (0.7s speed ramp + 0.35s
  contact grace). It was derived from a review, never played. Checklist
  step 24 is the open verdict.
- **Companion pause-menu path** was never driven open in an automated
  browser harness — synthetic Escape doesn't reach Godot's
  `_unhandled_input`. This is a harness limitation on pre-existing pause
  behaviour, and the browser-verified main-menu entry means the feature is
  reachable either way. Confirming with a real keyboard is on the
  checklist.

## Deferred — explicitly untouched

Episode 2, meme guests, NFT mint, Audio8, Polygres, Freebuff, Agent-Reach,
StreamCore redesign, and the optional Blaze Rush art slice.

## Merge recommendation

**Founder call, after the playtest.** Merging PR #12 remains a founder
decision once `docs/playtest/episode1-human-checklist.md` is complete —
this is explicitly not a recommendation to merge now.

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
