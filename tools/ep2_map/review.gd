extends Node
var out := "/workspace/work/pause-key/views"
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 DirAccess.make_dir_recursive_absolute(out)
 StateMachine.change_state(StateMachine.State.TRANSITIONING)
 StateMachine.change_state(StateMachine.State.PLAYING)
 var town := GoldTownChamber.new()
 add_child(town);town.setup()
 town._horse_bought=true
 town._advance_to(town.Beat.GEARED)
 town._player_pos=GoldTownChamber.DEPART_HORSE+Vector3(2,0,0)
 town._look_yaw=-PI*.5;town._look_pitch=-.1
 town._update_camera(0)
 var chart := preload("res://src/episode2/ui/region_map.gd").new()
 chart.allowed=func() -> bool: return StateMachine.is_playing()
 chart.context=func() -> Vector2: return Vector2(.23,.42)
 add_child(chart)
 GameManager.has_region_map=true;GameManager.map_active_destination="logans_lake"
 await shot("01-stables-map-corner")
 chart.toggle()
 await shot("02-western-map")
 chart.toggle()
 town.start_rig("")
 for i in 6:town.step(.1)
 await shot("03-mount-midpoint")
 town.queue_free();await get_tree().process_frame
 var trail := LakeTrailChamber.new()
 add_child(trail);trail.setup()
 await shot("04-trail-stables-start")
 for i in 90:trail.step(.1)
 await shot("05-ranch-exit")
 print("MAP_REVIEW: DONE");get_tree().quit()
func shot(label: String) -> void:
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
