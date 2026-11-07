extends Node
## The mystery rule as a player sees it (founder 2026-11-07; tests/ep2_weapons_test): a new save opens Tabs and Rich's counter (only what he has, the
## pickaxe, the Shipment over the Buffalo Gun over its cartridges), buys the Shipment and the Sharps with the chamber's own buy(), and the Sharps' tab
## and card appear. Real town chamber, real Compatibility renderer, a 1280x720 SubViewport (the window manager overrides the window size).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/weapon_tabs_shot.tscn -- out=docs/episode2-quality/weapon-tabs-2026-11-07/tabs
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/weapon_tabs"
var _c: GoldTownChamber = null
var _vp: SubViewport = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS               # the counter pauses the tree, as in the game
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_c = TOWN.instantiate()
	_vp.add_child(_c)
	_c.setup(0, [], 0)
	await get_tree().process_frame
	_c.set_process(false)
	_c.set_physics_process(false)
	_c.skip_armory_intro()
	GameManager.purse_spend("btc", GameManager.purse_balance("btc"))
	GameManager.purse_add("btc", 12)
	var counter: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", GoldTownChamber.ARMORY_SPOT)
	_c._player_pos = counter
	_c._advance_to(GoldTownChamber.Beat.ARMORY)
	var case_w: Vector3 = Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(2.6, 1.0, -5.2))
	_c._look_yaw = atan2(case_w.x - counter.x, case_w.z - counter.z)
	_c.step(0.1)
	# 1. a new save: Tabs, then Rich's counter
	_c.toggle_armory()
	await _grab("1_new_save_tabs")
	_c.get_hud().close_armory(false)
	_c._open_shop()
	await _grab("2_new_save_counter")
	var shop: Ep2ArmoryShop = _c._shop
	var pick: int = -1
	for i in shop._tabs().size():
		if str(shop._tabs()[i]["key"]) == Ep2ArmoryState.PICK:
			pick = i
	shop.show_tab(pick)
	await _grab("3_pickaxe_tab")
	# 2. the purchases, through the chamber's own buy (the purse is debited, the counter answers)
	shop.index = 0
	print("WEAPON_TABS_SHOT buy shipment ", _c.buy("river_gear", 2, "btc"))
	shop.purchase_result("river_gear", true)
	await _grab("4_shipment_bought")
	shop.index = 1
	await _grab("5_buffalo_gun_highlighted")
	print("WEAPON_TABS_SHOT buy sharps ", _c.buy("sniper", 3, "btc"))
	shop.purchase_result("sniper", true)
	await _grab("6_sharps_bought_tab_appears")
	shop.show_tab(0)
	await _grab("7_sharps_tab_in_case")
	_c._close_shop()
	_c.step(0.05)
	_c.toggle_armory()
	await _grab("8_tabs_after_purchase")
	for screen in [Vector2i(844, 390), Vector2i(390, 844)]:           # a phone, both ways
		_vp.size = screen
		await _grab("8_tabs_after_purchase_%dx%d" % [screen.x, screen.y])
	_vp.size = Vector2i(1280, 720)
	_c.get_hud().close_armory(false)
	_c._open_shop()
	for screen in [Vector2i(844, 390), Vector2i(390, 844)]:
		_vp.size = screen
		await _grab("6b_counter_%dx%d" % [screen.x, screen.y])
	_vp.size = Vector2i(1280, 720)
	_c._close_shop()
	_c.step(0.05)
	# 3. the Sheriff takes the irons: Tabs empties, the pick stays
	_c.armory.confiscate_firearms()
	_c.toggle_armory()
	await _grab("9_tabs_in_jail")
	print("WEAPON_TABS_SHOT done ", _out)
	get_tree().quit()


func _grab(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var keys: Array = []
	for t in _c._shop._tabs():
		keys.append(str(t["label"]))
	print("WEAPON_TABS_SHOT ", name, " strip=", keys, " cards=", _c.get_hud()._panel.shown_ids() if _c.get_hud() != null else [])
