extends Node
class ExitProbe extends "res://src/episode2/ep2_entry.gd":
 var left: bool = false
 func _ready() -> void: pass
 func _go_home() -> void: left=true
var checks: int = 0
var failures: int = 0
func check(label: String, ok: bool) -> void:
 checks += 1
 if not ok: failures += 1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func menu_route() -> String:
 var old: Node = get_tree().current_scene
 var menu := Node.new()
 menu.scene_file_path = GameManager.MENU_SCENE
 get_tree().root.add_child(menu);get_tree().current_scene = menu
 var route: String = GameManager.level_scene(GameManager.highest_unlocked_level)
 get_tree().current_scene = old;menu.free()
 return route
func playing() -> void:
 if StateMachine.is_paused(): StateMachine.change_state(StateMachine.State.PLAYING)
 if not StateMachine.is_playing():
  if not StateMachine.is_state(StateMachine.State.TRANSITIONING): StateMachine.change_state(StateMachine.State.TRANSITIONING)
  StateMachine.change_state(StateMachine.State.PLAYING)
func _ready() -> void:
 var existed: bool = FileAccess.file_exists(GameManager.SAVE_PATH)
 var original: String = FileAccess.get_file_as_string(GameManager.SAVE_PATH) if existed else ""
 GameManager.manual_resume = {};GameManager.reset_session()
 GameManager.highest_unlocked_level = 3
 GameManager.current_level = 1
 GameManager.total_score = 150
 GameManager.purse_add("btc", 4)
 GameManager.save_checkpoint(1, 2, Vector2(1400, 300))
 GameManager.purse_add("btc", 6)
 GameManager.total_score = 900
 var pm: CanvasLayer = load("res://src/ui/pause_menu.tscn").instantiate()
 add_child(pm);playing()
 await get_tree().process_frame
 pm.toggle()
 check("Episode1 pause freezes the tree",StateMachine.is_paused() and get_tree().paused)
 pm.get_node("VBox/SaveBtn").pressed.emit()
 check("pause Save writes a real checkpoint",FileAccess.file_exists(GameManager.SAVE_PATH) and GameManager.manual_resume.get("episode")==1)
 check("manual save does not unpause the game",StateMachine.is_paused())
 check("checkpoint owns immutable currency, not later mutations",GameManager.manual_resume.state.token_purse.btc==4)
 GameManager.save_session() # rolling autosave must not erase the explicit slot
 GameManager.reset_session()
 check("saved file reloads",GameManager.load_session())
 check("Episode1 checkpoint and score restore together",GameManager.get_checkpoint(1)==Vector2(1400,300) and GameManager.total_score==150 and GameManager.purse_balance("btc")==4)
 check("Continue chooses saved stage rather than highest unlock",menu_route()==GameManager.LEVEL_SEQUENCE[0])
 var previous: String = FileAccess.get_file_as_string(GameManager.SAVE_PATH)
 check("failed storage write reports failure",not GameManager.write_session({},"user://missing-directory/save.json"))
 check("failed write preserves existing save",FileAccess.get_file_as_string(GameManager.SAVE_PATH)==previous)
 check("malformed manual record is rejected",not GameManager.save_manual_checkpoint({"version":1,"episode":2,"state":{},"section":{"mode":2,"segment":999,"room":"gold_town"}}))
 check("rejected save preserves previous checkpoint",FileAccess.get_file_as_string(GameManager.SAVE_PATH)==previous)
 pm._on_resume_pressed();pm.queue_free();await get_tree().process_frame
 playing()
 GameManager.manual_resume={};GameManager.ep2_story_unlocked=true
 var entry: Node = load("res://src/episode2/ep2_entry.tscn").instantiate()
 add_child(entry);await get_tree().process_frame
 var root: Ep2SessionRoot = entry._root
 root.get_active().set_physics_process(false)
 check("both visible controls exist in Episode2",entry._run_controls.pause_button!=null and entry._run_controls.save_button!=null)
 var event := InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE
 entry._unhandled_input(event)
 check("desktop Escape opens pause instead of leaving",entry.is_pause_open() and StateMachine.is_paused())
 check("paused Episode2 exposes the mouse pointer for Save and Home",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
 var distance: float = root.get_active().get_distance()
 await get_tree().process_frame
 check("paused runner distance stays frozen",root.get_active().get_distance()==distance)
 entry._run_controls.save_button.pressed.emit()
 check("visible Save stores the runner checkpoint",GameManager.manual_resume.get("episode")==2 and GameManager.manual_resume.section.mode==1)
 check("save confirms the restore point",entry._run_controls.status.text.begins_with("Saved: Episode 2"))
 entry.get_overlay()._input(event)
 check("Escape resumes the paused runner",not entry.is_pause_open() and StateMachine.is_playing())
 var exit_probe:=ExitProbe.new();add_child(exit_probe);exit_probe._unhandled_input(event)
 check("nonpausable contexts retain an Escape exit",exit_probe.left)
 exit_probe.queue_free()
 # Save a later actual room, not just a segment number on paper.
 root.armory.acquire(Ep2ArmoryState.WIN)
 root.armory.firearm(Ep2ArmoryState.WIN).rounds=3
 root._rewarded_chambers={0:true,100:true}
 root._totals.gold_awarded=23
 root._chain_id="logans_lake";root._chain_n=4;root._completed_distance=1800
 root._enter_chamber()
 root.get_active().set_physics_process(false)
 check("later section Save succeeds",entry._save_checkpoint())
 var saved_btc: int = GameManager.purse_balance("btc")
 GameManager.purse_add("btc",15)
 root.armory.firearm(Ep2ArmoryState.WIN).rounds=1
 GameManager.save_session() # mutate autosave after the explicit save
 entry.queue_free();await get_tree().process_frame
 check("fresh session reloads later section",GameManager.load_session() and menu_route()==GameManager.EPISODE2_SCENE)
 GameManager.ep2_story_unlocked=false
 check("saved data never grants an access bypass",not GameManager.ep2_story_unlocked)
 GameManager.ep2_story_unlocked=true # fixture already earned the episode, no shipped bypass
 var next: Node = load("res://src/episode2/ep2_entry.tscn").instantiate()
 add_child(next);await get_tree().process_frame
 var restored: Ep2SessionRoot = next._root
 check("Continue enters the saved lake instead of the opening run",restored.get_mode()==Ep2SessionRoot.Mode.CHAMBER and restored.get_active().name.contains("Lake"))
 check("completed reward guards and totals survive JSON",restored._rewarded_chambers.has(100) and restored._totals.gold_awarded==23 and restored._chain_n==4)
 check("later transient spending rolls back with the section",GameManager.purse_balance("btc")==saved_btc and restored.armory.firearm(Ep2ArmoryState.WIN).rounds>1)
 check("Logan story restarts at its coherent section checkpoint",restored.get_active().has_method("get_beat") and restored.get_active().get_beat()==LogansLakeChamber.Beat.ARRIVE and restored.get_active().staging_count()==0)
 var saves: Array = [0]
 next._run_controls.save_action = func() -> bool:
  saves[0] += 1
  return true
 var button: Button = next._run_controls.save_button
 Input.action_press("move_right")
 var down := InputEventScreenTouch.new();down.index=3;down.pressed=true;down.position=button.size*.5
 var up := InputEventScreenTouch.new();up.index=3;up.pressed=false;up.position=down.position
 button.gui_input.emit(down);button.gui_input.emit(up);button.pressed.emit()
 check("second finger saves once without releasing the steering thumb",saves[0]==1 and Input.is_action_pressed("move_right"))
 Input.action_release("move_right")
 await get_tree().process_frame
 var disk_before: String = FileAccess.get_file_as_string(GameManager.SAVE_PATH)
 next._run_controls.save_action = func() -> bool: return GameManager.write_session({},"user://missing-directory/save.json")
 button.pressed.emit()
 check("visible storage failure never claims a save or damages the old one",next._run_controls.status.text.begins_with("Save failed") and FileAccess.get_file_as_string(GameManager.SAVE_PATH)==disk_before)
 next.queue_free();await get_tree().process_frame
 # A legacy save still uses its ordinary fields and no manual-slot route.
 GameManager.manual_resume={};GameManager.total_score=77;GameManager.save_session();GameManager.total_score=0
 check("legacy/no-manual save remains compatible",GameManager.load_session() and GameManager.total_score==77 and GameManager.manual_resume.is_empty())
 GameManager.write_session({})
 check("an empty legacy object still loads its defaults",GameManager.load_session() and GameManager.total_score==0)
 if existed:
  var backup:=FileAccess.open(GameManager.SAVE_PATH,FileAccess.WRITE)
  backup.store_string(original);backup.close()
 else:DirAccess.remove_absolute(GameManager.SAVE_PATH)
 print("MANUAL_CHECKPOINT: ",checks," checks, ",failures," failed")
 get_tree().quit(0 if failures==0 else 1)
