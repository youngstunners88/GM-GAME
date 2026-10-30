extends Node
func _ready()->void:
 var am=get_node("/root/AudioManager")
 var record=AudioEffectRecord.new()
 var bus=AudioServer.get_bus_index("Music")
 AudioServer.add_bus_effect(bus,record)
 record.set_recording_active(true)
 am.play_track_from(WoodsQuadChamber.TOWN_MUSIC,30,0)
 await get_tree().create_timer(2).timeout
 am.play_region_score([Ep2DrawMusic.TOWN_TRACK],8)
 await get_tree().create_timer(10).timeout
 am.play_region_score([Ep2DrawMusic.TRACK],8)
 await get_tree().create_timer(10).timeout
 am.play_region_score([Ep2DrawMusic.LAKE_TRACK],8)
 await get_tree().create_timer(10).timeout
 record.set_recording_active(false)
 var wav=record.get_recording()
 var path="/workspace/work/town-lake-1031/engine-region-mixes.wav"
 var error=wav.save_to_wav(path)
 print("REGION_MIX_RECORD ",error," bytes ",wav.data.size())
 AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 get_tree().quit(error)
