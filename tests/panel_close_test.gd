extends Node
var checks := 0
var failed := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failed += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	var shop := Ep2ArmoryShop.new()
	add_child(shop)
	var closes := [0]
	var purchases := [0]
	shop.closed.connect(func() -> void: closes[0] += 1; shop.hide())
	shop.buy_requested.connect(func(_id, _price, _tender) -> void: purchases[0] += 1)
	shop.open_shop(Ep2ArmoryState.post_hideout(), 10)
	var button: Button = shop.get_node("PanelClose")
	check("trade has a visible top-left close target", button.is_visible_in_tree() and button.position.x < 20 and button.position.y < 20 and button.size.x >= 44 and button.size.y >= 44)
	check("close never captures keyboard focus", button.focus_mode == Control.FOCUS_NONE)
	button.pressed.emit()
	check("close dismisses trade without a purchase", closes[0] == 1 and purchases[0] == 0 and not shop.visible)
	shop.free()
	var map = preload("res://src/episode2/ui/region_map.gd").new()
	map.context = func() -> Vector2: return Vector2(0.5,0.5)
	map.allowed = func() -> bool: return true
	GameManager.has_region_map = true
	add_child(map)
	map.toggle()
	check("expanded map owns pause", map.expanded and get_tree().paused)
	map.panel.get_node("PanelClose").pressed.emit()
	check("map close resumes its own pause", not map.expanded and not get_tree().paused)
	map.free()
	var pause = preload("res://src/ui/pause_menu.tscn").instantiate()
	add_child(pause)
	StateMachine.change_state(StateMachine.State.PAUSED)
	pause.get_node("PanelClose").pressed.emit()
	check("Episode 1 close resumes the StateMachine", StateMachine.is_playing() and not get_tree().paused)
	pause.queue_free()
	await get_tree().process_frame
	var overlay := Ep2TouchOverlay.new()
	add_child(overlay)
	var resumed := [0]
	overlay.resume_pressed.connect(func() -> void: resumed[0] += 1)
	overlay.show_pause()
	overlay.get_node("PanelClose").pressed.emit()
	check("Episode 2 pause close uses its resume signal", resumed[0] == 1)
	overlay.show_portrait_exit()
	check("portrait warning does not gain an invalid resume", not overlay.get_node("PanelClose").visible)
	overlay.free()
	print("PANEL_CLOSE: %d checks, %d failed" % [checks, failed])
	get_tree().quit(failed)
