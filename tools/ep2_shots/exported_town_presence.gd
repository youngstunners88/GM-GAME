extends SceneTree
## External-only production-pack replay. This script is excluded from the game.
var failed := 0
func check(label: String, ok: bool) -> void:
	if not ok:failed+=1
	print("[PASS] "+label if ok else "[FAIL] "+label)
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():ProjectSettings.load_resource_pack(args[0],false)
	call_deferred("run")
func rect(button: Control) -> Array:
	var p: Vector2=button.get_global_rect().get_center()
	return [p.x,p.y]
func run() -> void:
	await process_frame
	var sm=root.get_node("StateMachine")
	sm.change_state(sm.State.TRANSITIONING)
	sm.change_state(sm.State.PLAYING)
	root.disable_3d=true
	var session=load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	root.add_child(session)
	current_scene=session
	session.set_process(false)
	var woods=load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	session.add_child(woods)
	session._wire_chamber(woods)
	woods.setup()
	woods.set_physics_process(false)
	woods._show_active=false
	woods._show_blocks_control=false
	woods._running=true
	woods._health=1
	woods._hud.health=1
	session._active=woods
	session._mode=session.Mode.CHAMBER
	var gm=root.get_node("GameManager")
	gm.chill_buds=0
	gm.dude_free_bud_claimed=false
	check("exported Dude grants exactly one bud",gm.claim_dude_free_bud() and not gm.claim_dude_free_bud())
	var hud=woods.get_hud()
	for i in 8:await process_frame
	print("TC_WEB_OPEN_READY ",JSON.stringify({"hold":rect(hud._hold_button),"size":[root.get_visible_rect().size.x,root.get_visible_rect().size.y]}))
	while not hud.armory_open:await process_frame
	for i in 8:await process_frame
	check("exported Tabs pauses and suspends the real foot profile",paused and session.touch_suspended())
	print("TC_WEB_SUPPLIES_READY ",JSON.stringify({"bud":rect(hud._panel.bud_card),"use":rect(hud._panel.bud_use),"close":rect(hud._panel.get_node("PanelClose"))}))
	while not hud._panel.bud_selected:await process_frame
	check("exported real pointer selects the bud",not hud._panel.bud_use.disabled)
	while woods.get_health()<3:await process_frame
	check("exported use restores three hearts and spends one",woods.get_health()==3 and hud.health==3 and gm.chill_buds==0)
	check("exported full and empty cannot consume again",not woods.use_chill_bud() and gm.chill_buds==0 and hud.armory_open and paused)
	print("TC_WEB_HEALED")
	while hud.armory_open:await process_frame
	check("exported close restores play",not paused)
	session._active=null
	session.queue_free()
	await process_frame
	root.disable_3d=false
	var town=load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	root.add_child(town)
	current_scene=town
	town.setup()
	town.set_physics_process(false)
	town._advance_to(town.Beat.GEARED)
	town._show_active=false
	town._show_blocks_control=false
	town._hold=0
	town.release_look()
	town._player_pos=town.DEPART_HORSE+Vector3(2,0,2)
	town._look_yaw=atan2(10.,-9.)
	town._look_pitch=-.13
	town._update_camera(0)
	for i in 5:await process_frame
	check("exported ranch road is already present on foot",town._visuals.find_child("LakeRoadSurvey",true,false).is_visible_in_tree() and not town._depart_mounted)
	print("TC_WEB_RANCH_VIEW")
	await create_timer(5).timeout
	var survey=load("res://src/episode2/chamber/ep2_gold_town.gd")
	var xf: Transform3D=survey.building_xform(survey.entry("Bldg_Jail"))
	var d: Vector3=xf.basis*Vector3(0,0,-1)
	town._player_pos=xf*Vector3(-.4,0,-.3)
	town._look_yaw=atan2(d.x,d.z)
	town._look_pitch=-.04
	town._sheriff.place(town._jail_spot("sheriff"))
	town._update_camera(0)
	for i in 5:await process_frame
	print("TC_WEB_DOOR_VIEW")
	await create_timer(5).timeout
	print("TC_WEB_DONE:",failed)
