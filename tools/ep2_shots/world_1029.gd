extends Node
var out := "docs/episode2-quality/world-voice-music-20261029/cameras"
func cap(name: String) -> void:
 for i in 3: await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out+"/"+name+".png")
 print("CAPTURE ",name)
func _ready() -> void:
 DirAccess.make_dir_recursive_absolute(out)
 var session := Ep2SessionRoot.new()
 add_child(session);session.set_process(false)
 var c: LakeTrailChamber=preload("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 session.add_child(c);session._active=c;session._mode=session.Mode.CHAMBER
 session._wire_chamber(c);c.setup();c.set_physics_process(false);c.debug_invulnerable=true
 session._drive_prebuild(1e9)
 var lake: Node3D=session._pb_node
 for i in 250: c.preview_lake(lake)
 for distance in [200.0,330.0,440.0,c._route_total]:
  c._place_at_distance(distance);c._look_yaw=c._travel_yaw;c._look_pitch=-.04
  c._blend_lake_light();c._update_horse(0);c._update_camera(0)
  await cap("approach_"+str(int(distance)))
 c._first_ambush_said=true
 c._begin_shore()
 for i in 18:c.step(1.0/30.0)
 await cap("shore_before_crossing")
 var arrival: Dictionary=c.get_handoff()
 session.world_routes.park(session,c)
 c._camera.current=false
 lake.activate(session,arrival)
 await cap("actual_lake_arrival")
 session._pb_node=null
 session.queue_free()
 await get_tree().process_frame
 Ep2DrawMusic.finish(self)
 get_tree().quit()
