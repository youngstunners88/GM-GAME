extends Node
var failures := 0
var checks := 0
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok: failures+=1
 print("[PASS] " + label if ok else "[FAIL] " + label)
func _ready() -> void:
 StateMachine.change_state(StateMachine.State.TRANSITIONING)
 StateMachine.change_state(StateMachine.State.PLAYING)
 var chart := preload("res://src/episode2/ui/region_map.gd").new()
 chart.allowed = func() -> bool: return StateMachine.is_playing() and not get_tree().paused
 chart.context = func() -> Vector2: return Vector2(.23,.42)
 add_child(chart)
 GameManager.has_region_map=false
 await get_tree().process_frame
 await get_tree().process_frame
 check("no chart before body loot",not chart.corner.visible)
 GameManager.has_region_map=true
 GameManager.map_active_destination="logans_lake"
 GameManager.save_session()
 GameManager.has_region_map=false;GameManager.map_active_destination=""
 GameManager.load_session()
 check("map ownership and destination survive disk reload",GameManager.has_region_map and GameManager.map_active_destination=="logans_lake")
 await get_tree().process_frame
 await get_tree().process_frame
 check("owned chart remains visible at top left",chart.corner.visible and chart.corner.position.x<50 and chart.corner.position.y<70)
 var key := InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_M;key.keycode=KEY_M
 check("M is mapped to chart",key.is_action_pressed("toggle_map"))
 chart._input(key)
 await get_tree().process_frame
 await get_tree().process_frame
 check("M opens map and freezes simulation",chart.expanded and chart.panel.visible and get_tree().paused)
 check("lake destination pin is visible",chart.destination.visible)
 check("player marker follows room context",chart.marker.position.is_equal_approx(Vector2(.23,.42)*chart.paper.size-chart.marker.size*.5))
 chart._input(key)
 check("M closes and resumes",not chart.expanded and not get_tree().paused)
 chart._input(key)
 var esc := InputEventKey.new();esc.pressed=true;esc.keycode=KEY_ESCAPE
 chart._input(esc)
 check("Escape closes map before normal pause",not chart.expanded and StateMachine.is_playing())
 StateMachine.change_state(StateMachine.State.PAUSED)
 chart._input(key)
 check("map cannot steal another modal pause",not chart.expanded and get_tree().paused)
 StateMachine.change_state(StateMachine.State.PLAYING)
 print("REGION_MAP: ",checks," checks, ",failures," failed")
 get_tree().quit(failures)
