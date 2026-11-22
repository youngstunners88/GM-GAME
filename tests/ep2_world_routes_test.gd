extends Node
var failed := 0
var checks := 0
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok: failed+=1
 print("[PASS] " + label if ok else "[FAIL] " + label)
func _ready() -> void:
 var session := Ep2SessionRoot.new()
 add_child(session)
 session.set_process(false)
 var routes: Ep2WorldRoutes=session.world_routes
 var facility: SmeltingFacilityChamber=preload("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
 facility.intro_film=false
 session.add_child(facility);facility.setup();facility.set_physics_process(false)
 routes.park(session,facility)
 var lift: MineLiftChamber=preload("res://src/episode2/chamber/mine_lift.tscn").instantiate()
 session.add_child(lift);lift.setup();lift.set_physics_process(false)
 routes.park(session,lift)
 var woods: WoodsQuadChamber=preload("res://src/episode2/chamber/woods_quad.tscn").instantiate()
 session.add_child(woods);woods.setup();woods.set_physics_process(false)
 routes.park(session,woods)
 var town: GoldTownChamber=preload("res://src/episode2/chamber/gold_town.tscn").instantiate()
 session.add_child(town);town.setup();town.set_physics_process(false)
 town._opp.fall_dead()
 # This fixture represents a completed departure, rather than an unfinished STREET visit.
 town._beat=town.Beat.DONE
 routes.park(session,town)
 var trail: LakeTrailChamber=preload("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 session.add_child(trail);trail.setup();trail.set_physics_process(false)
 trail.adopt_departure(town,woods)
 check("mounted town uses actual original actors",trail._visuals.is_ancestor_of(town._opp))
 check("the saloon piano and street chatter ride out with the streets (no dead stop on mounting)",town._town_audio!=null and trail._visuals.is_ancestor_of(town._town_audio))
 session._active=trail;session._mode=session.Mode.CHAMBER
 check("correct minister voice",Ep2TownVoiceBank.LINES.town_cert1_0.ready and JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-audio-generated.json"))["town_cert1_0"]["voice_id"]=="CfxYdK3WmF3bmrvyLAiU")
 check("correct Dude voice",Ep2StableYard.DUDE_VOICE=="Pe1gOSDKAuczOZqgCiEm")
 check("Logan's dialogue has actual recordings",Ep2TownVoiceBank.stream("logan_handoff")!=null and Ep2TownVoiceBank.LINES.logan_handoff.ready)
 # Founder 2026-11-22: every LOGAN line in the lake is heard (his own key), never a silent box or a subtitle.
 var logan_src: String=FileAccess.get_file_as_string("res://src/episode2/chamber/logans_lake.gd")
 var logan_rx:=RegEx.new();logan_rx.compile('"LOGAN: ([^"]+)"')
 var logan_missing: Array=[]
 for m in logan_rx.search_all(logan_src):
  var lid: String=Ep2TownVoiceBank.id_for("logan",m.get_string(1))
  if lid=="" or not Ep2TownVoiceBank.LINES[lid].ready or Ep2TownVoiceBank.stream(lid)==null: logan_missing.append(m.get_string(1).left(40))
 check("every LOGAN line in logans_lake.gd has a ready take (%d lines, missing %s)"%[logan_rx.search_all(logan_src).size(),str(logan_missing)],logan_rx.search_all(logan_src).size()>=11 and logan_missing.is_empty() and not logan_src.contains('toast("LOGAN:') and not logan_src.contains('speech("LOGAN:'))
 check("road speech resolves streamed takes",absf(trail._vo_len("trail_lb_start")-Ep2TownVoiceBank.stream("trail_lb_start").get_length())<0.001)
 trail.set_move_input(Vector2(0,-1))
 var original_woods: int=woods.get_instance_id()
 check("trail has nineteen bandits",trail.get_bandit_count()==19)
 check("horse can leave the ranch for the original woods",routes.travel(session,"woods_quad",Vector3(0,0,1151)))
 check("held movement survives the boundary",woods._move_input==Vector2(0,-1))
 check("same woods instance and mounted transport survive",session._active.get_instance_id()==original_woods and routes.mounted)
 routes.tick(session,0.1)
 check("horse is present in the visited woods",routes.horse.get_parent()==woods._visuals)
 woods._player_pos=Vector3(0,0,961)
 check("no one-way desert boundary",woods._collide(Vector3(0,0,959)).z<960)
 woods._player_pos=Vector3(0,0,400)
 check("no invisible quad set-piece fence on return",woods._collide(Vector3(0,0,450)).z>440)
 lift.portal_begin()
 check("return through the original elevator restores the HUD and held weapon",routes.travel(session,"mine_lift",Vector3(0,15,3)) and lift._hud.visible and lift._vm._shown)
 lift._player_pos=Vector3(0,15,0)
 lift._cage_y=15
 for i in 210:
  lift._player_pos.y=lift._cage_y
  lift._tick(1.0/30.0)
 check("visited elevator descends to the smelting level",lift._cage_y<0.1)
 check("original facility can be re-entered",routes.travel(session,"smelting_facility",Vector3(0,0,15)))
 check("return facility grants control without repeating lesson",facility.has_player_control() and facility._world_revisit)
 check("return facility door remains traversable",facility._exit_open() and facility._walk_through_ok())
 facility._player_pos=Vector3(0,.6,SmeltingFacilityChamber.PORTAL_Z+.02)
 facility._vel_y=2.3
 facility.set_move_input(Vector2(0,1))
 routes.cooldown=0
 routes.tick(session,.1)
 routes.cooldown=0
 routes.tick(session,2)
 check("entering the lift retains a jump and never bounces after cooldown",session._active==lift and is_equal_approx(lift._player_pos.y,.6) and is_equal_approx(lift._vel_y,2.3))
 lift._player_pos.z=MineLiftChamber.PORTAL_Z-.02
 lift.set_move_input(Vector2(0,-1))
 routes.cooldown=0
 routes.tick(session,.1)
 check("reverse travel crosses the same physical doorway plane",session._active==facility)
 var lake: LogansLakeChamber=preload("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 session.add_child(lake);lake.setup();lake.set_physics_process(false)
 routes.park(session,lake)
 check("original town can be revisited",routes.travel(session,"gold_town",Vector3(0,0,1400)))
 check("fallen stranger stays dead on returning",town._opp.dead)
 town._player_pos=Ep2GoldTown.local_to_world("Bldg_Armory",GoldTownChamber.ARMORY_SPOT)
 check("armory counter remains usable on return",town._at_armory_counter())
 check("existing trail can be revisited",routes.travel(session,"lake_trail",Vector3(12,0,-10)))
 for i in 200: trail.preview_lake(lake)
 check("horizon contains actual lake geometry",trail._lake_preview.find_child("ShoreAndMountain",true,false)!=null)
 check("lake preview matches the arrival point",(trail.lake_transform()*LogansLakeChamber.SPAWN).distance_to(trail._route_pts[trail._route_pts.size()-1])<0.01)
 check("route has gradual grass transition",trail._visuals.find_child("GradualGrassApproach",true,false)!=null)
 check("lake route uses the supplied draw song",AudioManager.current_music_player.stream.resource_path==Ep2DrawMusic.TRACK)
 check("entering the lake replaces ride music with supplied GM Laker2",routes.travel(session,"logans_lake",LogansLakeChamber.SPAWN) and AudioManager.current_music_player.stream.resource_path==Ep2DrawMusic.LAKE_TRACK and Ep2DrawMusic.token<0)
 # One world (founder 2026-11-17): the auction road is walked back to the lake and ridden out onto the SAME road again
 var road: AuctionRoadChamber=preload("res://src/episode2/chamber/auction_road.tscn").instantiate()
 road.handoff={"road_mounted":false}
 session.add_child(road);road.setup(0,[],0);road.set_physics_process(false)
 routes.park(session,road)
 var road_id: int=road.get_instance_id()
 check("the lake can ride out onto the visited road",routes.travel(session,"auction_road",road.at(AuctionRoadChamber.START_S)) and session._active==road)
 road._player_pos=road.at(AuctionRoadChamber.START_S-1.6)
 road.set_move_input(Vector2(0,1))
 routes.cooldown=0
 routes.tick(session,.1)
 check("walking back down the road arrives at Logan's Lake by the auction sign (no dead end)",session._active==lake and lake._player_pos.distance_to(Ep2WorldRoutes.lake_from_road())<0.01)
 check("the lake never rebuilds the road it already has",not lake._can_leave_for_auction())
 lake._player_pos=LogansLakeChamber.AUCTION_SIGN
 lake._show_blocks_control=false
 lake.set_move_input(Vector2(0,1))
 routes.cooldown=0
 routes.tick(session,.1)
 check("back at the sign he walks onto the same road instance",session._active!=null and session._active.get_instance_id()==road_id)
 # One world after day-88 (founder 2026-11-17): the overlook path still climbs onto the river ridge, and the ridge walks back to the lake
 var river: RiverCoverChamber=preload("res://src/episode2/chamber/river_cover.tscn").instantiate()
 session.add_child(river);river.setup(0,[],0);river.set_physics_process(false)
 river.adopt_lake(lake)
 river._beat=river.Beat.DONE
 routes.park(session,river)
 var river_id: int=river.get_instance_id()
 routes.travel(session,"logans_lake",LogansLakeChamber.SPAWN)
 lake._beat=lake.Beat.ROAD
 lake._show_blocks_control=false
 lake.set_move_input(Vector2(0,1))
 lake._player_pos=Vector3(-8.0,0,LogansLakeChamber.WALK_ON_Z+0.2)
 routes.cooldown=0;routes.tick(session,.1)
 check("arriving on the seam does not throw him onto the ridge (armed only after stepping clear)",session._active==lake)
 lake._player_pos=Vector3(-8.0,0,LogansLakeChamber.WALK_ON_Z-3.0)
 routes.cooldown=0;routes.tick(session,.1)
 var top := Vector3(-8.0,0,LogansLakeChamber.WALK_ON_Z+0.2)
 lake._player_pos=top
 routes.cooldown=0;routes.tick(session,.1)
 check("after day-88 the overlook path walks onto the SAME river ridge, where he stands",session._active!=null and session._active.get_instance_id()==river_id and river._player_pos.distance_to(top+RiverCoverChamber.LAKE_OFFSET)<0.01)
 check("the live lake stands behind the ridge while he is up there",lake._visuals.get_parent()==river._lake_root)
 check("the ridge revisit never re-resolves the river (no chained jump)",not river._resolved and river._world_revisit)
 river._show_blocks_control=false
 river.set_move_input(Vector2(0,1))
 var up: Vector3=RiverCoverChamber.RIDGE_POINTS[2]
 river._player_pos=up
 routes.cooldown=0;routes.tick(session,.1)
 check("up the ridge he stays on the ridge",session._active==river and river.ridge_s(up)>RiverCoverChamber.HOME_S+2.0)
 var home: Vector3=river._player_pos
 for k in 400:
  if river.ridge_s(home)<=RiverCoverChamber.HOME_S: break
  home=home.move_toward(RiverCoverChamber.RIDGE_POINTS[0],0.25)
 river._player_pos=home
 routes.cooldown=0;routes.tick(session,.1)
 check("walking back down the ridge returns to the same lake, the lake handed back",session._active==lake and lake._visuals.get_parent()==lake and lake._player_pos.distance_to(home-RiverCoverChamber.LAKE_OFFSET)<0.01)
 session.queue_free()
 await get_tree().process_frame
 print("EP2_WORLD_ROUTES: ",checks," checks, ",failed," failed")
 get_tree().quit(failed)
