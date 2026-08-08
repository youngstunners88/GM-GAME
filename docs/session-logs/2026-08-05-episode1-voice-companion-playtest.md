# Episode 1: Lil Blunt's voice, companion chat, human playtest package — 2026-08-05

Session type: Episode 1 completion, per
`PROMPT_EPISODE1_VOICE_PLAYTEST_COMPLETE.md`. Rate-limit mode: Grok/Kimi/
Fable-5/DeepSeek carried the design, audit, and implementation drafting;
primary Claude Code did fetch, verification against the real files, gates,
and commit.

Episode 2 was not designed, mentioned as work, or started. PR #12 was NOT
merged and no merge is recommended — that gate is the founder's playtest.

## 1. Human playtest checklist (the headline deliverable)

`docs/playtest/episode1-human-checklist.md` — 36 ordered steps across boot,
movement, ladders, torch-in-hand (idle AND walking, the case that was
actually broken), stomp, combat, the newly tuned Auditor chase, Blaze Rush
exit, Stages 2/3 boss visibility, and mobile. Every item is something that
was reported broken at some point and has since been fixed; the list exists
to confirm the fixes hold up in a human's hands.

Step 24 is explicitly flagged as the one where the founder's verdict is the
real answer: last session's chase tune (0.7s speed ramp + 0.35s contact
grace) was made from a code review, never a playtest.

The checklist also states plainly what is *expected* to be missing
(placeholder art; and the voice work, if testing a build from before this
session) so absence isn't misread as breakage.

## 2. Lil Blunt's action VO — shipped, on a STAND-IN voice

**Blocker, stated plainly:** the founder-supplied voice ID
`HMGfKwZCRujgXyRDUW0b` returns `voice_not_found` from the ElevenLabs API on
this account's key. Queried `/v1/voices`: 41 voices available, none with
that ID. ElevenLabs shared-library voices must be added to a workspace
before the API can address them, which is a dashboard action only the
founder can take.

Rather than ship silence, the full pipeline was built and generated against
a clearly-labelled stand-in (`bIHbv24MWmeRgasZH58o`, "Will — Relaxed
Optimist", chosen as the closest chill/optimistic match to the brief). The
five clips exist, play, and are wired. **Swapping to the real voice is a
one-field change**: add the voice in the ElevenLabs dashboard, set
`voice_id` to the recorded `voice_id_intended` in
`assets/audio-manifest.json`, and run
`python3 scripts/generate_audio.py --force vo_hurt vo_death vo_attack vo_collect_major vo_boss_hype`.
The intended ID and these instructions are recorded per-line in the
manifest's `voice_status` field so they can't be lost.

**Generator change**: `scripts/generate_audio.py` gained a per-line
`voice_id` override. The manifest's top-level `voice_id` is the ANNOUNCER
(Callum) who narrates stage/boss intros; Lil Blunt is a different character
and needed his own voice without disturbing the existing 27 assets. Key
handling is unchanged — env var only, never inlined, never committed.

**Lines** (Grok 4.5): `vo_hurt` "Ow— okay." · `vo_death` "Welp. I'm out." ·
`vo_attack` "Yo! Got 'em!" · `vo_collect_major` "Ohh, nice." ·
`vo_boss_hype` "Heh— let's gooo."

**A new `AudioManager.play_bark()` path**, deliberately NOT reusing
`play_voice()`. Kimi flagged this as HIGH and it holds up: `play_voice()` is
single-slot and music-ducking, so barks reusing it would (a) cut off an
announcer line mid-sentence — and the killed line's `finished` never fires,
orphaning its music-restore tween — and (b) fire a duck/restore tween pair
on every single hurt. `play_bark()` has its own player, no ducking, per-id
cooldowns, and is a silent no-op when a file is missing so gameplay never
depends on VO assets existing.

### A real bug this session's audit caught and fixed

Fable-5's draft placed `vo_death` inside `Player.die()` after its guards.
Kimi's audit flagged that `GameManager.take_damage()` **already**
transitions to `GAME_OVER` before `Player.die()` is called — so `die()`'s
first guard (`if StateMachine.is_dead(): return`) returns immediately on
every health death, making a bark there dead code. Verified directly
against `game_manager.gd:216-219` and `state_machine.gd`'s transition
table: confirmed true. Moved to the killing-blow branch in `take_damage()`,
which always runs exactly once per fatal hit.

Two other model claims were checked and *rejected* rather than applied:
Kimi proposed a 0.4s `vo_attack` cooldown and Fable 8.0s. Measured the
actual clip: `vo_attack.mp3` is 1.23s, so anything under ~1.5s cuts itself
off mid-line during sustained combat, while 8s stops it reading as a
reaction at all. Set to 3.0s with that measurement recorded in the code.
The `vo_boss_hype` delay was likewise set from the measured 3.13s length of
the real `victory.mp3` (3.3s), not Fable's guessed 1.6s.

Cooldowns: hurt 4.0s, death 5.0s, attack 3.0s, collect 10.0s, boss hype
60.0s. All three attack paths (axe / flame projectile / fire breath) share
one `vo_attack` id so a single cooldown absorbs fan-axe multi-hits and
continuous flame ticks collectively.

## 3. Companion chat — Episode 1, with real game-state awareness

Treated as Episode 1 per the founder's explicit override of the earlier
roadmap doc.

`src/ui/companion_panel.{gd,tscn}` + backend `POST /companion`. This is
deliberately NOT a generic chatbot: the panel builds a read-only snapshot
of the live run (level and name, lives, health, score, whether the player
is in Blaze Rush, which boss is active, active power-ups, last damage
source, first-run flag) and sends it with every message.

Backend follows the existing `/oracle` hardening contract exactly — per-IP
rate limit, global daily spend cap, link stripping, length clamp — plus one
addition: **every state field is whitelisted and clamped server-side**, and
the state is passed in its own system turn explicitly labelled as data, not
instructions, so a tampered client can't smuggle prompt injection through
a game-state field. No wallet address is sent; the companion has no reason
to know it.

The Godot client never holds a model key — same proxy rule as the rest of
the project.

**Degradation ladder**, so core platforming never depends on this: no
backend → in-character line; offline → **state-aware canned lines** (still
reacts to the run); request failure → in-character retry line.

**Verified working in a real browser build**, not just compiled: clicked
"TALK TO LIL BLUNT" from the main menu, typed a message, and got the
correct state-conditioned offline reply — "Just gettin' started. Take the
scenic route if you want, no rush." — which is precisely the `first_run`
branch (score 0, level 1). That proves the state plumbing works end to end,
offline, with zero script errors. Screenshot evidence in `/tmp/vo-evidence`.

**Reachability note, stated honestly.** The companion is wired into BOTH
the pause menu (mid-run, where it matters most) and the main menu. The
main-menu path is confirmed working in-browser. The pause-menu path is
verified structurally — the button exists, is connected, and the scene
instantiates (headless probe confirmed all three) — but I could not drive
the pause menu open in the automated browser harness, because neither
Playwright's synthetic Escape nor a headless `InputEventAction` reliably
reaches Godot's `_unhandled_input`. This is a harness limitation on
PRE-EXISTING pause behaviour that this session did not modify. Adding the
main-menu entry point was a deliberate response: it guarantees the feature
is reachable regardless of how the pause key behaves on any given
platform. Confirming the pause menu opens with a real keyboard is on the
playtest checklist.

## 4. Not done / out of scope

- **Blaze Rush art slice (goal D)**: not started. It was explicitly
  conditional on A–C being green with time remaining; the voice-ID blocker
  and the `vo_death` bug consumed that margin. The founder's reference pack
  was unpacked and reviewed but no art was generated — better to leave it
  untouched than to half-start a visual pass.
- Episode 2, meme guests, NFT mint, Audio8, Polygres, Freebuff,
  Agent-Reach: untouched, as instructed.
- PR #12: still draft, still the founder's call after playtest.

## Multi-model log

| Model | Work | Cost |
|---|---|---|
| `x-ai/grok-4.5` | 5 VO bark lines + companion tone paragraph + 8 state-conditioned example lines | $0.0056 |
| `moonshotai/kimi-k3` | Event call-site audit — caught the `vo_death`-in-`die()` dead-code bug | ~$0.35 |
| `anthropic/claude-fable-5` | `play_bark()` implementation + call-site drafting (lead) | $0.2975 |

Primary Claude Code: fetch/merge, verification of every model claim against
the real files (two were rejected on measurement), the ElevenLabs blocker
diagnosis, backend endpoint, companion panel, browser evidence, gates,
docs, commit.

## Gates

`script_compile` (114 scripts / 77 scenes), `boss_arena_reachable`,
`boss_visibility`, `distributor_behaviour`, `blaze_rush_layout`,
`save_compat` — all PASS. Security sentinel 18/18, 0 blockers. Browser
run: 0 script errors. No API key appears in any committed file.
