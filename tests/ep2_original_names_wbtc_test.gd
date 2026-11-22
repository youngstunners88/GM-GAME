extends Node
## Real Episode 1 pickup -> protocol save/load -> Rich's purchase transaction.
var failures: int = 0

func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _ready() -> void:
	await get_tree().process_frame
	GameManager.token_purse = {"eth": 0, "btc": 0, "sol": 0}
	GameManager.titanx_collected = 0
	GoldMineSystem.wbtc_balance = 0
	var player := Node2D.new()
	add_child(player)
	player.add_to_group("player")
	var pickup: Area2D = load("res://src/collectibles/wbtc.tscn").instantiate()
	add_child(pickup)
	pickup.wbtc_amount = 100
	pickup._on_body_entered(player)
	check("Episode 1 WBTC pickup credits the same purse Rich reads", GameManager.purse_balance("wbtc") == 60)
	var saved: Dictionary = GoldMineSystem.get_save_data()
	GoldMineSystem.wbtc_balance = 0
	GoldMineSystem.load_save_data(saved)
	check("Episode 1 WBTC survives protocol save/load", GameManager.purse_balance("wbtc") == 60)
	var town := GoldTownChamber.new()
	town.armory = Ep2ArmoryState.new()
	var shop := Ep2ArmoryShop.new()
	shop.purse_of = func(t: String) -> int: return GameManager.purse_balance(t)
	add_child(shop)
	shop.open_shop(town.armory, 0)
	check("WBTC-only player opens directly on WBTC with the real balance", shop.tender == "wbtc" and shop.purse == 60)
	check("locked stock cannot spend WBTC", not town.buy(Ep2ArmoryState.MP18, 0, "wbtc") and GoldMineSystem.wbtc_balance == 60)
	check("Rich sells the Shipment for Episode 1 WBTC", town.buy("river_gear", 0, "wbtc") and GoldMineSystem.wbtc_balance == 58)
	check("Rich sells the Sharps for WBTC at the catalogue price", town.buy("sniper", 0, "wbtc") and GoldMineSystem.wbtc_balance == 55)
	check("duplicate gun refunds WBTC", not town.buy("sniper", 0, "wbtc") and GoldMineSystem.wbtc_balance == 55)
	for id in Ep2ArmoryState.SHOP_GUNS:
		var before: int = GoldMineSystem.wbtc_balance
		check("Rich sells %s for WBTC" % Ep2ArmoryState.NAMES[id], town.buy(id, 0, "wbtc") and town.armory.owns(id)
			and GoldMineSystem.wbtc_balance == before - int(Ep2ArmoryState.shop_item(id)["price"]))
	var before_ammo: int = GoldMineSystem.wbtc_balance
	check("WBTC also buys ammunition", town.buy("mp18_ammo", 0, "wbtc") and GoldMineSystem.wbtc_balance == before_ammo - 1)
	GoldMineSystem.wbtc_balance = 0
	check("insufficient WBTC refuses without overdraft", not town.buy("mp18_ammo", 0, "wbtc") and GoldMineSystem.wbtc_balance == 0)
	check("WBTC spending never debits BTC, ETH or SOL", GameManager.token_purse == {"eth": 0, "btc": 0, "sol": 0})
	GoldMineSystem.wbtc_balance = 7
	shop.tender = "wbtc"
	GameManager.purse_add("btc", 20)
	shop.open_shop(town.armory, 20)
	check("reopening preserves a funded WBTC choice", shop.tender == "wbtc" and shop.purse == 7)
	shop._cycle_tender(1)
	check("other tenders remain selectable", shop.tender == "sol" and shop.purse == 0)
	check("original handling names restored", Ep2ArmoryState.NAMES[Ep2ArmoryState.WIN] == "Winchester 1886"
		and Ep2ArmoryState.NAMES[Ep2ArmoryState.REM] == "Golden Remington 1875"
		and Ep2ArmoryState.NAMES[Ep2ArmoryState.MP18] == "Bergmann MP18"
		and Ep2ArmoryState.NAMES[Ep2ArmoryState.BORCH] == "Borchardt C-93"
		and Ep2ArmoryState.NAMES[Ep2ArmoryState.BUFF] == "Sharps 1874")
	# founder 2026-11-22 "Rich takes WBTC, visibly, either/or": BTC and WBTC are two buttons always on the counter, each with its balance
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.token_purse = {"eth": 0, "btc": 0, "sol": 0}
	GameManager.purse_add("eth", 5)
	var sharps_price: int = int(Ep2ArmoryState.shop_item(Ep2ArmoryState.SHARPS_ITEM)["price"])
	GoldMineSystem.wbtc_balance = sharps_price + 4
	var pay_town := GoldTownChamber.new()
	pay_town.armory = Ep2ArmoryState.new()
	pay_town.armory.river_gear = true
	shop.buy_requested.connect(func(id: String, price: int, t: String) -> void: shop.purchase_result(id, pay_town.buy(id, price, t)))
	shop.tender = "btc"
	shop.open_shop(pay_town.armory, 0)
	await get_tree().process_frame
	var pay_btc: Button = shop.get_node_or_null("PayBTC")
	var pay_wbtc: Button = shop.get_node_or_null("PayWBTC")
	check("BTC and WBTC are two always-visible pay buttons (finger-sized)", pay_btc != null and pay_wbtc != null and pay_btc.is_visible_in_tree()
		and pay_wbtc.is_visible_in_tree() and pay_btc.size.y >= 64.0 and pay_wbtc.size.y >= 64.0 and not pay_btc.get_rect().intersects(pay_wbtc.get_rect()))
	check("with BTC empty the counter opens on WBTC, not ETH", shop.tender == "wbtc" and shop.purse == sharps_price + 4)
	pay_btc.pressed.emit()
	check("tapping BTC pays in BTC (holds 0)", shop.tender == "btc" and shop.purse == 0)
	pay_wbtc.pressed.emit()
	check("tapping WBTC pays in WBTC", shop.tender == "wbtc" and shop.purse == sharps_price + 4)
	shop.index = 0
	for i in Ep2ArmoryState.SHOP.size():
		if str(Ep2ArmoryState.SHOP[i]["id"]) == Ep2ArmoryState.SHARPS_ITEM: shop.index = i
	shop.grace = 0.0
	shop._buy()
	check("BTC 0 + WBTC >= price: the Sharps is bought and WBTC drops by exactly %d" % sharps_price,
		pay_town.armory.sniper_owned and GoldMineSystem.wbtc_balance == 4 and GameManager.purse_balance("btc") == 0 and GameManager.purse_balance("eth") == 5)
	var more: Button = shop.get_node_or_null("Tender")
	more.pressed.emit()
	check("MORE keeps the other tokens one tap away (ETH)", shop.tender == "eth" and shop.purse == 5)
	var intro_src: String = FileAccess.get_file_as_string("res://src/episode2/actors/ep2_armory_intro.gd")
	var price_line: String = "Three BTC or WBTC and she's yours, cartridges by the box. Coin, never credit."
	check("Rich says BTC or WBTC out loud, and the line is recorded", intro_src.contains("{price} BTC or WBTC and she's yours")
		and Ep2TownVoiceBank.stream(Ep2TownVoiceBank.id_for("rich", price_line)) != null)
	pay_town.free()
	# founder 2026-11-22 "everything slows after trading with Rich": the counter lays itself out only while it is up
	shop.close_shop()
	check("a closed counter stops its per-frame layout and its lit case", not shop.visible and not shop.is_processing()
		and shop._case_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED and shop._case_piece == null and shop.showcase_key == "")
	shop.open_shop(town.armory, 0)
	check("reopening the counter lays it out again", shop.visible and shop.is_processing())
	shop.hide()
	check("any other hide also stops the counter", not shop.is_processing())
	var town_src: String = FileAccess.get_file_as_string("res://src/episode2/chamber/gold_town.gd")
	check("the town closes Rich's counter with close_shop()", town_src.contains("_shop.close_shop()"))
	shop._tabs()
	var remembered: bool = true
	for tab in Ep2ArmoryShop.WEAPON_TABS:
		if Ep2ArmoryShop.tab_owned(shop.state, tab) and Ep2Extras.has(str(tab["model"])) and not Ep2ArmoryShop._models_seen.has(str(tab["model"])): remembered = false
	check("a tab model found once is remembered (the layout asks for the tabs hundreds of times a frame)", remembered)
	shop.queue_free()
	town.free()
	player.queue_free()
	print("ORIGINAL_NAMES_WBTC: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)
