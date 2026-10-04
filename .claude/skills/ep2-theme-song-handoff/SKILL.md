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
# Read the position BEFORE stopping the video (the 2026-10-04 "it starts again" bug)
`VideoStreamPlayer.stop()` rewinds the Theora clock to 0. The first version read `stream_position` AFTER `stop()`,
got 0 every time, and restarted the theme from bar one even though the offset was right. `Ep2VideoFilm._finish()`
now reads `film_end_position()` first (decoder clock; falls back to the wall clock `_t`, capped at the film length,
when the decoder reports < 0.25 s), then stops. `last_song_position` records the hand-off for tests and rigs.
Regression gate: `tests/ep2_hideout_corrections_test.tscn` drives the REAL finish path (start, play 1.2 s, skip with
offset 0 -> song must be at ~1.2 s, not 0). A test that calls `_continue_song()` directly can never catch this.
# Verify the offset at sample level (done 2026-10-04)
Raw-waveform normalised cross-correlation of 3 s film windows against the whole song (`scipy.signal.correlate`,
16 kHz): every window from film 28 s to 59.5 s lands on the same offset, **26.531 s**, rising to ncc 0.99 at the
film's last second (song fully exposed, dialogue gone). Chroma said 26.53 too. The founder's "3/4 in" is wrong; the
offset is not the problem when he hears a restart - look for a position read after a stop/rewind, or a second
music call (grep `play_playlist|play_music|play_track_from` in src/episode2 + the session root).
# How it is wired
- `AudioManager.play_track_from(path, position, fade_in)`: hard-stops music, starts the track at `position`, tiny fade-in, loops after. Test proves position within 1 s.
- `Ep2VideoFilm.continue_track` + `song_video_offset`: on finish OR skip it starts the theme at `max(film_end_position() - offset, 0)`, position read before `stop()` (a skip before the song starts begins it from 0). Music bus is unmuted first.
- `Ep2SessionRoot._on_cliff_panic_music`: panic level 2 (~90 m, ~3.5 s before the mouth) -> `AudioManager.fade_out_music(3.0)`, once per run.
- The same theme file is the Episode 2 stage music afterwards (loops). It is in `TransitionDirector.PRESETS` so it is cached before the cut.
# Never
Start the theme from 0 after the film; layer the theme under the film's own copy (the Music bus is muted while it plays); let two songs overlap at the cut; claim "seamless" without `tests/ep2_theme_handoff_test.tscn` green. Web caveat: a main-thread stall (the first draw of Episode 2) can still gap audio for a moment.
