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
	check("arrival starts the supplied GM Laker2 recording",AudioManager.current_music_player.stream.resource_path==Ep2DrawMusic.LAKE_TRACK)
	check("the full supplied stereo track is loaded",AudioManager.current_music_player.stream is AudioStreamMP3 and absf(AudioManager.current_music_player.stream.get_length()-187.632)<.1)
	check("lake music loops on the existing Music bus",AudioManager._region_tracks==[Ep2DrawMusic.LAKE_TRACK] and AudioManager.current_music_player.bus==&"Music")
	check("ride ownership is released when lake music starts",Ep2DrawMusic.token<0 and Ep2DrawMusic.lake_token>=0)
	await get_tree().create_timer(.8).timeout
	check("the old ride fade cannot stop the new lake song",not AudioManager._override_active and AudioManager.current_music_player.stream.resource_path==Ep2DrawMusic.LAKE_TRACK)
	Ep2DrawMusic.begin_trail(self)
	await get_tree().create_timer(.8).timeout
	check("riding back restores the ride recording and releases lake ownership",Ep2DrawMusic.lake_token<0 and AudioManager.current_music_player.stream.resource_path==Ep2DrawMusic.TRACK)
	Ep2DrawMusic.begin_town(self)
	await get_tree().create_timer(.8).timeout
	check("returning to town restores both beds without a stale menu song",not AudioManager._override_active and AudioManager.current_music_player.stream!=base and AudioManager._region_tracks==[WoodsQuadChamber.TOWN_MUSIC,Ep2DrawMusic.TOWN_TRACK])
	print("EP2_LAKE_THEME: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
