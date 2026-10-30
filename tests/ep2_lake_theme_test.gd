extends Node
var checks := 0
var failed := 0
func check(label: String,ok: bool) -> void:
	checks+=1
	if not ok:failed+=1
	print("[PASS] "+label if ok else "[FAIL] "+label)
func _ready() -> void:
	Ep2DrawMusic.finish_lake(self)
	Ep2DrawMusic.finish(self)
	AudioManager.play_room_music("res://src/assets/music/menu_mist_theme.mp3",.01)
	await get_tree().create_timer(.1).timeout
	var base: AudioStream=AudioManager.current_music_player.stream
	Ep2DrawMusic.begin(self)
	check("draw/ride still use the previously supplied recording",AudioManager._override_player.stream.resource_path==Ep2DrawMusic.TRACK)
	Ep2DrawMusic.begin_lake(self)
	check("arrival starts the supplied GM Laker2 recording",AudioManager._override_player.stream.resource_path==Ep2DrawMusic.LAKE_TRACK)
	check("the full supplied stereo track is loaded",AudioManager._override_player.stream is AudioStreamMP3 and absf(AudioManager._override_player.stream.get_length()-187.632)<.1)
	check("lake music loops on the existing Music bus",AudioManager._override_player.stream.loop and AudioManager._override_player.bus==&"Music")
	check("ride ownership is released when lake music starts",Ep2DrawMusic.token<0 and Ep2DrawMusic.lake_token>=0)
	await get_tree().create_timer(.8).timeout
	check("the old ride fade cannot stop the new lake song",AudioManager._override_active and AudioManager._override_player.stream.resource_path==Ep2DrawMusic.LAKE_TRACK)
	Ep2DrawMusic.begin(self)
	await get_tree().create_timer(.8).timeout
	check("riding back restores the ride recording and releases lake ownership",Ep2DrawMusic.lake_token<0 and AudioManager._override_player.stream.resource_path==Ep2DrawMusic.TRACK)
	Ep2DrawMusic.finish(self)
	await get_tree().create_timer(.8).timeout
	check("leaving the special tracks resumes the actual previous music",not AudioManager._override_active and AudioManager.current_music_player.stream==base and not AudioManager.current_music_player.stream_paused)
	print("EP2_LAKE_THEME: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
