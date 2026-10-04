extends Node
## Gate for the founder's Episode 2 film + stage theme hand-off (skill ep2-theme-song-handoff, 2026-10-04):
## the runner music phases out before the film, the film carries the theme, and the game CONTINUES the theme from
## the matching position (never restarting, never jumping).
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_theme_handoff_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	print("EP2 THEME HANDOFF:")
	var F = SmeltingFacilityChamber
	_check("the founder's film is in the build", ResourceLoader.exists(F.FILM_VIDEO))
	_check("the stage theme is in the build", ResourceLoader.exists(F.STAGE_THEME))
	var theme: AudioStream = load(F.STAGE_THEME)
	_check("the theme is a real, long track (%.0f s)" % theme.get_length(), theme != null and theme.get_length() > 120.0)
	_check("the film constant matches the 60.8 s file", absf(F.FILM_SECONDS - 60.9) < 0.2)

	var am: Node = get_node("/root/AudioManager")
	# 1. play_track_from continues at the given position.
	am.play_track_from(F.STAGE_THEME, 34.3, 0.0)
	await get_tree().process_frame
	var pl: AudioStreamPlayer = am.current_music_player
	_check("play_track_from starts the theme", pl != null and pl.playing)
	var pos: float = pl.get_playback_position() if pl else -1.0
	_check("...at the requested position (34.3 s, got %.2f)" % pos, pos > 33.5 and pos < 36.5)
	_check("...on the Music bus", pl != null and pl.bus == "Music")

	# 2. The film hands the theme over at the right position when it ends (natural end).
	am.fade_out_music(0.01)
	await get_tree().create_timer(0.2).timeout
	var vf := Ep2VideoFilm.new()
	vf.continue_track = F.STAGE_THEME
	vf.song_video_offset = F.FILM_SONG_OFFSET
	add_child(vf)
	vf._continue_song(60.83)
	await get_tree().process_frame
	pl = am.current_music_player
	pos = pl.get_playback_position() if pl else -1.0
	_check("film end (60.83 s) continues the theme at ~34.3 s (got %.2f)" % pos, pl != null and pos > 33.5 and pos < 36.5)
	# 3. Skipping before the song starts in the film starts the theme from 0, never negative.
	vf._continue_song(10.0)
	await get_tree().process_frame
	pl = am.current_music_player
	pos = pl.get_playback_position() if pl else -1.0
	_check("a skip before the song begins starts it from the top (got %.2f)" % pos, pl != null and pos >= 0.0 and pos < 2.0)
	vf.queue_free()

	# 4. The runner music phases out before the film.
	var sr: Node = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(sr)
	await get_tree().process_frame
	am.play_playlist([F.STAGE_THEME], true, 0.1)
	sr._on_cliff_panic_music(1)
	_check("panic level 1 does NOT fade the music yet", not am._playlist.is_empty())
	sr._on_cliff_panic_music(2)
	_check("panic level 2 (~90 m, ~3.5 s before the mouth) fades the runner music out", am._playlist.is_empty())
	sr.queue_free()
	am.fade_out_music(0.01)

	print("EP2_THEME_HANDOFF: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)
