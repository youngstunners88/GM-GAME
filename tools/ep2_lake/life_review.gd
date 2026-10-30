extends Node
var c: LogansLakeChamber
var out := "/workspace/work/lake-life/views"
var cam: Camera3D
func _ready() -> void:
 DirAccess.make_dir_recursive_absolute(out)
 c=load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 add_child(c);c.setup();c.set_physics_process(false)
 await get_tree().process_frame
 await shot("01-moored",false)
 c._player_pos=Vector3(-5.5,0,8);c.start_rig()
 advance(20)
 c._player_pos=Vector3(-6,0,17);c.start_rig()
 advance(8.6)
 for spec in [[2.5,"02-walk-bank"],[5.5,"03-walk-dock"],[4.0,"04-boarding"],[2.0,"05-seated"]]:
  advance(float(spec[0]));await shot(str(spec[1]),false)
 # Close-up diagnostic camera follows the actual boat, preserving all world light.
 cam=Camera3D.new();add_child(cam);cam.current=true;cam.fov=52
 advance(23)
 for i in range(3):
  advance(2)
  cam.global_position=c._skiff.boat.global_position+c._skiff.boat.global_basis*Vector3(-3.1,1.8,-2.7)
  cam.look_at(c._skiff._seat.global_position+Vector3(0,.42,0))
  await shot("fish-%02d"%i,true)
 var chart := preload("res://src/episode2/ui/region_map.gd").new()
 chart.context=func() -> Vector2:return Vector2(.64,.38)
 chart.allowed=func() -> bool:return true
 add_child(chart)
 GameManager.has_region_map=true
 chart.toggle()
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join("map-icon.png"))
 chart.toggle();chart.queue_free();c.queue_free();await get_tree().process_frame
 var trail := LakeTrailChamber.new();add_child(trail);trail.setup();trail.set_physics_process(false)
 trail._place_at_distance(100)
 var flock: Node3D=trail._visuals.get_node("CirclingVultures")
 var toward: Vector3=flock.global_position+Vector3(0,29,0)-trail.get_camera().global_position
 trail._look_yaw=atan2(toward.x,toward.z);trail._look_pitch=atan2(toward.y,Vector2(toward.x,toward.z).length())
 trail._update_camera(0)
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join("trail-vultures.png"))
 print("LAKE_LIFE_REVIEW_DONE")
 get_tree().quit()
func advance(seconds: float) -> void:
 for i in int(seconds*60):c.step(1.0/60.0)
func shot(label: String,close: bool) -> void:
 if not close:
  c._player_pos=Vector3(2.9,0,10.25)
  var target: Vector3=c._skiff._seat.global_position+Vector3(0,.5,0)
  if c._skiff.state==c._skiff.State.WALK_TO_BOAT:
   c._player_pos=Vector3(-1.2,0,9.0)
   target=c._logan.global_position+Vector3(0,.9,0)
  var d: Vector3=target-c._player_pos-Vector3(0,c.eye_height,0)
  c._look_yaw=atan2(d.x,d.z);c._look_pitch=atan2(d.y,Vector2(d.x,d.z).length())
 c.step(0.0)
 if close:
  c.get_viewmodel().set_shown(false)
  for child in c.get_camera().get_children():
   if child is Node3D: child.hide()
  c._hud_layer.hide()
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
 print("SKIFF_CAPTURE ",label," state=",c._skiff.state," t=",c._skiff._time," phase=",c._skiff.stroke_phase)
