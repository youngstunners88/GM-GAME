extends Node
## Gate for the music-vs-voice duck (founder 2026-10-04: "Don't let the music override Inferno's speaking. There
## were times when while he was speaking the music subsided, but then it went up again while he was speaking.
## Monitor it and fix it"). The music must stay DUCKED for a whole multi-line speech and only lift after the last
## line (+ a short grace), never pump back up between lines. Skill ep2-voice-duck.
## Run: godot --headless res://tests/ep2_voice_duck_test.tscn

var _fail: int = 0
func _check(l: String, ok: bool, d: String = "") -> void:
	if ok: print("  [PASS] %s" % l)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [l, d])


func _ready() -> void:
	print("EP2 VOICE DUCK:")
	var am: Node = get_node("/root/AudioManager")
	var theme := "res://src/assets/music/ep2_deep_mining_theme.mp3"
	am.play_track_from(theme, 10.0, 0.0)
	await get_tree().process_frame
	var mp: AudioStreamPlayer = am.current_music_player
	_check("music is playing", mp != null and mp.playing)
	# line 1
	am.play_voice("vo_bull_range_intro")
	await get_tree().create_timer(0.3).timeout
	_check("during a line the music is ducked (%.1f dB)" % mp.volume_db, mp.volume_db <= -10.0)
	_check("the duck flag is set", am._voice_ducking)
	# simulate the line ending, then a SECOND line starting within the grace window
	am._on_voice_finished()
	var gen_after_finish: int = am._voice_gen
	await get_tree().create_timer(0.3).timeout        # less than VOICE_RESTORE_GRACE (0.7)
	_check("between lines (within grace) the music has NOT risen back up (%.1f dB)" % mp.volume_db, mp.volume_db <= -10.0)
	am.play_voice("vo_bull_range_aim")
	_check("a new line bumps the generation (restore is cancelled)", am._voice_gen > gen_after_finish)
	await get_tree().create_timer(0.3).timeout
	_check("still ducked during the second line (%.1f dB)" % mp.volume_db, mp.volume_db <= -10.0 and am._voice_ducking)
	# now let the speech truly end: finish + wait past the grace
	am._on_voice_finished()
	await get_tree().create_timer(1.6).timeout
	_check("after the LAST line (+grace) the music is restored to full (%.1f dB)" % mp.volume_db, mp.volume_db > -3.0)
	_check("the duck flag is cleared", not am._voice_ducking)
	am.fade_out_music(0.01)
	print("EP2_VOICE_DUCK: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)
