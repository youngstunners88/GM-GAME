---
name: gm-game-portal-voice
description: ElevenLabs voice for the three governors (Pauly the Smokest, Kane the Blaze Mechanic, Rich the Miner) reading every stop aspect. TRIGGER when governor dialogue is added/changed, a voice ID is mentioned, or clips are missing/robotic.
---

# Portal governor voice

- Voices: Pauly `h5iQzu1FcYr7bBjBGL1i` (Smoke), Kane `6v1vvHruJAwMrJgRpd5c` (Diamonds), Rich `LNV6ahDtkAOqwn1X3R7a` (Gold).
  IDs are not secrets. They belong to the FOUNDER's account: the env var **`ELEVENLABS_API`** works, while
  `ELEVENLABS_API_KEY` returns `voice_not_found` (400/404). Never print either key.
- `python3 scripts/gen_portal_vo.py [--force]` writes `src/assets/portals/vo/<protocol>_<stop>_<n>.mp3`
  (mp3_44100_64, ~100 KB each, 50 clips ~5 MB) for every aspect, skipping existing files. Change text -> `--force`.
- Playback: `StudyRoom._on_stop_reached` -> `Companion.play_voice(path)`; silent if a clip is missing.
- Keep the pack under the 190 MB gate; do not switch to higher bitrates.

## Loudness (founder 2026-09-30: "drowned by the music")
`Companion.play_voice` plays at +10 dB (`VOICE_GAIN_DB`) and ducks the **Music bus** by 14 dB while a clip plays,
restoring it after (and in `_exit_tree`). Tune those two constants, not the mp3s.

## Update 2026-09-30
- **No music ducking** (founder: "I didn't ask for that"). Clips are loudness-normalised to -14 LUFS by
  `gen_portal_vo.py` (ffmpeg loudnorm) and played at +8 dB; the music is never touched.
- Gold voice requested: `faxBRsvZBmi6q2wL3MQs`. It returns `voice_not_found` on both env keys, so it must be
  added to the account first (ElevenLabs Voice Library -> Add to My Voices); until then Gold uses Rich Miner `LNV6...`.
  `python3 scripts/gen_portal_vo.py --force --only gold` after swapping the ID.
- Room titles were removed from all three rooms (they masked stop labels). Characters were enlarged
  (`PortalExplorer.PLAYER_H` 104, `Companion.DISPLAY_H` 158) to match the props.

## Greetings and goodbyes (founder 2026-09-30)
`portal_copy.json` -> `<protocol>.welcome` / `.farewell` = `{gov, lb}`. `StudyRoom._converse(phase)` plays the governor
line then Lil Blunt's reply (voice `HMGfKwZCRujgXyRDUW0b`) via `Companion.speak()`: welcome on arrival, farewell when
leaving (`_do_ascend` awaits it, player frozen, then `Travel.ascend()`). Clips: `vo/<protocol>_<welcome|farewell>_<gov|lb>.mp3`
(made by `gen_portal_vo.py`).

## Gold pace (founder: "he speaks very slow")
Rich Miner (Storytellin' Cowboy) drawls. `TEMPO = {"gold": 1.3}` in `gen_portal_vo.py` speeds Gold governor clips with
ffmpeg `atempo` (pitch preserved) before loudnorm. The requested voice `faxBRsvZBmi6q2wL3MQs` is still not visible to
either env key nor in the shared library, so it must be added to the account by the founder first.
