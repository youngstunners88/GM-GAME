class_name Ep2WorldRoutes
extends RefCounted
## Visited places remain actual instances: no rebuilt cast, resurrected enemies or repeated rewards.
var rooms: Dictionary = {}
var cooldown: float = 0.0
var horse: Node3D
var mounted: bool = false
## The trail's adopted streets end here (trail z; the town room owns everything north of it). Trail -> town above it, town -> trail
## 2 m below it, so a rider standing on the line never flips rooms; `cooldown` covers the rest.
const TOWN_LINE_Z := 118.0
const TOWN_LINE_BACK := 2.0
## The walking pace a woods or town room had before the ridden horse raised it: put back when he next arrives there on foot.
var _foot_pace: Dictionary = {}
func id_of(room: Node) -> String:
 return room.get_script().resource_path.get_file().get_basename()
func park(session: Node, room: Node) -> void:
 var id: String = id_of(room)
 if rooms.has(id):
  if rooms[id].node == room: return
  # A newer visit to the same place (Logan's Lake again after day-88) replaces the stale copy instead of staying live in the tree.
  var stale: Dictionary = rooms[id]
  rooms.erase(id)
  if is_instance_valid(stale.viewport): stale.viewport.queue_free()
 # A retained room must not call an obsolete forward chain on a later visit.
 if room.chamber_cleared.is_connected(session._on_chamber_cleared): room.chamber_cleared.disconnect(session._on_chamber_cleared)
 if room.chamber_failed.is_connected(session._on_chamber_failed): room.chamber_failed.disconnect(session._on_chamber_failed)
 # The saddle is known only from the trail he is leaving: a horse left drinking at the lake (or shot) never follows him into town.
 if room is LakeTrailChamber:
  mounted=room.is_mounted();horse=room._horse if mounted else null
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
 if previous is RiverCoverChamber: previous.return_lake()
 if previous is AuctionRoadChamber: previous.return_lake()
 if previous is LogansLakeChamber: Ep2DrawMusic.finish_lake(previous)
 if previous is LakeTrailChamber: previous.restore_departure()
 var yaw: float = previous._look_yaw
 if previous.has_method("portal_detach"): previous.portal_detach()
 session._portal_on=false
 var pitch: float = previous._look_pitch
 var entry: Dictionary = rooms[id]
 rooms.erase(id)
 park(session,previous)
 var room: Node = entry.node
 room.reparent(session)
 entry.viewport.queue_free()
 room.process_mode = Node.PROCESS_MODE_INHERIT
 # An unfinished lake too: Logan's rule sends him back to Dude's mid-visit, and his story at the shore has to go on when he rides in again.
 var continuing_story: bool = (room is GoldTownChamber and room._beat not in [room.Beat.GEARED, room.Beat.DONE]) or room is LogansLakeChamber
 room._world_revisit = not continuing_story
 if room is Ep2Interlude: room._mounted_transport=mounted and id in ["woods_quad","gold_town"]
 room._resolved=false;room._running=true
 if not continuing_story:
  room._show_active=false;room._show_blocks_control=false;room._hold=0.0
 room._player_pos=position;room._look_yaw=yaw;room._look_pitch=pitch
 if (previous is SmeltingFacilityChamber and room is MineLiftChamber) or (previous is MineLiftChamber and room is SmeltingFacilityChamber):
  room._vel_y=previous._vel_y
  room._air_jumps=previous._air_jumps
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
  room.portal_finish_preview()
  room._set_mouth_open(true)
  room._gate_open=1.0;room._gate_in_goal=1.0
 elif room is LakeTrailChamber:
  # The one horse goes back under the trail's own roof: it was carried into the woods / the town's streets while he rode there.
  if is_instance_valid(room._horse) and room._horse.get_parent()!=room._visuals:
   room._horse.reparent(room._visuals,false)
   room._horse.position.y=0.0
  mounted=false;horse=null
  # A new leg of the ride: a retry restores what he carries NOW. The snapshot from the trail's first minute used to come back on a
  # later retry and wipe whatever he had bought at Rich's or Logan's since, with the BTC already spent.
  room._armory_snapshot=room.armory.snapshot()
  room._ending=false;room._end_t=0.0;room._beat=room.Beat.RIDE
  if previous is LogansLakeChamber:
   # One horse: ridden away from the lake it carries him up the trail; left drinking, the trail is walked.
   room.set_return_mounted(previous.is_riding_horse())
   room._place_at_distance(room._route_total-2.0)
  else:
   room._place_at_distance(0.0)
   room._player_pos=position
   room._in_departure_area=true
  room._speed=0.0
  # the lake room is turned against the trail; the town and the woods share the trail's own axes (a translation only)
  room._look_yaw=wrapf(yaw+room.lake_transform().basis.get_euler().y,-PI,PI) if previous is LogansLakeChamber else yaw
 # On foot in the woods or the town: his own eye height and pace, whatever a ride through here (or the mount at Dude's) left behind.
 if id in ["woods_quad","gold_town"] and not mounted:
  room.eye_height=Ep2Interlude.FPS_EYE_HEIGHT
  if _foot_pace.has(id):
   room.walk_speed=_foot_pace[id]
   _foot_pace.erase(id)
 if room.has_method("set_move_input"): room.set_move_input(previous._move_input,previous._run_input)
 room._camera.current=true
 if room is LakeTrailChamber and rooms.has("gold_town"):
  room.adopt_departure(rooms.gold_town.node,rooms.get("woods_quad",{}).get("node",null))
 session._active=room
 session._chain_id=id
 session._mode=session.Mode.CHAMBER
 if room.has_method("remember_retaliation_entry"): room.remember_retaliation_entry()
 if continuing_story:
  room.chamber_cleared.connect(session._on_chamber_cleared, CONNECT_ONE_SHOT)
 if not room.chamber_failed.is_connected(session._on_chamber_failed):
  room.chamber_failed.connect(session._on_chamber_failed, CONNECT_ONE_SHOT)
 if room.has_method("_update_camera"): room._update_camera(0.0)
 if room.has_method("_sync_visuals"): room._sync_visuals()
 for sound in entry.sounds:
  if is_instance_valid(sound[0]): sound[0].play(sound[1])
 if room is GoldTownChamber: Ep2DrawMusic.begin_town(room)
 if room is RiverCoverChamber and previous is LogansLakeChamber:
  room.lend_lake(previous)
  room.set_meta("left_home",false)
 if room is LogansLakeChamber and previous is RiverCoverChamber:
  room.set_meta("ridge_armed",false)
 if room is LogansLakeChamber:
  room._look_yaw=wrapf(yaw-(previous.lake_transform().basis.get_euler().y if previous is LakeTrailChamber else 0.0),-PI,PI)
  room.arrive_from_trail((previous is LakeTrailChamber or previous is AuctionRoadChamber) and previous.is_mounted())
  if previous is AuctionRoadChamber:
   room.set_meta("road_parked",true)          # the road is kept: riding back out takes him onto THAT road, not a rebuilt one
   if not previous.is_mounted() and room._horse != null and room._riding == false:
    room._horse.visible=false;room._horse_state="gone"     # his horse stands at the auction rail, not back at the water
  Ep2DrawMusic.begin_lake(room)
 elif room is LakeTrailChamber:
  if room.get_route_distance()>=room.get_route_length()-room.LAKE_REVEAL_DISTANCE:Ep2DrawMusic.begin_lake(room)
  else:Ep2DrawMusic.begin_trail(room)
 else: Ep2DrawMusic.finish(room)
 cooldown=1.0
 session.mode_changed.emit(session._mode)
 return true
## The road to the auction leaves the lake by Logan's sign: same compass, the sign's side of the shore.
static func lake_from_road() -> Vector3:
 var into: Vector3 = LogansLakeChamber.LOGAN_MARK - LogansLakeChamber.AUCTION_SIGN
 into.y = 0.0
 return LogansLakeChamber.AUCTION_SIGN + into.normalized() * (LogansLakeChamber.AUCTION_REACH + 1.5)
func tick(session: Node, delta: float) -> void:
 cooldown=maxf(0,cooldown-delta)
 var c: Node=session._active
 if c == null or session._mode != session.Mode.CHAMBER or not c.has_method("get_player_position"): return
 var id: String=id_of(c)
 var p: Vector3=c.get_player_position()
 if mounted and is_instance_valid(horse) and id in ["woods_quad","gold_town"]:
  if horse.get_parent()!=c._visuals: horse.reparent(c._visuals)
  if not _foot_pace.has(id): _foot_pace[id]=c.walk_speed
  horse.position=p
  if c._move_input.length()>0.05: horse.rotation.y=c._look_yaw
  c.eye_height=move_toward(c.eye_height,2.18,delta*1.5);c.walk_speed=7.0
 if cooldown>0:return
 # the shore run carries him to the water's edge first; he arrives where he is, not snapped to the lake's spawn
 if id=="lake_trail" and c._ending and c._end_t>=c._shore_time and rooms.has("logans_lake"):
  travel(session,"logans_lake",c.lake_transform().affine_inverse()*c.get_player_position())
  return
 if not c.has_player_control() or c._move_input.length()<0.05:return
 # One world: after day-88 the overlook path still climbs onto the river ridge, and the ridge walks back down to the lake.
 # Each side arms only once he has stepped clear of the seam, so standing on it never bounces him between the two.
 if id=="logans_lake" and rooms.has("river_cover") and c._beat==c.Beat.ROAD and not c.is_riding_horse():
  if p.z<LogansLakeChamber.WALK_ON_Z-2.0: c.set_meta("ridge_armed",true)
  elif p.z>=LogansLakeChamber.WALK_ON_Z and c.get_meta("ridge_armed",false):
   travel(session,"river_cover",p+RiverCoverChamber.LAKE_OFFSET)
   return
 if id=="river_cover" and c._world_revisit:
  var s: float=c.ridge_s(p)
  if s>RiverCoverChamber.HOME_S+2.0: c.set_meta("left_home",true)
  elif s<=RiverCoverChamber.HOME_S and c.get_meta("left_home",false) and rooms.has("logans_lake"):
   travel(session,"logans_lake",p-RiverCoverChamber.LAKE_OFFSET)
   return
 if id=="logans_lake" and p.z<LogansLakeChamber.SPAWN.z-0.7:
  travel(session,"lake_trail",Vector3.ZERO)
  return
 # One world (founder 2026-11-17): the auction road is walked back to the lake, and ridden out again onto the same road.
 # Founder 2026-11-22 ("why are we teleporting to the auction road"): the same place on both sides of the line, the same gaze, and the
 # real lake behind him on the road (AuctionRoadChamber.lake_xform / adopt_lake). The lake hands over at START_S, the road back at LAKE_BACK_S.
 if id=="auction_road" and c.road_s(p)<AuctionRoadChamber.LAKE_BACK_S and rooms.has("logans_lake"):
  var lake: Node=rooms.logans_lake.node
  travel(session,"logans_lake",AuctionRoadChamber.to_lake(p))
  lake._look_yaw-=AuctionRoadChamber.LAKE_YAW_DELTA
  return
 if id=="logans_lake" and rooms.has("auction_road") and c._on_road_start():
  var road: Node=rooms.auction_road.node
  var riding: bool=c.is_riding_horse()
  travel(session,"auction_road",AuctionRoadChamber.from_lake(p))
  road._look_yaw+=AuctionRoadChamber.LAKE_YAW_DELTA
  road.adopt_lake(c)
  road._mounted=riding
  if riding:
   road._hitched=false;road.eye_height=AuctionRoadChamber.MOUNTED_EYE;road.walk_speed=AuctionRoadChamber.MOUNTED_SPEED
  return
 if id=="lake_trail" and c._in_departure_area and p.z>TOWN_LINE_Z and rooms.has("gold_town"):
  travel(session,"gold_town",p+GoldTownChamber.DEPART_HORSE)
 elif id=="lake_trail" and c._in_departure_area and p.z < -78.5:
  travel(session,"woods_quad",p+GoldTownChamber.DEPART_HORSE)
 # The town owns Dude's ranch at z=1230. The old 1345 boundary sent the
 # referred player to the woods' independent, unreferred scenery yard.
 # Once he has ridden out, Dude's ranch and the lake road belong to the trail (it carries the town's own streets). Coming back down the
 # street hands him to it again - without this the revisited town had no way back to the lake at all (audit 2026-11-17).
 elif id=="gold_town" and c._world_revisit and rooms.has("lake_trail") and p.z<GoldTownChamber.DEPART_HORSE.z+TOWN_LINE_Z-TOWN_LINE_BACK:
  travel(session,"lake_trail",p-GoldTownChamber.DEPART_HORSE)
 elif id=="gold_town" and p.z<1150.0:
  travel(session,"woods_quad",p)
 elif id=="woods_quad" and c._world_revisit:
  if p.z>1152.0:
   # the same ground from the south: the trail's when it exists, else the town that has not been left yet
   if rooms.has("lake_trail"):travel(session,"lake_trail",p-GoldTownChamber.DEPART_HORSE)
   else:travel(session,"gold_town",p)
  elif p.z<6.2:travel(session,"mine_lift",p+MineLiftChamber.SURFACE_OFFSET)
 elif id=="mine_lift" and c._world_revisit:
  if c._cage_y<0.1 and p.z<MineLiftChamber.PORTAL_Z:
   travel(session,"smelting_facility",p+Vector3(0,0,30))
  elif c._cage_y>14.9 and p.z>MineLiftChamber.EXIT_Z:
   travel(session,"woods_quad",p-MineLiftChamber.SURFACE_OFFSET)
 elif id=="smelting_facility" and c._world_revisit and p.z>SmeltingFacilityChamber.PORTAL_Z:
  travel(session,"mine_lift",p-Vector3(0,0,30))

func clear() -> void:
 for entry in rooms.values():
  if is_instance_valid(entry.viewport): entry.viewport.queue_free()
 rooms.clear()
 _foot_pace.clear()
 mounted=false;horse=null
