extends Node
func _ready()->void:
 var session=load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
 add_child(session)
 session.set_process(false)
 session.armory=Ep2ArmoryState.post_hideout()
 var trail=load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 session.add_child(trail)
 session._active=trail
 session._wire_chamber(trail)
 trail.setup()
 trail.set_physics_process(false)
 session._drive_prebuild(1e9)
 var lake=session._pb_node
 for i in 200:trail.preview_lake(lake)
 var out="/workspace/work/town-lake-1031/views"
 DirAccess.make_dir_recursive_absolute(out)
 for distance in [80.,45.,15.,0.]:
  trail._place_at_distance(trail._route_total-distance)
  trail._look_yaw=trail._travel_yaw
  trail._look_pitch=-.025
  trail._blend_lake_light()
  trail._update_camera(0)
  trail._sync_visuals()
  for i in 4:await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(out+"/approach-%d.png"%int(distance))
  print("LAKE_APPROACH ",distance," previewLogan=",trail._lake_preview.has_node("Logan"))
 print("LAKE_APPROACH_DONE")
 get_tree().quit()
