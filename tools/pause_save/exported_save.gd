extends SceneTree
## External-only proof: real exported menu/controls and persistent user:// across engine restarts.
var gm
var sm
var checks: int=0
var failures: int=0
var touch_mode: bool=false
const PHASE := "user://pause_save_proof_phase"
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok:failures+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()>0: ProjectSettings.load_resource_pack(args[0],false)
 touch_mode=args.has("touch")
 call_deferred("run")
func save_phase(n: int) -> void:
 var f:=FileAccess.open(PHASE,FileAccess.WRITE);f.store_string(str(n));f.close()
func checkpoint_reload(n: int) -> void:
 if OS.has_feature("web"):
  for i in 1800:
   if gm.manual_save_status()!=0:break
   await process_frame
  check("browser confirms durable checkpoint",gm.manual_save_status()==1)
 print("PERSISTENCE_RELOAD:",n)
 if not OS.has_feature("web"):quit(0 if failures==0 else 1)
func wait_scene(path: String) -> Node:
 for i in 900:
  if current_scene!=null and current_scene.scene_file_path==path and sm.is_playing():return current_scene
  await process_frame
 check("scene reveal completes "+path,false);return null
func continue_from_menu() -> void:
 if sm.is_paused():sm.change_state(sm.State.PLAYING)
 if not sm.is_state(sm.State.TRANSITIONING):sm.change_state(sm.State.TRANSITIONING)
 var menu=load(gm.MENU_SCENE).instantiate();root.add_child(menu);current_scene=menu
 await process_frame
 menu._on_continue()
func run() -> void:
 await process_frame
 gm=root.get_node("GameManager");sm=root.get_node("StateMachine")
 var phase: int=int(gm.manual_resume.get("episode",0))
 if phase==0:
  gm.reset_session();gm.manual_resume={};gm.purse_add("btc",4);gm.total_score=1234
  sm.change_state(sm.State.TRANSITIONING)
  var level=load(gm.LEVEL_SEQUENCE[0]).instantiate();root.add_child(level);current_scene=level
  await process_frame
  gm.save_checkpoint(1,0,level.level_data.checkpoints[0])
  var pm=level.get_node("PauseMenu");pm.toggle()
  await process_frame
  if touch_mode:
   await RenderingServer.frame_post_draw
   await RenderingServer.frame_post_draw
   print("SAVE_TOUCH_READY:1")
   for i in 1800:
    if gm.manual_resume.get("episode")==1:break
    await process_frame
  else: pm.get_node("VBox/SaveBtn").pressed.emit()
  check("exported Episode1 Save writes the checkpoint",gm.manual_resume.get("episode")==1 and gm.manual_resume.state.total_score>=1234)
  check("exported Episode1 Save preserves pause",sm.is_paused())
  await checkpoint_reload(1);return
 if phase==1:
  check("browser reload preserves Episode1 manual checkpoint",gm.manual_resume.get("episode")==1 and gm.total_score>=1234 and gm.purse_balance("btc")==4)
  await continue_from_menu()
  var stage=await wait_scene(gm.LEVEL_SEQUENCE[0])
  check("actual menu Continue restores Episode1 stage and checkpoint",stage!=null and gm.get_checkpoint(1)!=Vector2.ZERO)
  gm.ep2_story_unlocked=true # fixture's earned-entry flag; production gate is unchanged
  root.get_node("SceneRouter").load_scene(gm.EPISODE2_SCENE)
  var entry=await wait_scene(gm.EPISODE2_SCENE)
  if entry==null:quit(1);return
  for i in 900:
   if entry._root!=null:break
   await process_frame
  var session=entry._root
  session.get_active().set_physics_process(false)
  session.armory.acquire("winchester_1886");session.armory.firearm("winchester_1886").rounds=3
  session._chain_id="logans_lake";session._chain_n=4
  session._rewarded_chambers={0:true,100:true};session._totals.gold_awarded=23
  session._completed_distance=1800;session._enter_chamber()
  session.get_active().set_physics_process(false)
  await process_frame
  if touch_mode:
   await RenderingServer.frame_post_draw
   await RenderingServer.frame_post_draw
   print("SAVE_TOUCH_READY:2")
   for i in 1800:
    if gm.manual_resume.get("episode")==2:break
    await process_frame
  else: entry._run_controls.save_button.pressed.emit()
  check("exported Episode2 visible Save writes later section",gm.manual_resume.get("episode")==2 and gm.manual_resume.section.room=="logans_lake")
  gm.purse_add("btc",15);gm.save_session()
  check("rolling autosave keeps the explicit checkpoint immutable",gm.manual_resume.state.token_purse.btc==4)
  entry._open_pause()
  await checkpoint_reload(2);return
 if phase==2:
  check("second browser reload preserves Episode2 checkpoint",gm.manual_resume.get("episode")==2 and gm.purse_balance("btc")==4)
  gm.ep2_story_unlocked=true # external replay only, never shipped
  await continue_from_menu()
  var entry=await wait_scene(gm.EPISODE2_SCENE)
  if entry==null:quit(1);return
  for i in 900:
   if entry._root!=null:break
   await process_frame
  var session=entry._root
  check("actual menu Continue restores saved lake rather than new run",session.get_mode()==2 and session.get_active().name.contains("Lake"))
  check("exported ammo and reward guards survive reload",session.armory.firearm("winchester_1886").rounds==3 and session._rewarded_chambers.has(100) and session._totals.gold_awarded==23)
  check("restored lake begins without duplicate staging",session.get_active().has_method("staging_count") and session.get_active().staging_count()==0)
  if OS.has_feature("web"):
   var before: Variant = JavaScriptBridge.eval("window.localStorage.getItem('smokerealm_manual_checkpoint_v1')",true)
   JavaScriptBridge.eval("window.__originalSaveSetItem=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw new DOMException('fixture quota','QuotaExceededError');};",true)
   entry._run_controls.save_button.pressed.emit()
   check("blocked browser storage reports failure",entry._run_controls.status.text.begins_with("Save failed"))
   check("blocked browser storage preserves previous checkpoint",JavaScriptBridge.eval("window.localStorage.getItem('smokerealm_manual_checkpoint_v1')",true)==before)
   JavaScriptBridge.eval("Storage.prototype.setItem=window.__originalSaveSetItem;delete window.__originalSaveSetItem;",true)
  entry._open_pause()
  print("PERSISTENCE_ALL_PASS"if failures==0 else "PERSISTENCE_FAILED")
  print("WEB_SAVE_READY")
  if not OS.has_feature("web"):quit(0 if failures==0 else 1)
