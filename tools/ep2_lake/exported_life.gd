extends SceneTree
## External-only fixture against an exported engine and packs. Not a production warp.
var failures := 0
func check(label: String, ok: bool) -> void:
 if not ok:failures+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()>0:ProjectSettings.load_resource_pack(args[0],false)
 call_deferred("run")
func run() -> void:
 await process_frame
 var gm=root.get_node("GameManager");var sm=root.get_node("StateMachine")
 sm.change_state(sm.State.TRANSITIONING);sm.change_state(sm.State.PLAYING)
 var lake=load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 root.add_child(lake);current_scene=lake;lake.setup();lake.set_physics_process(false)
 print("LIFE_WEB_READY")
 await create_timer(1).timeout
 lake._staged=true
 for i in 3240:lake.step(1.0/60.0)
 check("exported Logan fishes with rod line and bobber",lake._skiff.state==lake._skiff.State.FISH and lake._skiff._rod.visible and lake._skiff._line_mesh.visible and lake._skiff._bobber.visible)
 var audio=lake._visuals.get_node("LakeAmbience")
 audio._process(.1)
 check("exported water insect and frog streams decode and play",audio.layers.all(func(p):return p.stream!=null and p.playing))
 audio.timer=0;audio._process(.1)
 check("exported bird recordings play",audio.bird.playing)
 var chart=load("res://src/episode2/ui/region_map.gd").new()
 chart.allowed=func() -> bool:return true
 chart.context=func() -> Vector2:return Vector2(.64,.38)
 root.add_child(chart);gm.has_region_map=true
 await process_frame;await process_frame
 check("exported full and corner charts have Lil Blunt textures",chart.marker is TextureRect and chart.corner_marker is TextureRect and chart.marker.texture!=null and chart.corner_marker.texture!=null)
 print("LIFE_MAP_READY")
 for i in 1800:
  if chart.expanded:break
  await process_frame
 check("M opens the map and pauses fishing",chart.expanded and paused)
 print("LIFE_MAP_OPEN")
 for i in 1800:
  if not chart.expanded:break
  await process_frame
 check("Escape returns to the fishing lake",not chart.expanded and not paused)
 print("LIFE_WEB_DONE:",failures)
