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
