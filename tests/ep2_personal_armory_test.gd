extends Node

class PauseProbe extends Node:
	var ticks: int = 0
	func _physics_process(_delta: float) -> void:
		ticks += 1
## Resource transactions plus real camera, input routing, runner bridge and woods checkpoint.
var _fail: int = 0

func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fail += 1

func _both() -> Ep2ArmoryState:
	var state := Ep2ArmoryState.new()
	state.acquire(Ep2ArmoryState.REM)
	state.acquire(Ep2ArmoryState.WIN)
	return state

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Ep2ArmoryState.install_actions()
	_check("rebinding rejects the existing reload key", not Ep2ArmoryState.rebind_key("ep2_weapon_2", KEY_R, false))
	_check("keyboard actions can be rebound without losing controller input", Ep2ArmoryState.rebind_key("ep2_weapon_2", KEY_F3, false) and Ep2ArmoryState.key_label("ep2_weapon_2") == "F3" and InputMap.action_get_events("ep2_weapon_2").size() == 2)
	Ep2ArmoryState.install_actions()
	_check("installation respects existing custom bindings", Ep2ArmoryState.key_label("ep2_weapon_2") == "F3")
	Ep2ArmoryState.rebind_key("ep2_weapon_2", KEY_2, false)
	var state := Ep2ArmoryState.new()
	_check("unowned gun cannot be selected", not state.select(Ep2ArmoryState.REM))
	state.restore({}, false)
	_check("old Stage 1 save does not award a revolver", not state.owns(Ep2ArmoryState.REM))
	state.restore({}, true)
	_check("old earned Stage 3 save migrates the golden Remington", state.owns(Ep2ArmoryState.REM) and state.firearm(Ep2ArmoryState.REM).rounds == 6)
	state = _both()
	var win: Ep2Winchester = state.firearm(Ep2ArmoryState.WIN)
	var rem: Ep2Winchester = state.firearm(Ep2ArmoryState.REM)
	win.rounds = 1
	win.reserve = 2
	_check("one real shot spends only one rifle round", win.trigger() == Ep2Winchester.Shot.OK and win.rounds == 0 and rem.rounds == 6)
	_check("same frame cannot fire a second round", win.trigger() == Ep2Winchester.Shot.CYCLING and win.rounds == 0)
	state.select(Ep2ArmoryState.REM)
	_check("swap has a measured 180 ms guard", not state.ready())
	state.step(0.18)
	_check("the guard opens at 180 ms", state.ready())
	state.select_previous()
	_check("swapping back cannot reset a gun cooldown", win.is_cycling())
	state.step(0.65)
	_check("owned empty guns stay selectable and dry fire", win.trigger() == Ep2Winchester.Shot.EMPTY and state.equipped == Ep2ArmoryState.WIN)
	win.start_reload()
	state.step(0.49)
	state.select(Ep2ArmoryState.REM)
	state.step(0.6)
	_check("switch before a round commits cancels it without spending reserve", win.rounds == 0 and win.reserve == 2 and not win.reloading)
	state.select(Ep2ArmoryState.WIN)
	state.step(0.18)
	win.start_reload()
	state.step(0.5)
	state.select(Ep2ArmoryState.REM)
	state.step(1.0)
	_check("completed reload rounds survive switching; future rounds do not load", win.rounds == 1 and win.reserve == 1 and not win.reloading)
	rem.rounds = 0
	rem.reserve = 0
	_check("zero reserve cannot reload or auto-switch", not rem.start_reload() and rem.trigger() == Ep2Winchester.Shot.EMPTY and state.equipped == Ep2ArmoryState.REM)
	state.record_corpse("woods:test", 3)
	_check("once-only quiver recovery stores arrows separately", state.claim_corpse("woods:test") == 3 and state.claim_corpse("woods:test") == -1 and state.arrows == 3 and win.rounds == 1 and rem.rounds == 0)
	_check("arrows do not create a bow or third quick slot", Ep2ArmoryState.IDS.size() == 2 and not state.owns("bow"))
	var saved: Dictionary = state.snapshot()
	var copy := Ep2ArmoryState.new()
	copy.restore(JSON.parse_string(JSON.stringify(saved)))
	_check("JSON round trip keeps selection, both pools and searched bodies", copy.equipped == state.equipped and copy.arrows == 3 and copy.claim_corpse("woods:test") == -1 and copy.firearm(Ep2ArmoryState.WIN).reserve == 1 and copy.firearm(Ep2ArmoryState.REM).reserve == 0)
	copy.restore({"version": [], "weapons": "bad", "arrows": {}}, false)
	copy.restore({"version": 1, "weapons": {Ep2ArmoryState.WIN: {"owned": true, "loaded": [3], "reserve": {}, "cycle": []}}, "arrows": {}})
	_check("malformed counts cannot abort save loading or inject rounds", copy.active_gun().rounds == 0 and copy.active_gun().reserve == 0 and copy.arrows == 0)

	# Exercise the actual save boundary, preserving the prior test user's save.
	var prior_save: String = FileAccess.get_file_as_string(GameManager.SAVE_PATH) if FileAccess.file_exists(GameManager.SAVE_PATH) else ""
	var prior_inventory: Dictionary = GameManager.personal_armory.duplicate(true)
	GameManager.personal_armory = saved
	_check("GameManager writes the versioned armory", GameManager.save_session())
	GameManager.personal_armory = {}
	_check("GameManager loads finite pools and loot claims", GameManager.load_session() and int(GameManager.personal_armory["weapons"][Ep2ArmoryState.WIN]["reserve"]) == 1 and int(GameManager.personal_armory["arrows"]) == 3 and bool(GameManager.personal_armory["corpses"]["woods:test"]["searched"]))
	GameManager.personal_armory = prior_inventory
	if prior_save != "":
		var file := FileAccess.open(GameManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string(prior_save)
		file.close()
	else:
		DirAccess.remove_absolute(GameManager.SAVE_PATH)

	# Camera attachment, rebinding and two simultaneously prebuilt views never refill resources.
	var cam := Camera3D.new()
	add_child(cam)
	var vm := Ep2Viewmodel.new()
	add_child(vm)
	vm.bind_armory(state)
	vm.attach(cam)
	vm.attach(cam)
	_check("repeated attach preserves an empty revolver and rifle reserve", vm.gun == rem and vm.gun.rounds == 0 and win.reserve == 1)
	_check("Remington has a real camera-held model and a grip hand", vm.rifle.name == "GoldenRemington1875" and vm.rifle.has_node("Barrel") and vm.rifle.has_node("RightArm"))
	_check("a newly selected prop starts in carry before the first physics tick", vm.rifle.position == vm.hip_pos + Vector3(vm.rifle.get_meta("hip_offset", Vector3.ZERO)) and vm.rifle.rotation.is_equal_approx(vm.rifle.get_meta("hip_rotation", Ep2Viewmodel.VM_HIP_ROT)))
	vm.set_exposure(0.7)
	vm.set_world_shadows(false)
	var lighting_ok: bool = not vm._exp_mats.is_empty()
	for pair in vm._exp_mats:
		lighting_ok = lighting_ok and is_equal_approx((pair[0] as StandardMaterial3D).albedo_color.r, (pair[1] as Color).r * 0.7) and (pair[0] as BaseMaterial3D).disable_receive_shadows
	_check("daylight settings reach the cached Winchester while Remington is equipped", lighting_ok)
	_check("the Blender Remington also receives the shadow setting", (vm.rifle.get_node("Barrel").get_surface_override_material(0) as BaseMaterial3D).disable_receive_shadows)

	state.select(Ep2ArmoryState.WIN)
	state.step(0.18)
	_check("selection projects the founder Winchester without a refill", vm.gun == win and win.rounds == 1 and vm.rifle.has_node("Hands/HandsModel"))
	var cam2 := Camera3D.new()
	add_child(cam2)
	var preview := Ep2Viewmodel.new()
	add_child(preview)
	preview.bind_armory(state.detached_copy())
	preview.attach(cam2)
	vm.fire()
	preview.bind_armory(state)
	_check("activating a prebuilt view refreshes from live ammo", preview.gun == win and preview.gun.rounds == 0)
	preview.queue_free()
	cam2.queue_free()
	vm.queue_free()
	cam.queue_free()
	await get_tree().process_frame

	# Actual session input routing, GUI finger events, and a modal that cannot shoot.
	var root := Ep2SessionRoot.new()
	root.input_enabled = false
	add_child(root)
	var prior: Dictionary = GameManager.personal_armory.duplicate(true)
	var original_level: int = GameManager.current_level
	var original_highest: int = GameManager.highest_unlocked_level
	GameManager.personal_armory = _both().snapshot()
	root.configure([], false)
	root.input_enabled = true
	var room := Ep2Interlude.new()
	root.add_child(room)
	root._wire_chamber(room)
	room._running = true
	room._camera = Camera3D.new()
	room.add_child(room._camera)
	room._build_first_person()
	root._active = room
	root._mode = Ep2SessionRoot.Mode.CHAMBER
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.pressed = true
	root._route_free_roam(key)
	_check("keyboard slot 2 selects Remington through session routing", root.armory.equipped == Ep2ArmoryState.REM)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	pad.pressed = true
	root._route_free_roam(pad)
	_check("controller LB selects Winchester through InputMap", root.armory.equipped == Ep2ArmoryState.WIN)
	await get_tree().process_frame
	var hud: Ep2FpsHud = room._hud
	var slot: Button = hud._slots[1]
	var finger := InputEventScreenTouch.new()
	finger.index = 1
	finger.position = hud._hold_button.get_global_rect().get_center()
	finger.pressed = true
	Input.parse_input_event(finger)
	await get_tree().process_frame
	_check("second-thumb hold opens the icon armory and pauses the tree", hud.armory_open and get_tree().paused)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = slot.get_global_rect().get_center()
	Input.parse_input_event(drag)
	await get_tree().process_frame
	_check("touch preview waits for release before changing weapons", hud._panel.highlighted == Ep2ArmoryState.REM and root.armory.equipped == Ep2ArmoryState.WIN)
	finger = finger.duplicate()
	finger.position = drag.position
	finger.pressed = false
	Input.parse_input_event(finger)
	await get_tree().process_frame
	_check("touch release selects the other gun and resumes gameplay", root.armory.equipped == Ep2ArmoryState.REM and not hud.armory_open and not get_tree().paused)
	root.armory.step(0.18)
	var probe := PauseProbe.new()
	probe.process_mode = Node.PROCESS_MODE_PAUSABLE
	room.add_child(probe)
	await get_tree().physics_frame
	root.armory.firearm(Ep2ArmoryState.WIN).rounds = 1
	root.armory.firearm(Ep2ArmoryState.WIN).start_reload()
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await get_tree().process_frame
	var reload_clock: float = root.armory.firearm(Ep2ArmoryState.WIN)._reload_t
	var ticks: int = probe.ticks
	var loaded: int = root.armory.active_gun().rounds
	var before: Vector3 = room.get_player_position()
	await get_tree().create_timer(0.08, true).timeout
	_check("holding armory freezes world physics and finite ammunition", probe.ticks == ticks and loaded == root.armory.active_gun().rounds and room.get_player_position() == before and not room.shoot())
	_check("holstered reload clock stays frozen throughout selection", root.armory.firearm(Ep2ArmoryState.WIN)._reload_t == reload_clock and root.armory.firearm(Ep2ArmoryState.WIN).rounds == 1)
	_check("two actual weapon textures replace the text inventory", hud._panel.ICONS[Ep2ArmoryState.WIN].get_width() == 640 and hud._panel.ICONS[Ep2ArmoryState.REM].get_width() == 640 and hud._slots.size() == 2)
	key.physical_keycode = KEY_1
	Input.parse_input_event(key)
	await get_tree().process_frame
	_check("keyboard choice works while paused without committing early", hud._panel.highlighted == Ep2ArmoryState.WIN and root.armory.equipped == Ep2ArmoryState.REM)
	tab.pressed = false
	Input.parse_input_event(tab)
	await get_tree().process_frame
	_check("key release equips once and returns control", root.armory.equipped == Ep2ArmoryState.WIN and not get_tree().paused and not hud.armory_open)
	pad.button_index = JOY_BUTTON_BACK
	pad.pressed = true
	Input.parse_input_event(pad)
	await get_tree().process_frame
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = .8
	Input.parse_input_event(stick)
	await get_tree().process_frame
	pad.pressed = false
	Input.parse_input_event(pad)
	await get_tree().process_frame
	_check("controller hold, stick choice and release select Remington", root.armory.equipped == Ep2ArmoryState.REM and not get_tree().paused)
	get_tree().paused = true
	hud.toggle_armory()
	_check("armory cannot steal an existing pause", not hud.armory_open and get_tree().paused)
	get_tree().paused = false
	room.toggle_armory()
	hud._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("focus loss releases the armory pause without changing selection", not hud.armory_open and not get_tree().paused and root.armory.equipped == Ep2ArmoryState.REM)
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	await get_tree().process_frame
	room.toggle_armory()
	await get_tree().process_frame
	_check("portrait selector uses a readable 390-unit layout and separate stacked cards", is_equal_approx(hud._panel.size.x, 390) and hud._slots[0].get_global_rect().end.y < hud._slots[1].get_global_rect().position.y)
	hud.close_armory(false)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	room.toggle_armory()
	root._active = null
	root._mode = Ep2SessionRoot.Mode.IDLE
	root.queue_free()
	await get_tree().process_frame
	_check("freeing an open HUD releases its pause", not get_tree().paused)
	GameManager.personal_armory = prior
	GameManager.current_level = original_level
	GameManager.highest_unlocked_level = original_highest

	# The real hideout grants the actual rifle resource and keeps the teacher's gate.
	var lesson_root := Ep2SessionRoot.new()
	lesson_root.input_enabled = false
	add_child(lesson_root)
	lesson_root.armory.acquire(Ep2ArmoryState.REM)
	var facility: SmeltingFacilityChamber = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	lesson_root.add_child(facility)
	lesson_root._wire_chamber(facility)
	facility.intro_film = false
	facility.setup(0, [], 0)
	facility.set_physics_process(false)
	facility._item_delivered("rifle")
	facility._enter_fps()
	facility._show_blocks_control = false
	facility._lesson = SmeltingFacilityChamber.Lesson.FIRE
	facility._gun.rounds = 3
	facility._gun.reserve = 7
	facility._gun.locked = false
	facility._gun.reload_locked = false
	_check("hideout handover shares its actual gun, including lesson ammo", lesson_root.armory.firearm(Ep2ArmoryState.WIN) == facility.get_gun())
	_check("revolver switching cannot bypass the rifle lesson", not facility.select_weapon(Ep2ArmoryState.REM) and facility._gun.rounds == 3)
	facility._lesson = SmeltingFacilityChamber.Lesson.PRACTICE
	facility._molds_left = 0
	facility._tick_lesson(0.1)
	facility._beat = SmeltingFacilityChamber.Beat.VERB_TEACH
	_check("after the lesson the hideout supports the Remington FPS view", facility.select_weapon(Ep2ArmoryState.REM) and facility._armory_view.rifle.name == "GoldenRemington1875" and lesson_root.armory.firearm(Ep2ArmoryState.WIN).rounds == 3 and lesson_root.armory.firearm(Ep2ArmoryState.WIN).reserve == 7)
	var resumed: SmeltingFacilityChamber = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	lesson_root.add_child(resumed)
	lesson_root._wire_chamber(resumed)
	resumed.intro_film = false
	resumed.setup()
	resumed.set_physics_process(false)
	resumed._item_delivered("rifle")
	resumed._begin_lesson()
	_check("re-entering a completed lesson preserves its real gun and finite ammo", resumed.get_gun() == lesson_root.armory.firearm(Ep2ArmoryState.WIN) and resumed.get_gun().rounds == 3 and resumed.get_gun().reserve == 7 and resumed.get_lesson() == SmeltingFacilityChamber.Lesson.DONE and not resumed.get_gun().locked)
	var disk_state := Ep2ArmoryState.new()
	disk_state.restore(lesson_root.armory.snapshot())
	_check("completed training survives an armory save", disk_state.firearm(Ep2ArmoryState.WIN).training_complete)
	resumed.get_gun().training_complete = false
	resumed._begin_lesson()
	_check("resuming incomplete training never refills or discards ammunition", resumed.get_gun().rounds == 3 and resumed.get_gun().reserve == 7 and resumed.get_gun().locked)
	resumed.get_gun().rounds = 4
	resumed._lesson = SmeltingFacilityChamber.Lesson.LOAD
	resumed._tick_lesson(0.1)
	_check("a resumed full gun advances past loading without another round", resumed.get_lesson() == SmeltingFacilityChamber.Lesson.AIM and resumed.get_gun().reserve == 7)
	lesson_root.queue_free()
	await get_tree().process_frame

	# Runner bridge consumes finite reserves, rather than spawning a fresh cylinder on reload.
	var runner: RunnerGraybox = load("res://src/episode2/runner/runner_graybox.tscn").instantiate()
	add_child(runner)
	runner.setup(200, [], [], [], true)
	var runner_state := _both()
	runner_state.firearm(Ep2ArmoryState.REM).rounds = 1
	runner_state.firearm(Ep2ArmoryState.REM).reserve = 2
	runner.bind_armory(runner_state)
	runner._try_fire_round()
	runner.reload()
	runner._advance_reload(1.3)
	_check("runner reload transfers only the remaining two rounds", runner.get_ammo() == 2 and runner_state.firearm(Ep2ArmoryState.REM).rounds == 2 and runner_state.firearm(Ep2ArmoryState.REM).reserve == 0)
	runner.queue_free()
	await get_tree().process_frame

	# A failed finite-ammo runner attempt cannot permanently spend its restart supply.
	var retry_root := Ep2SessionRoot.new()
	retry_root.input_enabled = false
	add_child(retry_root)
	var before_runner_save: Dictionary = GameManager.personal_armory.duplicate(true)
	var resume_reload := _both()
	resume_reload.select(Ep2ArmoryState.REM)
	resume_reload.step(0.18)
	resume_reload.active_gun().rounds = 4
	resume_reload.active_gun().start_reload()
	GameManager.personal_armory = resume_reload.snapshot()
	retry_root.configure([{"chamber_z": 200, "armed": true, "obstacles": []}], false)
	retry_root.start()
	_check("entering the runner cancels the FPS loader without spending its reserve", not retry_root.armory.firearm(Ep2ArmoryState.REM).reloading and retry_root.armory.firearm(Ep2ArmoryState.REM).rounds == 4 and retry_root.armory.firearm(Ep2ArmoryState.REM).reserve == 18)
	var attempt: RunnerGraybox = retry_root.get_active()
	attempt.set_physics_process(false)
	attempt.step(0.18)
	var starting: int = retry_root.armory.firearm(Ep2ArmoryState.REM).rounds
	var spent: bool = attempt._try_fire_round()
	retry_root._on_run_failed()
	_check("runner failure restores its entry inventory instead of draining later retries", spent and retry_root.armory.firearm(Ep2ArmoryState.REM).rounds == starting and retry_root.armory.equipped == Ep2ArmoryState.REM)
	retry_root.queue_free()
	await get_tree().process_frame
	GameManager.personal_armory = before_runner_save

	# A real bear body + proximity search + atomic surface retry.
	var woods: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	add_child(woods)
	var encounter := _both()
	encounter.firearm(Ep2ArmoryState.WIN).rounds = 2
	encounter.firearm(Ep2ArmoryState.REM).rounds = 3
	woods.bind_armory(encounter)
	woods.setup()
	woods.set_physics_process(false)
	var surface_rounds: int = encounter.active_gun().rounds
	woods.get_viewmodel().fire()  # player input can arrive before the first physics step
	woods._retry_from_surface()
	_check("surface entry captures ammo before the very first player event", encounter.active_gun().rounds == surface_rounds)
	woods.step(1.0 / 60.0)
	var baseline: Dictionary = woods._armory_snapshot.duplicate(true)
	var bear: Ep2BearBrain = woods.get_bears()[0]
	bear.arrows = 3
	bear.hp = 1
	bear.take_hit(woods.get_player_position())
	var body: Ep2Actor = bear.actor
	woods._player_pos = body.position - Vector3(0, 0, 0.3)
	woods._look_yaw = 0.0
	woods._show_blocks_control = false
	woods._riding = false
	_check("proximity search returns remaining arrows and keeps the body", woods.start_rig() and encounter.arrows == 3 and is_instance_valid(body) and body.is_inside_tree())
	_check("the same body cannot be farmed twice", not woods.start_rig() and encounter.arrows == 3)
	encounter.select(Ep2ArmoryState.REM)
	encounter.step(0.18)
	woods.shoot()
	woods._retry_from_surface()
	_check("retry restores both guns, selection, arrows and corpse claims together", encounter.snapshot()["weapons"][Ep2ArmoryState.WIN]["loaded"] == baseline["weapons"][Ep2ArmoryState.WIN]["loaded"] and encounter.snapshot()["weapons"][Ep2ArmoryState.REM]["loaded"] == baseline["weapons"][Ep2ArmoryState.REM]["loaded"] and encounter.equipped == baseline["equipped"] and encounter.arrows == baseline["arrows"] and encounter.corpses == baseline["corpses"])
	_check("retry restores the living bear with the same stable ID", not (woods.get_bears()[0] as Ep2BearBrain).is_dead() and str(woods.get_bears()[0].get_meta("corpse_id")) == "woods:0")
	# Actual activation removes/re-enters the tree; resource callbacks must survive it.
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(320, 180)
	add_child(viewport)
	woods.reparent(viewport, false)
	woods.activate(self)
	woods.set_physics_process(false)
	var reports: Array = [0]
	woods.get_viewmodel().fired.connect(func() -> void: reports[0] += 1)
	var entry_rounds: int = encounter.active_gun().rounds
	_check("activated rooms reconnect shots exactly once", woods.get_viewmodel().fire() and reports[0] == 1 and encounter.active_gun().rounds == entry_rounds - 1)
	encounter.select(Ep2ArmoryState.REM)
	encounter.step(0.18)
	_check("activated rooms still switch the real prop and gun", woods.get_viewmodel().gun == encounter.firearm(Ep2ArmoryState.REM) and woods.get_viewmodel().rifle.name == "GoldenRemington1875" and woods.get_viewmodel().fire() and reports[0] == 2)
	viewport.queue_free()
	woods.queue_free()
	await get_tree().process_frame
	# No integration fixture inventory is left in the next suite's persisted session.
	if prior_save != "":
		var file := FileAccess.open(GameManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string(prior_save)
		file.close()
	else:
		DirAccess.remove_absolute(GameManager.SAVE_PATH)
	print("EP2_PERSONAL_ARMORY: %s" % ("ALL PASS" if _fail == 0 else "%d FAILED" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
