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
	shop.queue_free()
	town.free()
	player.queue_free()
	print("ORIGINAL_NAMES_WBTC: %s" % ("ALL PASS" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)
