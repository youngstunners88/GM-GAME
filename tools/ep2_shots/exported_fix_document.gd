extends SceneTree
## External verification fixture for the production engine/packs, never exported.
var failed := 0
func check(label: String, ok: bool) -> void:
	if not ok: failed += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: ProjectSettings.load_resource_pack(args[0], false)
	call_deferred("run")

func run() -> void:
	await process_frame
	var sm = root.get_node("StateMachine")
	sm.change_state(sm.State.TRANSITIONING)
	sm.change_state(sm.State.PLAYING)
	var session = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	root.add_child(session)
	current_scene = session
	session.set_process(false)
	var facility = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	session.add_child(facility)
	session._active = facility
	session._wire_chamber(facility)
	facility.setup()
	var film = facility.get_video_film()
	print("FIX_WEB_FILM_READY")
	var start := Time.get_ticks_msec()
	var last_time: int = start
	var last_pos := 0.0
	var worst_gap := 0
	var updates := 0
	var unwanted_prebuild := false
	while facility.get_beat_name() == "CINEMATIC" and Time.get_ticks_msec()-start < 100000:
		await process_frame
		if film._video.is_playing():
			var p: float = film._video.stream_position
			if p > last_pos:
				worst_gap = maxi(worst_gap, Time.get_ticks_msec()-last_time)
				updates += 1
				last_time = Time.get_ticks_msec()
				last_pos = p
		if not film.is_done() and session._pb_node != null: unwanted_prebuild = true
	print("FIX_FILM_METRICS ", JSON.stringify({"picture_s":last_pos,"wall_ms":Time.get_ticks_msec()-start,"updates":updates,"worst_gap_ms":worst_gap,"reason":film.finish_reason}))
	check("exported founder film decodes to normal completion", film.finish_reason == "end" and last_pos > 55.0)
	check("exported film has no elevator background rendering", not unwanted_prebuild)
	check("exported film enters the ready lesson", facility.get_beat_name() == "VERB_TEACH" and facility._room_ready)
	session.queue_free()
	await process_frame
	var town = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	town.setup()
	town.set_physics_process(false)
	town._show_active = false
	town._show_blocks_control = false
	town._hold = 0.0
	town._advance_to(town.Beat.ARMORY)
	town._show_active = false
	check("exported Sheriff and Utah install grounded skeletal walks", town._sheriff.anim_player().has_animation("GroundedWalk") and town._utah.anim_player().has_animation("GroundedWalk"))
	town._open_shop()
	print("FIX_WEB_SHOP_READY")
	for i in 5000:
		if not town._shop_open: break
		await process_frame
	check("click close uses the real trade unpause path", not town._shop_open and not paused)
	var map = load("res://src/episode2/ui/region_map.gd").new()
	map.context = func() -> Vector2: return Vector2(0.5,0.5)
	map.allowed = func() -> bool: return true
	root.get_node("GameManager").has_region_map = true
	root.add_child(map)
	map.toggle()
	print("FIX_WEB_MAP_READY")
	for i in 5000:
		if not map.expanded: break
		await process_frame
	check("click close dismisses map and resumes", not map.expanded and not paused)
	map.queue_free()
	await process_frame
	var menu = load("res://src/ui/pause_menu.tscn").instantiate()
	root.add_child(menu)
	sm.change_state(sm.State.PAUSED)
	print("FIX_WEB_EP1_PAUSE_READY")
	for i in 5000:
		if sm.is_playing(): break
		await process_frame
	check("Episode 1 pause close resumes gameplay", sm.is_playing() and not paused)
	menu.queue_free()
	await process_frame
	town._hud.show_ammo = true
	town._hud.armory_enabled = true
	town._hud.toggle_armory()
	print("FIX_WEB_SELECTOR_READY")
	for i in 5000:
		if not town._hud.armory_open: break
		await process_frame
	check("weapon selector click close cancels and resumes", not town._hud.armory_open and not paused)
	print("FIX_WEB_DONE:", failed)
