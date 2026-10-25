---
name: ep2-voice-duck
description: Music must duck under a character's speech for the WHOLE speech and never pump back up between lines. TRIGGER on "the music overrides his speaking", "the music subsided then went up again while he was speaking", "I can't hear the dialogue over the music", or edits to AudioManager.play_voice / _on_voice_finished / the voice-duck constants.
---
# Why (founder 2026-10-04)
"Don't let the music override Inferno's speaking. There were times when while he was speaking the music subsided, but then it went up again while he was speaking. Monitor it and fix it."
Inferno speaks MANY consecutive lines. Each `play_voice` ducked the music and each line's own `finished` restored it to full over 0.5 s - so between every two lines the music rose back up, then ducked again. It pumped audibly through the whole speech. A second cause: when the stage theme LOOPED mid-speech, `_play_next_in_playlist` spawned a fresh player at full volume, blasting over the voice.
# The fix (AudioManager)
- A generation counter `_voice_gen` + a `_voice_ducking` flag. `play_voice` bumps the gen and ducks to `VOICE_DUCK_DB` (-16). `_on_voice_finished` does NOT restore immediately: it waits `VOICE_RESTORE_GRACE` (0.7 s) and only lifts the duck if the gen is unchanged AND nothing is still speaking. A new line bumps the gen, cancelling the pending restore. => the music stays down from the first word to a beat after the LAST line.
- `_play_next_in_playlist` starts a looping track already at `VOICE_DUCK_DB` when `_voice_ducking`, so a loop mid-speech never jumps to full.
- Voice itself is +6 dB on the SFX bus so it sits clearly on top.
# 2026-10-25: one tween owns the music level ("people VO overshadowed by music")
- `_tween_music_to(db, s)` is the ONLY thing that moves `current_music_player.volume_db`; duck, restore and every fade-in (playlist, `play_track_from`,
  override release, `crossfade_music`) kill the previous tween and aim at `_music_rest_db()` (the duck level while someone speaks). Before, a fade-in tween
  created first kept running after the 0.15 s duck and pulled the music back to full over the words (measured -7.6 dB 3.4 s into a line during the forest ->
  town crossfade), and a line starting during the 0.5 s restore was pushed back up the same way.
- Recorded town takes play at `TOWN_TAKE_GAIN_DB` (+2.5): mastered ~-20 LUFS against a -16 LUFS town theme; the loudest take peaks -2.8 dBTP.
- A townsperson's 3D greeting (`Ep2TownSoundscape.greet`) calls `duck_for_speech(len, -10)`; ambient beds (the train) read `is_speech_ducking()` and dip.
- Gate: `tests/ep2_audio_mix_test.tscn` (crossfade under a line, restore re-duck, greeting duck, take gain, the train).
- NOT a bus effect: Godot 4.3 web plays samples through Web Audio, where bus effects are not applied - the duck stays a player volume.

# Gate / monitor
`tests/ep2_voice_duck_test.tscn` plays the theme, fires two lines with a gap, and asserts the music stays <= -10 dB throughout (never rises between lines) and only returns to 0 after the last line + grace. Re-run after any change to the duck.
# Never
Restore the music on a per-line `finished`; spawn a music player at full volume while a voice is active; make the grace shorter than the typical inter-line gap.
