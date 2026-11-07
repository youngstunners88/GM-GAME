extends Node
## Rich & Utah's unlock chain and weapon tabs, and the bud in Tabs (founder 2026-11-03).
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_armory_chain_test.tscn

const OTHER_GUNS := [Ep2ArmoryState.REM, Ep2ArmoryState.BOW, Ep2ArmoryState.WIN, Ep2ArmoryState.BORCH, Ep2ArmoryState.SHOT,
	Ep2ArmoryState.MP18, Ep2ArmoryState.TOMMY]
var _failures: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] ", label)
	else:
		_failures += 1
		print("  [FAIL] ", label, " ", detail)


func _ready() -> void:
	var save_guard: RefCounted = preload("res://tests/ep2_save_guard.gd").new()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	_test_chain()
	_test_never_stranded()
	_test_saved()
	await _test_tabs()
	_test_assets()
	await _test_bud_in_tabs()
	save_guard = null
	print("EP2_ARMORY_CHAIN: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _test_chain() -> void:
	print("-- THE CHAIN: Shipment, then the Sharps, then the rest")
	var town := GoldTownChamber.new()
	GameManager.purse_spend("btc", GameManager.purse_balance("btc"))
	GameManager.purse_add("btc", 60)
	_check("the Shipment is the counter's first row", str(Ep2ArmoryState.SHOP[0]["id"]) == Ep2ArmoryState.GATE_ITEM and str(Ep2ArmoryState.SHOP[0]["name"]) == "THE SHIPMENT")
	_check("before the Shipment the Sharps is refused and no coin moves", not town.buy("sniper", 3, "btc") and not town.armory.sniper_owned and GameManager.purse_balance("btc") == 60)
	for id in OTHER_GUNS:
		_check("before the Shipment %s is refused" % id, not town.buy(id, 0, "btc"))
	_check("the Shipment is sold first", town.buy("river_gear", 2, "btc") and town.armory.river_gear and GameManager.purse_balance("btc") == 58)
	for id in OTHER_GUNS:
		if not town.armory.owns(id):
			_check("after the Shipment %s still waits for the Sharps, and no coin moves" % id, not town.buy(id, 0, "btc") and not town.armory.owns(id) and GameManager.purse_balance("btc") == 58)
	_check("the row says what it is waiting for", Ep2ArmoryState.lock_note(town.armory, Ep2ArmoryState.MP18) == "SHARPS FIRST" and Ep2ArmoryState.lock_note(Ep2ArmoryState.new(), Ep2ArmoryState.MP18) == "SHIPMENT FIRST")
	_check("the Sharps is sold next", town.buy("sniper", 3, "btc") and town.armory.sniper_owned and town.armory.owns(Ep2ArmoryState.BUFF))
	for id in OTHER_GUNS:
		_check("the Sharps opens %s" % id, Ep2ArmoryState.unlocks_stock(town.armory, id))
		if not town.armory.owns(id):
			_check("...and %s can be bought" % id, town.buy(id, 0, "btc") and town.armory.owns(id))
	town.free()
	GameManager.purse_spend("btc", GameManager.purse_balance("btc"))


func _test_never_stranded() -> void:
	print("-- THE CHAIN NEVER STRANDS HIM")
	var st := Ep2ArmoryState.post_hideout()
	st.river_gear = true
	_check("ammunition for a gun he carries stays on sale before the Sharps", Ep2ArmoryState.unlocks_stock(st, "rifle_ammo"))
	st.acquire(Ep2ArmoryState.BORCH)
	_check("a gun he already owns is not waiting on the Sharps (the stranger's Borchardt)", Ep2ArmoryState.unlocks_stock(st, Ep2ArmoryState.BORCH))
	st.confiscate_firearms()
	_check("a gun the Sheriff holds can be bought back before the Sharps", st.is_held(Ep2ArmoryState.BORCH) and Ep2ArmoryState.unlocks_stock(st, Ep2ArmoryState.BORCH))
	_check("the lake ride needs the Shipment only, so an unaffordable Sharps never stops the story", st.river_gear and not st.sniper_owned)


func _test_saved() -> void:
	print("-- THE UNLOCKS ARE SAVED")
	var st := Ep2ArmoryState.new()
	st.purchase_river_gear("btc")
	var after: Ep2ArmoryState = _reload(st)
	_check("a save after the Shipment comes back with the Sharps open and the rest shut", Ep2ArmoryState.unlocks_stock(after, "sniper") and not Ep2ArmoryState.unlocks_stock(after, Ep2ArmoryState.TOMMY))
	st.purchase_sniper("btc")
	after = _reload(st)
	_check("a save after the Sharps comes back with everything open", after.sniper_owned and Ep2ArmoryState.unlocks_stock(after, Ep2ArmoryState.TOMMY))
	var fresh: Ep2ArmoryState = _reload(Ep2ArmoryState.new())
	_check("a fresh save starts locked", not Ep2ArmoryState.unlocks_stock(fresh, "sniper"))


## Through JSON, the way a save file carries it.
func _reload(st: Ep2ArmoryState) -> Ep2ArmoryState:
	var loaded := Ep2ArmoryState.new()
	loaded.restore(JSON.parse_string(JSON.stringify(st.snapshot())))
	return loaded


func _test_tabs() -> void:
	print("-- THE WEAPON TABS (every gun owned: the mystery rule is tests/ep2_weapons_test)")
	var layer := CanvasLayer.new()
	add_child(layer)
	var shop := Ep2ArmoryShop.new()
	layer.add_child(shop)
	var bought: Array = []
	shop.buy_requested.connect(func(id: String, _p: int, _t: String) -> void: bought.append(id))
	var owner := Ep2ArmoryState.post_hideout()
	owner.purchase_river_gear("btc")
	owner.purchase_sniper("btc")
	for id in Ep2ArmoryState.IDS:
		owner.acquire(id)
	shop.open_shop(owner, 50)
	shop.grace = 0.0
	await get_tree().process_frame
	var tabs: Array = shop._tabs()
	var keys: Dictionary = {}
	for tab in tabs:
		keys[str(tab["key"])] = true
	_check("ten tabs once he owns every gun: one per supplied model, nine guns and his pickaxe", tabs.size() == 10 and keys.size() == 10 and tabs.size() == Ep2ArmoryShop.WEAPON_TABS.size() and shop._tab_btns.size() == 10, "%d tabs, %d buttons" % [tabs.size(), shop._tab_btns.size()])
	for i in tabs.size():
		shop._tab_btns[i].pressed.emit()
		for f in 3:
			await get_tree().process_frame
		var spin_a: float = shop.showcase_spin
		for f in 6:
			await get_tree().process_frame
		_check("%s: its model is in the case and turning" % tabs[i]["label"], shop.showcase_key == str(tabs[i]["key"]) and shop._case_piece != null and shop.showcase_spin > spin_a and shop.active_tab() == i)
		if str(tabs[i]["row"]) != "":
			_check("%s: the highlight is on the row that sells it" % tabs[i]["label"], str(Ep2ArmoryState.SHOP[shop.index]["id"]) == str(tabs[i]["row"]))
	_check("looking at a tab never buys anything, locked or not", bought.is_empty())
	shop.index = 0
	for f in 3:
		await get_tree().process_frame
	_check("the Shipment row shows the crate, and no gun tab is lit", shop.showcase_key == Ep2ArmoryState.GATE_ITEM and shop.active_tab() == -1)
	for screen in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(844, 390), Vector2i(667, 375), Vector2i(390, 844)]:
		get_window().size = screen
		for f in 3:
			await get_tree().process_frame
		var inside: bool = true
		var clear: bool = true
		var panel := Rect2(Vector2.ZERO, shop.size)
		for t in tabs.size():
			var r: Rect2 = shop.tab_rect(t)
			inside = inside and panel.encloses(r)
			clear = clear and not r.intersects(shop.showcase_rect()) and not r.intersects(shop.row_rect(shop._scroll))
			for u in range(t + 1, tabs.size()):
				clear = clear and not r.intersects(shop.tab_rect(u))
			var widest: float = Ep2ArmoryShop.FONT.get_string_size(str(tabs[t]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9 if r.size.x < 80.0 else 12).x
			inside = inside and widest <= r.size.x
		_check("%dx%d: every tab is on screen, its name fits, and it covers no row, tab or the case" % [screen.x, screen.y], inside and clear)
	get_window().size = Vector2i(1280, 720)
	var patch := Ep2BudPatchShop.new()
	layer.add_child(patch)
	patch.open_patch(5)
	_check("Dude's patch has no weapon tabs and never asks for the Shipment", patch._tab_btns.is_empty() and patch.tabs_height() == 0.0 and patch._lock_note("buds_two") == "")
	layer.queue_free()
	await get_tree().process_frame


func _test_assets() -> void:
	print("-- THE MODELS ARE PACK-SAFE")
	var paths: Array = [Ep2Extras.SHIPMENT, Ep2Extras.PATCH_FROST]
	for tab in Ep2ArmoryShop.WEAPON_TABS:
		paths.append(str(tab["model"]))
	for path in paths:
		_check("%s streams with the extras pack, not the main pack" % str(path).get_file(), str(path).begins_with("res://src/episode2/extras/") and ResourceLoader.exists(path))
		if not ResourceLoader.exists(path):
			continue
		var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		var tris: int = 0
		var marker: bool = false
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			marker = marker or str((mi as Node).name).to_lower().contains("icosphere")
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				tris += (mi as MeshInstance3D).mesh.surface_get_array_index_len(s) / 3
		_check("%s is within budget, with no marker sphere or rig" % str(path).get_file(), tris > 1000 and tris <= 12500 and not marker and model.find_children("*", "Skeleton3D", true, false).is_empty(), str(tris))
		model.free()


func _test_bud_in_tabs() -> void:
	print("-- A BUD BOUGHT FROM DUDE IS USABLE IN TABS")
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	var woods: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	add_child(woods)
	woods.setup()
	woods.set_physics_process(false)
	woods._health = 1
	woods._hud.health = 1
	woods._show_active = false
	woods._show_blocks_control = false
	var hud: Ep2FpsHud = woods.get_hud()
	GameManager.chill_buds = 0
	GameManager.purse_add("btc", Ep2StableYard.BUD_PRICE)
	var yard := Ep2StableYard.new()
	_check("Dude takes the coin and hands over the buds", yard.buy_buds() and GameManager.chill_buds == Ep2StableYard.BUD_PACK)
	yard.free()
	hud.toggle_armory()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Ep2WeaponSelector = hud._panel
	_check("they show in Tabs with their count", panel.bud_card.is_visible_in_tree() and panel.bud_card.text.contains("×%d" % Ep2StableYard.BUD_PACK), panel.bud_card.text)
	panel.select_bud()
	panel.refresh_supplies()
	_check("they can be used from Tabs", not panel.bud_use.disabled)
	panel.bud_use.pressed.emit()
	_check("using one heals him and spends one", woods.get_health() == 3 and GameManager.chill_buds == Ep2StableYard.BUD_PACK - 1)
	hud.close_armory(false)
	woods.queue_free()
	await get_tree().process_frame
