# Episode 1: real Lil Blunt voice swap + companion close-path fix — 2026-08-06

Session type: audio identity + playtest support. Rate-limit mode (94%):
Grok / Kimi / DeepSeek carried design, audit and doc work in parallel;
primary Claude Code did env detection, verification, gates and commit.

Episode 2 untouched. PR #12 not merged — that remains the founder's call
after the playtest checklist.

## 1. The real voice is LIVE — and the 404 was a wrong-key problem

Last session the founder-supplied voice ID `HMGfKwZCRujgXyRDUW0b` returned
`voice_not_found`, so the barks shipped on a labelled stand-in. This
session the founder pointed at a new env name, `ELEVENLABS_API`.

Checked both keys against `/v1/voices` (names and counts only, no values
printed):

| Env name | Auth | Voices | Target voice present |
|---|---|---|---|
| `ELEVENLABS_API` | OK | 27 | **YES — named "Lil Blunt", category `generated`** |
| `ELEVENLABS_API_KEY` (legacy) | OK | 41 | no |

So the voice was never missing — the old key simply belongs to a different
workspace that cannot see it. Both keys authenticate, which is exactly why
this looked like a missing-voice problem rather than a wrong-key one.

**Changes:**
- `scripts/generate_audio.py` now resolves the key from
  `("ELEVENLABS_API", "ELEVENLABS_API_KEY")` **in that order**, with a
  comment explaining that order matters and why flipping it back
  reintroduces the 404. Values are never printed or committed.
- All five `vo_*` manifest entries repointed to `HMGfKwZCRujgXyRDUW0b`;
  the `voice_id_intended` placeholder field is gone, and `voice_status`
  now records that this voice requires the `ELEVENLABS_API` workspace.
- Regenerated the five barks only (`--force`), 0 failures. The stand-in is
  gone.

**Verified at engine level** (headless probe, built/run/deleted — not
committed), because "the file downloaded" is not the same as "the game can
play it":

| bark | length | cooldown | loads | live player on SFX bus |
|---|---|---|---|---|
| `vo_hurt` | 1.30s | 4.0s | ✓ | ✓ |
| `vo_death` | 0.88s | 5.0s | ✓ | ✓ |
| `vo_attack` | 1.11s | 3.0s | ✓ | ✓ |
| `vo_collect_major` | 0.84s | 10.0s | ✓ | ✓ |
| `vo_boss_hype` | 1.53s | 60.0s | ✓ | ✓ |

Every cooldown exceeds its own clip length, so no bark can cut itself off.
Also asserted: the cooldown genuinely suppresses an immediate repeat, and
a missing file is a silent no-op rather than a crash.

A browser probe that counted `AudioBufferSourceNode.start()` calls showed
no change and was **discarded as invalid, not reported as a failure** —
Godot 4's web driver mixes all audio through a single AudioWorklet, so
individual game sounds never appear as separate buffer sources. The engine
-level probe above is the authoritative check.

## 2. A real soft-lock in the companion close path — found and fixed

Kimi's re-audit found a genuine defect this session introduced last
session, and it is worse than cosmetic:

`CompanionPanel.close()` set `visible = false` and `paused = false` but
never freed the node. The pause menu re-shows itself on the panel's
`tree_exited`, which therefore **never fired**. End state after closing the
companion from the pause menu: StateMachine still `PAUSED` (so
`player.gd` keeps gameplay gated off), tree unpaused, and no visible menu —
a soft-lock recoverable only by pressing the pause key, on exactly the
platforms where that key is least reliable. It also leaked one invisible
panel per Talk-button press.

**Fix:** `close()` now `queue_free()`s the panel so `tree_exited` fires,
and hands the tree back to gameplay only when not returning to a paused
menu (`get_tree().paused = StateMachine.is_paused()`), so the main-menu
path still unpauses correctly while the pause-menu path stays paused
under the re-shown menu.

**Verified behaviourally**, not by inspection — a probe drove
pause → Talk → close and asserted: panel freed ✓, pause menu re-shown ✓,
tree still paused ✓, StateMachine still PAUSED ✓, and **zero live
`CompanionPanel` nodes after four open/close cycles** ✓ (an initial
node-count heuristic flagged a false leak; the definitive per-node check
came back clean — the drift was unrelated level entities).

Two of Kimi's five items came back `UNVERIFIED` purely because I hadn't
inlined those files. Both were confirmed directly instead: all three hit
paths (`axe.gd`, `flame_projectile.gd`, `fire_breath.gd`) do call
`play_bark("vo_attack", 3.0)` with the shared id, and `_on_talk_pressed`
is connected from `level_base.gd`, `secret_realm.gd`, and exposed in
`main_menu.gd`.

## 3. Companion offline lines no longer repeat themselves

The two states a struggling player hits most (`low_lives`, `boss_death`)
had exactly one canned line each, so dying to the Auditor repeatedly
replayed one identical sentence — canned at precisely the moment it should
not be. Added three Grok-written alternates per state and a round-robin
picker (`_line_for`). Deliberately rotation, not random: at pool size 3,
random visibly repeats. Turn 0 still uses the original wording so the
established first impression is unchanged.

## 4. Not done / deliberately not expanded

- **Playtest feedback loop: no feedback to act on.** The founder has still
  not run `docs/playtest/episode1-human-checklist.md`. Per the brief, no
  bugs were invented and the chase tune (step 24) was left alone — it is
  still code-only and awaiting a human verdict.
- **Blaze Rush art slice: not started.** It was gated on the playtest
  being clean; there is no playtest yet, so the gate isn't met.
- **Qwen: N/A this session** — its role is reading founder fail
  screenshots, and none were attached.
- **Observed, not chased:** loading Level 1 in a headless probe emits two
  `Invalid assignment of property 'color' ... on a base object of type
  'Sprite2D'` script errors. This is pre-existing and outside this
  session's diff (which touches only the manifest, generator, companion
  panel, readiness doc and five .mp3s — none assign `color` to a Sprite2D).
  No gate catches it and it does not block play. Flagged here for a future
  session rather than expanding scope at a 94% rate limit.

## Multi-model log

| Model | Work | Cost |
|---|---|---|
| `x-ai/grok-4.5` | 3 alternate companion lines each for low-lives / boss-death | $0.0056 |
| `moonshotai/kimi-k3` | Post-swap bark re-audit — found the companion soft-lock | ~$0.30 |
| `deepseek/deepseek-v4-flash` | Readiness-doc status rewrite | $0.0007 |
| `anthropic/claude-fable-5` | N/A — the swap was a config change plus a 6-line fix; a dispatch round-trip would have cost more than it saved |
| `qwen` | N/A — no founder fail screenshots attached |

Primary Claude Code: env detection, voice-workspace diagnosis, generator
key-order change, regeneration, engine-level and behavioural verification,
gates, docs, commit.

## Gates

`script_compile` (114 scripts / 77 scenes), `boss_arena_reachable`,
`boss_visibility`, `distributor_behaviour`, `blaze_rush_layout`,
`save_compat` — all PASS. Security sentinel 18/18, 0 blockers. No API key
value appears in any tracked file.
