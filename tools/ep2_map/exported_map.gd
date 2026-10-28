extends SceneTree
## External-only exported-resource replay; no production unlock or warp.
var failures := 0
func check(label: String, ok: bool) -> void:
 if not ok: failures+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()>0:ProjectSettings.load_resource_pack(args[0],false)
 call_deferred("run")
func run() -> void:
 await process_frame
 var gm=root.get_node("GameManager")
 var sm=root.get_node("StateMachine")
 gm.ep2_story_unlocked=true # Fixture only; entry's real access gate is unchanged.
 var entry=load("res://src/episode2/ep2_entry.tscn").instantiate()
 root.add_child(entry);current_scene=entry
 await process_frame
 entry._root._chain_id="gold_town";entry._root._enter_chamber()
 await process_frame
 var town=entry._root.get_active()
 town._got_map=true;gm.has_region_map=true;gm.map_active_destination="logans_lake"
 town._horse_bought=true;town._advance_to(town.Beat.GEARED)
 town._player_pos=town.DEPART_HORSE+Vector3(1.5,0,0)
 town._update_camera(0)
 var chart=entry.get_node("RegionMap")
 for i in 3:await process_frame
 check("exported chart appears after ownership",chart.corner.visible)
 print("MAP_KEYS_READY")
 for i in 1800:
  if chart.expanded:break
  await process_frame
 check("physical M opens exported chart and freezes world",chart.expanded and paused)
 print("MAP_OPEN_READY")
 for i in 1800:
  if not chart.expanded:break
  await process_frame
 check("physical Escape closes chart and restores gameplay",not chart.expanded and sm.is_playing())
 town.step(8)
 check("no automatic stable departure",entry._root.get_active()==town and town.get_beat_name()=="GEARED")
 check("E mounts only beside Dude's horse",town.can_mount_departure() and town.start_rig(""))
 print("MAP_WEB_DONE:",failures)
