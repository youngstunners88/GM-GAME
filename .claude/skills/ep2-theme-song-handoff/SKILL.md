---
name: ep2-theme-song-handoff
description: Make a stage theme continue seamlessly across a film -> gameplay cut (and fade the previous music out before the film). Measure where the song sits inside the film's audio, never guess; use AudioManager.play_track_from. TRIGGER on "the song needs to continue", "music phase out before the video", "seamless music", any change to Ep2VideoFilm.continue_track, FILM_SONG_OFFSET, STAGE_THEME, ep2_session_root._on_cliff_panic_music, or a new founder film that has a song in it.
---
# The founder's rule (Google Doc "Ep 2 video transition", 2026-10-04)
The film carries the stage's main theme from partway in. When the film ends and gameplay begins the theme must CONTINUE from where it lifted off. The mine's runner music must phase out and fade out BEFORE Lil Blunt goes into the film.
# Measure the offset (do not trust "about 3/4 in")
1. Pull the film audio and the song to 16 kHz mono (`ffmpeg -vn -ac 1 -ar 16000`).
2. Chroma (12 pitch classes, 55-2000 Hz) and log-mel features, z-scored; slide a song window over the film audio. Real result for this film: song 0-10 s matches film 26.5 s and song 20-30 s matches film 46.5 s, i.e. **film_time - song_time = 26.53 s** (both windows agree). Plain RMS envelope correlation is useless here (0.04); the film audio also carries effects.
3. Song position at film end = film_length - offset (60.83 - 26.53 = 34.3 s). The founder said the song starts "about 3/4 in" (45.6 s); the measurement says 26.5 s (44%). If he disagrees, change ONE constant: `SmeltingFacilityChamber.FILM_SONG_OFFSET`.
# How it is wired
- `AudioManager.play_track_from(path, position, fade_in)`: hard-stops music, starts the track at `position`, tiny fade-in, loops after. Test proves position within 1 s.
- `Ep2VideoFilm.continue_track` + `song_video_offset`: on finish OR skip it starts the theme at `max(video_stream_position - offset, 0)` (a skip before the song starts begins it from 0). Music bus is unmuted first.
- `Ep2SessionRoot._on_cliff_panic_music`: panic level 2 (~90 m, ~3.5 s before the mouth) -> `AudioManager.fade_out_music(3.0)`, once per run.
- The same theme file is the Episode 2 stage music afterwards (loops). It is in `TransitionDirector.PRESETS` so it is cached before the cut.
# Never
Start the theme from 0 after the film; layer the theme under the film's own copy (the Music bus is muted while it plays); let two songs overlap at the cut; claim "seamless" without `tests/ep2_theme_handoff_test.tscn` green. Web caveat: a main-thread stall (the first draw of Episode 2) can still gap audio for a moment.
