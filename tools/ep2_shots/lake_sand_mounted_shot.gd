extends Node
## Founder 2026-11-22 (images 1 and 3, "sand on the green trail", a repeat): the REAL ride, with the visited town adopted into the trail
## (adopt_departure) as it is when he mounts in town. lake_sand_shot builds the trail alone and never saw the town's desert floor ride along.
## Frames along the last 700 m before and after the lake room is copied in, looking down the road like the founder's shots.
func _ready()->void:
 var out:String=OS.get_environment("SHOT_OUT")
 for a in OS.get_cmdline_user_args():
  if a.begins_with("out="):out=a.substr(4)
 if out=="":out="user://lake_sand_mounted"
 DirAccess.make_dir_recursive_absolute(out)
 var session=load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
 add_child(session)
 session.set_process(false)
 session.armory=Ep2ArmoryState.post_hideout()
 var town:GoldTownChamber=load("res://src/episode2/chamber/gold_town.tscn").instantiate()
 add_child(town)
 town.setup()
 town.set_physics_process(false)
 var trail=load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 session.add_child(trail)
 session._active=trail
 session._wire_chamber(trail)
 trail.setup()
 trail.set_physics_process(false)
 trail.adopt_departure(town)
 session._drive_prebuild(1e9)
 var lake=session._pb_node
 for pass_name in ["before","after"]:
  if pass_name=="after":
   for i in 200:trail.preview_lake(lake)
  for distance in [420.,300.,200.,140.,90.,40.]:
   trail._place_at_distance(trail._route_total-distance)
   trail._look_yaw=trail._travel_yaw
   trail._look_pitch=-.10
   trail._blend_lake_light()
   trail._update_camera(0)
   trail._sync_visuals()
   for i in 4:await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png(out+"/%s-%d.png"%[pass_name,int(distance)])
 print("LAKE_SAND_MOUNTED_DONE ",ProjectSettings.globalize_path(out))
 get_tree().quit()
