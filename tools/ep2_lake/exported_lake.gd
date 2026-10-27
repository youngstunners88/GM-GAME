extends SceneTree
## External fixture for exact exported packs. No shipped URL/access bypass.
var c
var capture_path: String=""
var failures: int=0
func check(label: String,ok: bool) -> void:
 print("[PASS] "+label if ok else "[FAIL] "+label)
 if not ok:failures+=1
func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()<1 or not ProjectSettings.load_resource_pack(args[0],false):
  quit(1);return
 if args.size()>1:capture_path=args[1]
 call_deferred("run")
func advance(seconds: float) -> void:
 for i in int(seconds*60):c.step(1.0/60.0)
func walk(target: Vector3) -> bool:
 for i in 3600:
  var d: Vector3=target-c.get_player_position()
  if Vector2(d.x,d.z).length()<.35:
   c.set_move_input(Vector2.ZERO);return true
  c._look_yaw=atan2(d.x,d.z);c.set_move_input(Vector2(0,1));c.step(1.0/60.0)
 return false
func drawn_ground(c, p: Vector3) -> float:
 var ground:=c._visuals.get_node("ShoreAndMountain") as MeshInstance3D
 var arrays:=ground.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in range(0,indices.size(),3):
  var a: Vector3=ground.to_global(vertices[indices[i]])
  var b: Vector3=ground.to_global(vertices[indices[i+1]])
  var d: Vector3=ground.to_global(vertices[indices[i+2]])
  if p.x<minf(a.x,minf(b.x,d.x)) or p.x>maxf(a.x,maxf(b.x,d.x)) or p.z<minf(a.z,minf(b.z,d.z)) or p.z>maxf(a.z,maxf(b.z,d.z)):continue
  var hit=Geometry3D.segment_intersects_triangle(p+Vector3(0,20,0),p-Vector3(0,10,0),a,b,d)
  if hit!=null:return hit.y
 return INF
func run() -> void:
 c=load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 root.add_child(c);c.setup();c.set_physics_process(false)
 await process_frame
 var inventory: Dictionary=c.armory.snapshot().duplicate(true)
 check("packed forest upgrades",c._landscape.upgraded and c._landscape.tree_instances>=90)
 check("actual exported bank supports Logan",absf(drawn_ground(c,c.LOGAN_MARK)-c._logan.position.y)<.025)
 check("ordinary walk reaches founder Logan",walk(Vector3(-5.5,0,8)))
 check("ordinary interact starts investigation",c.start_rig())
 advance(20)
 check("ordinary walk reaches cargo",walk(Vector3(-6,0,17)))
 c._hud.search_requested.emit()
 check("touch stages exactly once",c.staging_complete() and c.staging_count()==1 and not c.start_rig())
 advance(8.4)
 check("Logan waits through handoff",c._skiff.state==c._skiff.State.MOORED)
 advance(15)
 check("packed skiff boards and rows",c._skiff.ready_art and c._skiff.state==c._skiff.State.ROW and c._skiff.circuit_distance>0)
 var max_contact: float=0
 var max_seat: float=0
 for i in 162:
  c.step(1.0/30.0)
  max_seat=maxf(max_seat,c._skiff.seat_error())
  for side in ["Left","Right"]:
   var n: int=0 if side=="Left" else 1
   max_contact=maxf(max_contact,c._skiff.palm_position(side).distance_to(c._skiff.grips[n].global_position))
 check("downloaded palms/seat survive two whole strokes",max_contact<.015 and max_seat<.01)
 check("inventory remains unchanged",c.armory.snapshot()==inventory)
 if capture_path!="":
  c._player_pos=Vector3(2.9,0,10.25)
  var d: Vector3=c._skiff._seat.global_position+Vector3(0,.5,0)-c._player_pos-Vector3(0,c.eye_height,0)
  c._look_yaw=atan2(d.x,d.z);c._look_pitch=atan2(d.y,Vector2(d.x,d.z).length());c.step(0)
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(capture_path)
 check("ordinary movement reaches overlook",walk(c.OVERLOOK))
 check("lake preserves high overlook/outflow",c.river_ready() and c.get_player_position().y>5.5)
 print("EXPORTED_LAKE: ALL PASS" if failures==0 else "EXPORTED_LAKE: FAILED "+str(failures))
 c.free();quit(0 if failures==0 else 1)
