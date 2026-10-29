class_name Ep2WorldRoutes
extends RefCounted
## Visited places remain actual instances: no rebuilt cast, resurrected enemies or repeated rewards.
var rooms: Dictionary = {}
var cooldown: float = 0.0
var horse: Node3D
var mounted: bool = false
func id_of(room: Node) -> String:
 return room.get_script().resource_path.get_file().get_basename()
func park(session: Node, room: Node) -> void:
 var id: String = id_of(room)
 if rooms.has(id): return
 # A retained room must not call an obsolete forward chain on a later visit.
 if room.chamber_cleared.is_connected(session._on_chamber_cleared): room.chamber_cleared.disconnect(session._on_chamber_cleared)
 if room.chamber_failed.is_connected(session._on_chamber_failed): room.chamber_failed.disconnect(session._on_chamber_failed)
 if room is LakeTrailChamber and room.is_mounted():
  horse=room._horse;mounted=true
 if id in ["smelting_facility","mine_lift","woods_quad"] and room._bull != null:
  room._bull.hide()
 var vp := SubViewport.new()
 vp.name = "Visited_"+id
 vp.own_world_3d = true
 vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
 session.add_child(vp)
 room.reparent(vp)
 room.process_mode = Node.PROCESS_MODE_DISABLED
 var sounds: Array = []
 for sound in room.find_children("*","AudioStreamPlayer3D",true,false):
  if sound.playing:
   sounds.append([sound,sound.get_playback_position()]);sound.stop()
 rooms[id] = {"node":room,"viewport":vp,"sounds":sounds}
func travel(session: Node, id: String, position: Vector3) -> bool:
 if not rooms.has(id): return false
 var previous: Node = session._active
 if previous is LogansLakeChamber: Ep2DrawMusic.finish_lake(previous)
 if previous is LakeTrailChamber: previous.restore_departure()
 var yaw: float = previous._look_yaw
 if previous.has_method("portal_detach"): previous.portal_detach()
 session._portal_on=false
 var pitch: float = previous._look_pitch
 if previous is LakeTrailChamber and previous.is_mounted():
  horse=previous._horse;mounted=true
 var entry: Dictionary = rooms[id]
 rooms.erase(id)
 park(session,previous)
 var room: Node = entry.node
 room.reparent(session)
 entry.viewport.queue_free()
 room.process_mode = Node.PROCESS_MODE_INHERIT
 var continuing_story: bool = room is GoldTownChamber and room._beat not in [room.Beat.GEARED, room.Beat.DONE]
 room._world_revisit = not continuing_story
 if room is Ep2Interlude: room._mounted_transport=mounted and id in ["woods_quad","gold_town"]
 room._resolved=false;room._running=true
 if not continuing_story:
  room._show_active=false;room._show_blocks_control=false;room._hold=0.0
 room._player_pos=position;room._look_yaw=yaw;room._look_pitch=pitch
 if not continuing_story and room.has_method("release_look"): room.release_look()
 if room is WoodsQuadChamber:
  room._riding=false;room._beat=room.Beat.SNEAK;room.camera_max.z=1760.0
 elif room is GoldTownChamber:
  room._depart_mounted=false
  # An unfinished errand belongs to this instance, including its referral and objective.
  # Only a completed departure returns as free roam; never manufacture GEARED on a visit.
  if room._beat == room.Beat.DONE: room._beat=room.Beat.GEARED
 elif room is SmeltingFacilityChamber:
  room._beat=room.Beat.TERMS
 elif room is MineLiftChamber:
  room._set_mouth_open(true)
  room._gate_open=1.0;room._gate_in_goal=1.0
 elif room is LakeTrailChamber:
  room._ending=false;room._end_t=0.0;room._beat=room.Beat.RIDE
  if previous is LogansLakeChamber:
   room._place_at_distance(room._route_total-2.0)
  else:
   room._place_at_distance(0.0)
   room._player_pos=position
   room._in_departure_area=true
  room._speed=0.0
  room._look_yaw=wrapf(yaw+room.lake_transform().basis.get_euler().y,-PI,PI)
 if room.has_method("set_move_input"): room.set_move_input(previous._move_input,previous._run_input)
 room._camera.current=true
 if room is LakeTrailChamber and rooms.has("gold_town"):
  room.adopt_departure(rooms.gold_town.node,rooms.get("woods_quad",{}).get("node",null))
 session._active=room
 session._chain_id=id
 session._mode=session.Mode.CHAMBER
 if continuing_story:
  room.chamber_cleared.connect(session._on_chamber_cleared, CONNECT_ONE_SHOT)
  room.chamber_failed.connect(session._on_chamber_failed, CONNECT_ONE_SHOT)
 if room.has_method("_update_camera"): room._update_camera(0.0)
 if room.has_method("_sync_visuals"): room._sync_visuals()
 for sound in entry.sounds:
  if is_instance_valid(sound[0]): sound[0].play(sound[1])
 if room is LogansLakeChamber:
  room._look_yaw=wrapf(yaw-(previous.lake_transform().basis.get_euler().y if previous is LakeTrailChamber else 0.0),-PI,PI)
  Ep2DrawMusic.begin_lake(room)
 elif room is LakeTrailChamber: Ep2DrawMusic.begin(room)
 else: Ep2DrawMusic.finish(room)
 cooldown=1.0
 session.mode_changed.emit(session._mode)
 return true
func tick(session: Node, delta: float) -> void:
 cooldown=maxf(0,cooldown-delta)
 var c: Node=session._active
 if c == null or session._mode != session.Mode.CHAMBER or not c.has_method("get_player_position"): return
 var id: String=id_of(c)
 var p: Vector3=c.get_player_position()
 if mounted and is_instance_valid(horse) and id in ["woods_quad","gold_town"]:
  if horse.get_parent()!=c._visuals: horse.reparent(c._visuals)
  horse.position=p
  if c._move_input.length()>0.05: horse.rotation.y=c._look_yaw
  c.eye_height=move_toward(c.eye_height,2.18,delta*1.5);c.walk_speed=7.0
 if cooldown>0:return
 if id=="lake_trail" and c._ending and rooms.has("logans_lake"):
  travel(session,"logans_lake",LogansLakeChamber.SPAWN)
  return
 if not c.has_player_control() or c._move_input.length()<0.05:return
 if id=="logans_lake" and p.z<LogansLakeChamber.SPAWN.z-0.7:
  travel(session,"lake_trail",Vector3.ZERO)
  return
 if id=="lake_trail" and c._in_departure_area and p.z>118.0 and rooms.has("gold_town"):
  travel(session,"gold_town",p+GoldTownChamber.DEPART_HORSE)
 elif id=="lake_trail" and c._in_departure_area and p.z < -78.5:
  travel(session,"woods_quad",p+GoldTownChamber.DEPART_HORSE)
 # The town owns Dude's ranch at z=1230. The old 1345 boundary sent the
 # referred player to the woods' independent, unreferred scenery yard.
 elif id=="gold_town" and p.z<1150.0:
  travel(session,"woods_quad",p)
 elif id=="woods_quad" and c._world_revisit:
  if p.z>1152.0:travel(session,"gold_town",p)
  elif p.z<6.2:travel(session,"mine_lift",p+MineLiftChamber.SURFACE_OFFSET)
  elif p.x>8.0 and p.z>1200.0 and p.z<1240.0:
   travel(session,"lake_trail",p-GoldTownChamber.DEPART_HORSE)
 elif id=="mine_lift" and c._world_revisit:
  if c._cage_y<0.1 and p.z<MineLiftChamber.PORTAL_Z+0.9:
   travel(session,"smelting_facility",p+Vector3(0,0,30))
  elif c._cage_y>14.9 and p.z>MineLiftChamber.EXIT_Z:
   travel(session,"woods_quad",p-MineLiftChamber.SURFACE_OFFSET)
 elif id=="smelting_facility" and c._world_revisit and p.z>SmeltingFacilityChamber.PORTAL_Z:
  travel(session,"mine_lift",p-Vector3(0,0,30))

func clear() -> void:
 for entry in rooms.values():
  if is_instance_valid(entry.viewport): entry.viewport.queue_free()
 rooms.clear()
 mounted=false;horse=null
