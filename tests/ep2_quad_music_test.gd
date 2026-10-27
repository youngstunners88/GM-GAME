extends Node
## EP2 QUAD MUSIC (founder 2026-10-27: "The music from the Quad bike ride in the forest to exiting changes to drastically. And it
## also changes too soon."). The forest -> town crossfade is equal-power: the outgoing and incoming tracks together hold one
## loudness the whole way (the old linear-dB ramps sank both ~25 dB at the midpoint), it still sits under a line that starts
## mid-blend, and the woods start it only once the quad is out of the trees.
## Run: godot --headless res://tests/ep2_quad_music_test.tscn

var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	print("EP2 QUAD MUSIC:")
	var am: Node = get_node("/root/AudioManager")
	var forest := WoodsQuadChamber.MUSIC
	var theme := "res://src/assets/music/ep2_deep_mining_theme.mp3"   # always in the main pack; the town theme streams
	am.play_track_from(forest, 0.0, 0.0)
	await get_tree().process_frame
	var old: AudioStreamPlayer = am.current_music_player
	am.crossfade_music(theme, 2.0)
	var fresh: AudioStreamPlayer = am.current_music_player
	check("the crossfade starts a new player and keeps the old one fading", fresh != null and fresh != old and is_instance_valid(old))
	var lowest: float = 9.0
	var highest: float = 0.0
	for i in 19:
		await _wait(0.1)
		var a_old: float = db_to_linear(old.volume_db) if is_instance_valid(old) else 0.0
		var a_new: float = db_to_linear(fresh.volume_db)
		var power: float = a_old * a_old + a_new * a_new
		lowest = minf(lowest, power)
		highest = maxf(highest, power)
	check("the blend holds one loudness: combined power never sinks below -1.5 dB nor rises above +0.5 dB",
		lowest >= db_to_linear(-1.5) and highest <= db_to_linear(0.5), "power %.2f..%.2f" % [lowest, highest])
	await _wait(0.4)
	check("the new track ends at full level and the old one is gone", fresh.volume_db > -0.5 and not is_instance_valid(old), "%.1f dB" % fresh.volume_db)
	# a line that starts mid-blend keeps the incoming music under it
	am.crossfade_music(forest, 3.0)
	var back: AudioStreamPlayer = am.current_music_player
	am.play_voice("vo_bull_plan1")
	await _wait(2.4)
	check("a line that starts mid-blend holds the incoming track down", back.volume_db <= -10.0, "%.1f dB" % back.volume_db)
	am._on_voice_finished()
	await _wait(AudioManager.VOICE_RESTORE_GRACE + 1.2)
	check("...and the music comes back up after it", back.volume_db > -3.0 and not am.is_speech_ducking(), "%.1f dB" % back.volume_db)
	# a second music change mid-blend takes over cleanly (the blend stops writing to a player it no longer owns)
	am.crossfade_music(theme, 3.0)
	var abandoned: AudioStreamPlayer = am.current_music_player
	await _wait(0.5)
	am.play_room_music(forest, 0.5)
	await _wait(1.2)
	check("a new song mid-blend fades the abandoned blend out instead of fighting it", not is_instance_valid(abandoned) or abandoned.volume_db <= -30.0)
	# the woods start the blend only out of the trees
	check("the woods start the town theme past the last pines, not as they thin",
		WoodsQuadChamber.TOWN_MUSIC_AFTER_TREES > 0.0 and WoodsQuadChamber.TOWN_MUSIC_FADE >= 10.0)
	print("EP2_QUAD_MUSIC: ", "ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	get_tree().quit(failures)
