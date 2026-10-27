extends Node
var c: LogansLakeChamber
var out := "/workspace/work/logan-cabin/review"
func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("out="):out=arg.substr(4)
 DirAccess.make_dir_recursive_absolute(out)
 c=load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 add_child(c);c.setup();c.set_physics_process(false)
 await get_tree().process_frame
 await shot("01-trail",Vector3(-8,0,-9),Vector3(-21,3,13))
 await shot("02-front",Vector3(-13,0,13),Vector3(-21,2.9,13))
 await shot("03-branding",Vector3(-15.8,1,8.5),Vector3(-19.4,2.35,8.6))
 await shot("04-posters",Vector3(-16.4,1,17.3),Vector3(-19.1,2.35,17.3))
 await shot("05-prospecting",Vector3(-18,1.24,12.4),Vector3(-19.2,2.11,11.05))
 await shot("06-reserves",Vector3(-18.2,1.24,14.1),Vector3(-19.8,1.5,15.23))
 await shot("07-lake-return",Vector3(-13,0,13),Vector3(-2,1.4,10))
 print("CABIN_REVIEW: ALL CAPTURED ready=",c._cabin.ready_art)
 get_tree().quit()
func shot(label: String, feet: Vector3, target: Vector3) -> void:
 c._player_pos=feet
 c._set_ground(Ep2LoganCabin.walk_height(feet)if feet.x<-11.5 else c.path_height(feet.z))
 var d: Vector3=target-c._player_pos-Vector3(0,c.eye_height,0)
 c._look_yaw=atan2(d.x,d.z);c._look_pitch=atan2(d.y,Vector2(d.x,d.z).length())
 for i in 3:c.step(1.0/60)
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
 print("CABIN_CAPTURE ",label)
