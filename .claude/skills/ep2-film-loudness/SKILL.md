---
name: ep2-film-loudness
description: Make a founder film loud enough without clipping or breaking the song hand-off - measure momentary loudness per second, ride the quiet dialogue up, leave the music section untouched, remux into the .ogv without re-encoding the picture. TRIGGER on "make the video louder", "I can't hear them talking", "the film is quiet", any new founder film, or a change to ep2_cliff_to_hideout.ogv.
---
# Measure first (2026-10-04)
`ffmpeg -i f.ogv -vn -af ebur128=peak=true -f null -` per second. The founder film was -16 LUFS overall and peaked at 0 dBFS, so a plain gain boost clips. The truth was in the profile: seconds 6-25 (the dialogue) sat at -25..-35 LUFS while the music and effects sat at -13..-17. Loud overall, inaudible where the talking is.
# Fix = a gain RIDE, not a boost (`tools/ep2_audio/loudify_film.py in.wav out.wav`)
100 ms level steps, gain = target(-12 LUFS) - level clamped to [0, +20 dB], fast attack / slow release smoothing, gated below -50 LUFS (do not ride room tone), applied only before `SONG_START` 25 s and faded to zero by 27 s so the stage theme keeps its exact level and character (the game continues that theme from the same position: skill ep2-theme-song-handoff), then `alimiter=limit=0.8` as the ceiling.
Result: dialogue +13 dB (now -13..-18 LUFS), integrated -16.0 -> -13.1 LUFS, no clipping.
# Remux without touching the picture
`ffmpeg -i old.ogv -i loud.wav -map 0:v -map 1:a -c:v copy -c:a libvorbis -q:a 4 -shortest new.ogv`; duration must stay 60.83 s (the song offset 26.53 s depends on it). Size +60 KB. Run `godot --headless --import` and `tests/ep2_hideout_corrections_test.tscn`.
# Never
Boost the whole file; touch the music section; re-encode the video (pck gate 190 MB); change the length by even a frame.
