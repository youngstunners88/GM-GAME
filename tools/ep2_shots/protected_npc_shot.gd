extends Node3D
func _ready() -> void:
 var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
 add_child(c)
 c.setup(0, [], 0)
 c.set_physics_process(false)
 c._beat = c.Beat.GEARED
 c._show_active = false
 c._show_blocks_control = false
 c._hold = 0
 var cast: Dictionary = {"dude": c._stable_yard.actors[0], "minister": c._minister, "bartender": c._bartender, "sheriff": c._sheriff, "rich": c._rich, "utah": c._utah, "store_clerk": c._shopkeepers[0][1], "stable_assistant": c._stable_yard.actors[1]}
 DirAccess.make_dir_recursive_absolute("res://.farm/protected-npc")
 for id in cast:
  c._hud.visible = true
  c._hud.fade = 0.0
  c._hud.fade_to(0.0, 0.01)
  var f: Ep2TownFolk = cast[id]
  c._player_pos = f.global_position + Vector3(0,0,-2 if id in ["sheriff", "utah"] else 2)
  var d: Vector3 = f.global_position + Vector3(0,1.2,0) - (c._player_pos + Vector3(0,c.eye_height,0))
  c._look_yaw=atan2(d.x,d.z);c._look_pitch=atan2(d.y,Vector2(d.x,d.z).length())
  c._update_camera(0)
  if not c._law.retaliation.begin(c,id,f): print("CAPTURE_FAIL ",id);continue
  for i in 35: c.step(1.0/60.0)
  for i in 3: await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://.farm/protected-npc/"+id+"_player.png")
  for i in 6: c.step(1.0/60.0)
  c._hud.visible = false
  var cam:=Camera3D.new();add_child(cam);cam.current=true
  cam.global_position = f.global_position + Basis(Vector3.UP,f.rotation.y)*Vector3(2,1.5,2.2)
  cam.look_at(f.global_position+Vector3(0,1.15,0))
  for i in 3: await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://.farm/protected-npc/"+id+"_side.png")
  cam.queue_free();c._camera.current=true
  c._law.retaliation.reset()
  await get_tree().process_frame
 print("RETALIATION_CAPTURE_DONE")
 get_tree().quit()
