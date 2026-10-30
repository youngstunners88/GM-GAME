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
 session._active=trail;session._mode=session.Mode.CHAMBER
 check("correct minister voice",Ep2TownVoiceBank.LINES.vo_minister_1.ready and JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-audio-generated.json"))["vo_minister_1"]["voice_id"]=="CfxYdK3WmF3bmrvyLAiU")
 check("correct Dude voice",Ep2StableYard.DUDE_VOICE=="3N5PpVsIKXqmtLAhF2Lj")
 check("Logan's dialogue has actual recordings",Ep2TownVoiceBank.stream("logan_depth")!=null and Ep2TownVoiceBank.stream("logan_cargo")!=null and Ep2TownVoiceBank.stream("logan_handoff")!=null)
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
 check("lake route uses the supplied draw song",AudioManager._override_active and AudioManager._override_player.stream.resource_path==Ep2DrawMusic.TRACK)
 check("entering the lake replaces ride music with supplied GM Laker2",routes.travel(session,"logans_lake",LogansLakeChamber.SPAWN) and AudioManager._override_active and AudioManager._override_player.stream.resource_path==Ep2DrawMusic.LAKE_TRACK and Ep2DrawMusic.token<0)
 session.queue_free()
 await get_tree().process_frame
 print("EP2_WORLD_ROUTES: ",checks," checks, ",failed," failed")
 get_tree().quit(failed)
