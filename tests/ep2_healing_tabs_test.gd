extends Node
var checks := 0
var failed := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failed += 1
	print("[PASS] "+label if ok else "[FAIL] "+label)

func click(button: Button, finger: int = -1) -> void:
	for i in 3: await get_tree().process_frame
	var point: Vector2 = button.get_global_rect().get_center()
	if finger < 0:
		var motion := InputEventMouseMotion.new()
		motion.position=point
		motion.global_position=point
		get_viewport().push_input(motion,true)
		await get_tree().process_frame
	for pressed in [true,false]:
		if finger < 0:
			var event := InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=pressed
			event.position=point
			event.global_position=point
			get_viewport().push_input(event,true)
		else:
			var event := InputEventScreenTouch.new()
			event.index=finger
			event.pressed=pressed
			event.position=point
			get_viewport().push_input(event,true)
		await get_tree().process_frame

func _ready() -> void:
	var save_guard: RefCounted=preload("res://tests/ep2_save_guard.gd").new()
	process_mode=Node.PROCESS_MODE_ALWAYS
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	var woods: WoodsQuadChamber=load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	add_child(woods)
	woods.setup()
	woods.set_physics_process(false)
	woods._health=1
	woods._hud.health=1
	woods._show_active=false
	woods._show_blocks_control=false
	var hud: Ep2FpsHud=woods.get_hud()
	GameManager.chill_buds=0
	GameManager.dude_free_bud_claimed=false
	check("Dude's real inventory gift can be claimed once",GameManager.claim_dude_free_bud() and not GameManager.claim_dude_free_bud() and GameManager.chill_buds==1)
	hud.toggle_armory()
	await get_tree().process_frame
	check("actual Tabs host owns pause",hud.armory_open and get_tree().paused)
	await click(hud._panel.bud_card)
	check("pointer selects the actual bud card",hud._panel.bud_selected and not hud._panel.bud_use.disabled)
	var equipped: String=woods.armory.equipped
	await click(hud._panel.bud_use)
	check("Use restores one heart to all three",woods.get_health()==3 and hud.health==3)
	check("successful Use spends exactly one bud",GameManager.chill_buds==0)
	check("healing keeps Tabs paused and never equips a weapon",hud.armory_open and get_tree().paused and woods.armory.equipped==equipped)
	await click(hud._panel.bud_use)
	check("disabled empty/full button cannot consume again",GameManager.chill_buds==0 and woods.get_health()==3)
	hud.close_armory(false)
	check("close returns this pause owner to gameplay",not get_tree().paused)
	GameManager.add_chill_buds(2)
	woods._health=1
	hud.health=1
	hud.toggle_armory()
	await get_tree().process_frame
	await click(hud._panel.bud_card,1)
	check("second raw finger can select the bud",hud._panel.bud_selected)
	await click(hud._panel.bud_use,1)
	check("raw finger restores full health exactly once",woods.get_health()==3 and GameManager.chill_buds==1)
	check("full health refuses another use and retains stock",not woods.use_chill_bud() and GameManager.chill_buds==1)
	woods._health=2
	hud.health=2
	var key := InputEventKey.new()
	key.pressed=true
	key.physical_keycode=KEY_H
	Input.parse_input_event(key)
	await get_tree().process_frame
	check("existing H shortcut also restores three",woods.get_health()==3 and GameManager.chill_buds==0)
	hud.close_armory(false)
	GameManager.add_chill_buds(1)
	woods._health=1
	woods._failing=true
	check("a failed attempt cannot be revived",not woods.use_chill_bud() and woods.get_health()==1 and GameManager.chill_buds==1)
	woods.free()
	var trail: LakeTrailChamber=load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	add_child(trail)
	trail.setup()
	trail.set_physics_process(false)
	trail._health=1
	check("lake trail uses its owning three-heart health",trail.use_chill_bud() and trail.get_health()==3 and trail.get_hud().health==3 and GameManager.chill_buds==0)
	trail.free()
	save_guard.restore()
	print("EP2_HEALING_TABS: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
