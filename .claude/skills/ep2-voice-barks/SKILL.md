---
name: ep2-voice-barks
description: Give Lil Blunt a varied voice and the bears real presence in the Episode 2 runner — reaction barks per event (boulder wreck = alarm, hop = celebration), a shuffled vocabulary that never repeats, priority/overlap rules, ElevenLabs generation, and distance-scaled 3D bear sounds. TRIGGER when the founder says Lil Blunt is silent / not reacting / repeats himself, asks for more vocabulary or personality, asks for bear or creature sounds, or a new gameplay event needs a vocal reaction.
---

# Episode 2 voice barks

Founder, 2026-09-29: "Lil Blunt is not even reacting to anything vocally. A boulder smashes a
cart, that's life-threatening! Hopping over is something to celebrate ... I want a variation in
his vocabulary." And: "use ElevenLabs for the bear sounds ... hear them in the distance as we
approach closer."

## Where things live

| Thing | File |
|---|---|
| Source of truth: lines per category, gap, priority, bear SFX prompts | `assets/ep2-voice-bank.json` |
| Build: writes manifest entries + `voice_bank.gd`, `--generate` calls ElevenLabs | `tools/ep2_voice/build_bank.py` |
| Runtime (reads the sim, never writes it) | `src/episode2/runner/runner_voice.gd` (node `Voice` in `runner_graybox.tscn`) |
| Gate | `tests/ep2_runner_voice_test.tscn` |
| Takes (MP3) | `src/assets/sounds/voice/ep2_vo_<category>_<n>.mp3`, bears `src/assets/sounds/ep2_bear_*.mp3` |

Voice = custom "Lil Blunt" `HMGfKwZCRujgXyRDUW0b`, which needs the `ELEVENLABS_API` env key
(the legacy `ELEVENLABS_API_KEY` workspace cannot see it). Never print keys.

## Adding or changing a reaction

1. Edit `assets/ep2-voice-bank.json` (category → `lines`, `gap`, `priority`).
2. `python3 tools/ep2_voice/build_bank.py --generate` (only missing takes are generated).
3. `godot --headless --import`, then run the voice test.
4. Hook the event in `runner_voice.gd` (`say("<category>")` from a sim signal, or poll in `_process`).

## The rules that keep it from sounding like a tic

- **Emotion matches stakes.** Boulder smash / hit are ALARM; hops and clears are CELEBRATION;
  coins are a small treat. Write the line to the moment: short, punchy, in his chill-but-hyped voice.
  Nothing aggressive; no drug-stereotype lines (CLAUDE.md global rules).
- **Vocabulary depth:** ≥4 lines per common category, ≥8 for hops (he does it constantly).
- **Shuffled bag:** each category deals every line once before any repeats, and never the same
  line back to back across bags (`RunnerVoice.Pick`).
- **One voice at a time, priority cuts:** `boulder_smash 100 > hit 90 > hop 80 > zip 75 > jump 70
  > bear_down 65 > warning 60 ...`. A lower line never talks over a higher one.
- **Gaps:** ambient categories (coin, reload, duck) have a per-category gap so they stay occasions.
  Hops have a short gap (0.8 s) — every hop is celebrated, but two in one breath don't stack.
- **A wreck that bails the rider (`rider_bailed`) is not a hop**; lane changes within 0.4 s of a
  bail are ignored so he doesn't cheer while his cart explodes.

## Bears

`AudioStreamPlayer3D` per living bear at its ledge (`archer_world_pos`), growls every 2.6–5 s
inside `BEAR_HEAR` (46 m), first sighting gets a roar, dying gets `ep2_bear_fall`. Loudness comes
from Godot's inverse-square attenuation PLUS a distance ramp (`RunnerVoice.bear_db`, quiet at 46 m,
full by 8 m), tested monotone. Bow creak/loose takes exist in the bank for the archer attack cue.

## Jev's part

Jev (`scripts/jev.mjs`) is a decisions model (text only) — use it for the design choices, not the
audio. 2026-09-29 verdicts: danger outranks celebration when they collide within 1 s → **yes (0.89)**;
"celebrate EVERY hop?" → **uncertain (0.50)**, so the gap is short but non-zero rather than sampled.
Its `choice` question wants `criteria` keys that are the OPTIONS (not a wrapper label) — a wrapper
label got picked at 0.98 and told us nothing. Numbers to Jev, listening to the founder.

## Gaps still open

Nobody in this session can hear audio. Judge takes by the founder's ear; if a line reads wrong,
edit the JSON text and regenerate that id (`generate_audio.py --force <id>`).
