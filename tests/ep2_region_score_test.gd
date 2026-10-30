extends Node
var failed:=0
var checks:=0
func check(label:String,ok:bool)->void:
 checks+=1
 if not ok:failed+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _ready()->void:
 var am=get_node("/root/AudioManager")
 var a=WoodsQuadChamber.TOWN_MUSIC
 var b=Ep2DrawMusic.TOWN_TRACK
 am.play_track_from(a,0,0)
 var first=am.current_music_player
 am.play_region_score([a,b],1.0)
 check("enter town keeps the running main theme",am.current_music_player==first and am._region_tracks==[a,b])
 first.seek(first.stream.get_length()-.8)
 am._process(0)
 var second=am.current_music_player
 check("natural tail starts the supplied alternate",second!=first and am._last_track==b and am._retiring.has(first))
 first.finished.emit()
 check("outgoing EOF cannot stop incoming deck",am.current_music_player==second and is_instance_valid(second))
 await get_tree().create_timer(.45).timeout
 var power=pow(db_to_linear(first.volume_db),2)+pow(db_to_linear(second.volume_db),2)
 check("overlap has no midpoint silence hole",power>.7 and power<1.3)
 await get_tree().create_timer(.7).timeout
 am.advance_region_score()
 check("the alternate returns to main theme",am._last_track==a and am._region_tracks==[a,b])
 am._on_music_track_finished()
 check("a suspended-tab EOF still advances the town rotation",am._last_track==b)
 var token=am.push_music_override(Ep2DrawMusic.TRACK)
 var draw=am._override_player
 am.play_region_score([Ep2DrawMusic.LAKE_TRACK],1.0)
 check("a region mix retains audible override as outgoing deck",not am._override_active and am._retiring.has(draw))
 var lake=am.current_music_player
 am.release_music_override(token)
 check("stale override release cannot interrupt lake mix",am.current_music_player==lake)
 am.play_region_score([Ep2DrawMusic.LAKE_TRACK],1.0)
 check("lake setup keeps the approach song position",am.current_music_player==lake)
 am.play_playlist([a],true)
 check("leaving region cancels town rotation",am._region_tracks.is_empty())
 check("founder supplied song is nonempty",(load(b) as AudioStream).get_length()>140)
 print("EP2_REGION_SCORE: ",checks," checks, ",failed," failed")
 get_tree().quit(failed)
