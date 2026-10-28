extends Node
var failures := 0
var checks := 0
func check(label: String, ok: bool) -> void:
 checks += 1
 if not ok: failures += 1
 print("[PASS] " + label if ok else "[FAIL] " + label)
func ride(c: LakeTrailChamber, target: Vector3) -> bool:
 for i in 5000:
  var d: Vector3 = target-c._player_pos
  if d.length() < 0.5:
   c.set_move_input(Vector2.ZERO)
   return true
  c._look_yaw=atan2(d.x,d.z)
  c.set_move_input(Vector2(0,1))
  c.step(1.0/30.0)
 print("RIDE STOP ",c._player_pos," wanted ",target)
 return false
func _ready() -> void:
 var saves := [0]
 var controls := RunControls.new()
 controls.save_action=func() -> bool: saves[0]+=1;return true
 controls.available=func() -> bool: return true
 controls.checkpoint_name=func() -> String: return "Test"
 add_child(controls)
 controls._process(0)
 var key := InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_G
 controls._unhandled_input(key)
 check("G saves exactly once",saves[0]==1)
 key.echo=true;controls._unhandled_input(key)
 check("held G does not repeat saves",saves[0]==1)
 controls.free()
 var town: GoldTownChamber = preload("res://src/episode2/chamber/gold_town.tscn").instantiate()
 add_child(town);town.setup(0,[],0);town.set_physics_process(false)
 town._show_active=false;town._show_blocks_control=false;town._hold=0
 town._advance_to(town.Beat.DRAW)
 town._draw_state="go"
 town._hold=0
 check("bell alone keeps weapon holstered",town._viewmodel_lowered() and not town.shoot())
 check("Enter draws once",town.draw_weapon() and not town.draw_weapon())
 check("draw releases weapon",not town._viewmodel_lowered())
 check("previous founder Sheriff restored",town._sheriff.model.scene_file_path==town.SHERIFF_MODEL)
 town._advance_to(town.Beat.WON)
 check("minister reacts before body loot",town.minister_task()=="panic" and not town.has_peacemaker())
 check("crowd cheer is actually played",town._town_audio.effect_counts.get("crowd_cheer",0)==1)
 var folk: Ep2TownFolk=town.get_opponent()
 folk.fall_dead();folk.step(0.5)
 var pose: Transform3D=folk.global_transform * Transform3D(folk.model.basis.orthonormalized(),folk.model.position)
 var corpse_at: Vector3=pose*Vector3(0,0.9,0)
 var shot: Dictionary=town._law.player_shot(corpse_at+Vector3(0,3,0),Vector3.DOWN)
 check("fallen body remains a blood target",shot.get("kind")=="corpse" and town._law.blood_events>=2)
 for id in Ep2TownVoiceBank.LINES:
  check("recorded voice "+str(id),Ep2TownVoiceBank.stream(id)!=null)
 town.free()
 var c: LakeTrailChamber=preload("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 add_child(c);c.setup(0,[],0);c.set_physics_process(false);c.debug_invulnerable=true
 check("town remains visible behind saddle",c._visuals.find_child("DepartureTown",true,false)!=null and c._visuals.find_child("Bldg_Jail",true,false)!=null)
 check("more bandits on the road",c.get_bandit_count()==13)
 c._look_yaw=c._travel_yaw+PI;c.look(Vector2(.01,0))
 check("full backward aiming",absf(angle_difference(c._travel_yaw,c._look_yaw))>3.1)
 c.set_move_input(Vector2.ZERO)
 var parked: Vector3=c._player_pos
 for i in 90: c.step(1.0/30.0)
 check("horse waits for rider input",c._player_pos.distance_to(parked)<0.01)
 var returned:=true
 for target in [Vector3(10,0,-9),Vector3(21,0,-9),Vector3(21,0,30),Vector3(13,0,70),Vector3(13,0,170)]:
  if not ride(c,target):
   returned=false
   break
 check("ride through gate all the way back to town",returned and c._player_pos.z>165 and c.is_mounted())
 c._place_at_distance(140);c._look_yaw=c._travel_yaw+PI
 c.set_move_input(Vector2(0,1))
 for i in 300: c.step(1.0/30.0)
 check("rider can turn around on the ambush road",c._route_s<100)
 check("blood stays visibly red when dry",Ep2BloodFx.POOL_DRY.r>0.2 and Ep2BloodFx.POOL_DRY.r>Ep2BloodFx.POOL_DRY.g*8)
 c.free()
 print("EP2_RESIDUALS_1028: ",checks," checks, ",failures," failed")
 get_tree().quit(failures)
