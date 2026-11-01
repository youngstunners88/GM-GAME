---
name: ep2-speech-no-subtitles
description: Episode 2 character dialogue is heard, not subtitled (founder 2026-11-01 "remove the subtitles" + "awkward delay"). One pacing rule (Ep2Speech) and one HUD entry (Ep2FpsHud.speech). TRIGGER on any new spoken line, caption, toast with a speaker name, conversation timing, "awkward delay", "dead air", or a request to bring subtitles back.
---

# Speech without subtitles

- **Pacing**: `Ep2Speech.pace(id, text)` = the recorded take + `GAP` (0.12 s). Only a line whose take is missing uses a reading
  time. The old rule `max(reading time, take + 0.55 s)` was the founder's "awkward delay".
- **Display**: `_hud.speech("WHO: words", seconds, Ep2Speech.voiced(id))`. Voiced -> logged in `speech_log`, nothing drawn.
  Unvoiced (no take authored, or the streamed voice pack failed) -> the old toast, so a failed download is never silent.
- Call sites converted: town `_town_line`, `_jail_line`, `_caption_line`/`_caption_seconds`, `_on_stable_line` (town + woods),
  stable yard `_line_seconds`, the Armory intro (`voice_seconds`), the trail's `_say_trail_line`, Logan's `_say` (his box only
  shows unvoiced narration).
- New dialogue must go through these two functions. Never add a `toast("WHO: ...")` for a voiced line.
- Input lock: scripted shows still hold control while a line plays; with pacing at take + 0.12 s the hold ends as the voice does.
