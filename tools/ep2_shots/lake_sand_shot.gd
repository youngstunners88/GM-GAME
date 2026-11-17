extends Node
## Founder 2026-11-17: no desert sand around the lake that vanishes on arrival, no desert glitch on the road in.
## Frames along the last 700 m of the trail, before and after the lake room is copied in, then the lake room itself.
func _ready()->void:
 var out:String=OS.get_environment("SHOT_OUT")
 if out=="":out="user://lake_sand"
 DirAccess.make_dir_recursive_absolute(out)
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
 for pass_name in ["before","after"]:
  if pass_name=="after":
   for i in 200:trail.preview_lake(lake)
  for distance in [700.,420.,260.,140.,40.]:
   trail._place_at_distance(trail._route_total-distance)
   trail._look_yaw=trail._travel_yaw
   trail._look_pitch=-.06
   trail._blend_lake_light()
   trail._update_camera(0)
   trail._sync_visuals()
   for i in 4:await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png(out+"/%s-%d.png"%[pass_name,int(distance)])
  # looking back over the shoulder from near the shore: what surrounds the lake on the desert side
  trail._place_at_distance(trail._route_total-30.)
  trail._look_yaw=trail._travel_yaw+PI*0.75
  trail._update_camera(0);trail._sync_visuals()
  for i in 4:await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(out+"/%s-side.png"%pass_name)
 print("LAKE_SAND_DONE ",ProjectSettings.globalize_path(out))
 get_tree().quit()
