extends Node
## Lil Blunt's crypto purse (founder 2026-10-24): ETH, BTC, WBTC, SOL and TitanX collected all game, shown in the weapon tab, spent
## at Rich's per token. Proves the REAL Episode 1 coin scenes credit their own token, spending can never go negative or mint,
## WBTC/TitanX are the same counters the protocol already keeps, a save round-trips it, an
## old save's coin pool moves in once without creating a face, and the weapon tab draws the purse.
##
## Run: godot --headless res://tests/ep2_purse_test.tscn

var _fail: int = 0


func _check(name: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", name, "" if ok else "  (" + detail + ")"])
	if not ok:
		_fail += 1


func _ready() -> void:
	await get_tree().process_frame
	print("EP2_PURSE:")
	GameManager.token_purse = {"eth": 0, "btc": 0, "sol": 0}
	GoldMineSystem.wbtc_balance = 0
	GameManager.titanx_collected = 0
	# 1. the real coin scenes credit their own token (and still count as a coin)
	for tok in ["eth", "btc", "sol"]:
		var coin: Node = load("res://src/collectibles/coin_%s.tscn" % tok).instantiate()
		add_child(coin)
		var coins_before: int = GameManager.coins_collected
		var before: int = GameManager.purse_balance(tok)
		coin.collect()
		_check("a %s coin is one %s face in the purse and one coin on the tally" % [tok.to_upper(), tok.to_upper()],
			GameManager.purse_balance(tok) == before + 1 and GameManager.coins_collected == coins_before + 1,
			"purse %d -> %d" % [before, GameManager.purse_balance(tok)])
		coin.queue_free()
	var eth: int = GameManager.purse_balance("eth")
	GameManager.add_ethereum_ring()
	_check("an Ethereum ring is ETH in the purse", GameManager.purse_balance("eth") == eth + 1)
	# 2. WBTC and TitanX are the protocol's own counters, not copies
	GoldMineSystem.wbtc_balance = 3
	GameManager.add_titanx(2)
	_check("WBTC in the purse is GoldMineSystem.wbtc_balance", GameManager.purse_balance("wbtc") == 3)
	_check("TitanX in the purse is titanx_collected", GameManager.purse_balance("titanx") == 2)
	# 3. spending: exact debit, refusal leaves everything untouched
	GameManager.token_purse = {"eth": 4, "btc": 9, "sol": 5}
	_check("paying 3 BTC debits exactly 3 BTC", GameManager.purse_spend("btc", 3) and GameManager.purse_balance("btc") == 6
		and GameManager.purse_balance("eth") == 4 and GameManager.purse_balance("sol") == 5)
	_check("over-spending is refused and debits nothing", not GameManager.purse_spend("sol", 6) and GameManager.purse_balance("sol") == 5)
	_check("zero, negative and unknown tenders are refused", not GameManager.purse_spend("eth", 0) and not GameManager.purse_spend("eth", -2)
		and not GameManager.purse_spend("gold", 1) and GameManager.purse_balance("eth") == 4)
	_check("WBTC and TitanX pay from their own counters", GameManager.purse_spend("wbtc", 2) and GoldMineSystem.wbtc_balance == 1
		and GameManager.purse_spend("titanx", 2) and GameManager.titanx_collected == 0)
	GameManager.purse_add("wbtc", 2)
	_check("a refund puts the faces back", GoldMineSystem.wbtc_balance == 3)
	# 4. the Armory takes every token in the purse, and nothing else
	for t in GameManager.PURSE_TOKENS:
		_check("the Armory takes %s" % t.to_upper(), Ep2ArmoryState.ARMORY_TENDER.has(t) and Ep2ArmoryShop.TENDERS.has(t))
	# 6. save round trip and the one-time migration of an old save's coin pool
	GameManager.token_purse = {"eth": 2, "btc": 7, "sol": 1}
	var data: Dictionary = {"token_purse": GameManager.token_purse.duplicate()}
	GameManager.token_purse = {"eth": 0, "btc": 0, "sol": 0}
	GameManager._load_purse(data)
	_check("a save carries the purse", GameManager.token_purse == {"eth": 2, "btc": 7, "sol": 1}, str(GameManager.token_purse))
	GameManager._load_purse({"token_purse": {"eth": -5, "btc": "lots", "sol": [3]}})
	_check("a hand-edited save cannot load a negative or junk balance", GameManager.token_purse == {"eth": 0, "btc": 0, "sol": 0}, str(GameManager.token_purse))
	GameManager.coins_collected = 10
	GameManager._load_purse({"coins": 10})
	var total: int = int(GameManager.token_purse["eth"]) + int(GameManager.token_purse["btc"]) + int(GameManager.token_purse["sol"])
	_check("an old save's 10-coin pool moves in once, split ETH/BTC/SOL, no face created or lost",
		total == 10 and GameManager.token_purse == {"eth": 3, "btc": 4, "sol": 3}, str(GameManager.token_purse))
	# 7. the weapon tab draws the purse strip without error
	var sel := Ep2WeaponSelector.new()
	sel.state = Ep2ArmoryState.new()
	sel.size = Vector2(1280, 720)
	add_child(sel)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the weapon tab carries an icon for every purse token", Ep2WeaponSelector.PURSE_ICONS.size() == GameManager.PURSE_TOKENS.size())
	sel.queue_free()
	print("EP2_PURSE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
