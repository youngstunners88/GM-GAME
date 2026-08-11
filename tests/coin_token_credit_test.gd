extends Node
## T4 — "$TITANX, $DIAMONDS, AND $GOLD are tokens and not coins."
##
## coin.gd swaps its FACE to a protocol logo per stage but used to always
## credit GameManager.add_coin() regardless of which logo was showing — a
## TitanX-branded pickup on Stage 1 still counted as "COINS" on the HUD, and
## the same was true for the (previously dead-code) Stage 2/3 branches. This
## proves each stage's coin now credits the SAME system its face represents,
## and that the fallback (a level with no stage token art) still behaves like
## a plain coin.
##
## Run: godot --headless res://tests/coin_token_credit_test.tscn

const COIN := preload("res://src/collectibles/coin.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("COIN TOKEN CREDIT (T4):")
	_test_stage(1, "titanx",
		func() -> int: return GameManager.titanx_collected,
		func(before: int, after: int) -> bool: return after == before + 1)
	_test_stage(2, "diamonds",
		func() -> int: return GoldMineSystem.diamonds_balance,
		func(before: int, after: int) -> bool: return after > before)
	_test_stage(3, "gold",
		func() -> int: return GoldMineSystem.gold_balance,
		func(before: int, after: int) -> bool: return after == before + 1)
	_test_no_coins_leak_from_branded_pickups()
	_test_fallback_stage_still_credits_coins()
	print("COIN_TOKEN_CREDIT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _test_stage(level: int, expect: String, read_balance: Callable, improved: Callable) -> void:
	GameManager.current_level = level
	var before: int = read_balance.call()
	var coin: Area2D = COIN.instantiate()
	add_child(coin)
	coin.call("collect")
	var after: int = read_balance.call()
	_check("stage %d coin (%s-branded) credits %s" % [level, expect, expect],
		improved.call(before, after),
		"before=%d after=%d" % [before, after])
	coin.queue_free()

## The regression this exists to catch: a branded pickup silently ALSO
## incrementing coins_collected, which would put the same mislabeling right
## back — just alongside the correct counter instead of instead of it.
func _test_no_coins_leak_from_branded_pickups() -> void:
	for level in [1, 2, 3]:
		GameManager.current_level = level
		var before: int = GameManager.coins_collected
		var coin: Area2D = COIN.instantiate()
		add_child(coin)
		coin.call("collect")
		var after: int = GameManager.coins_collected
		_check("stage %d branded coin does NOT also increment COINS" % level,
			after == before, "coins_collected went %d -> %d" % [before, after])
		coin.queue_free()

func _test_fallback_stage_still_credits_coins() -> void:
	GameManager.current_level = 9  # no STAGE_TOKENS entry -> plain coin
	var before: int = GameManager.coins_collected
	var coin: Area2D = COIN.instantiate()
	add_child(coin)
	coin.call("collect")
	var after: int = GameManager.coins_collected
	_check("a level with no stage token art still behaves like a plain coin",
		after == before + 1, "coins_collected went %d -> %d" % [before, after])
	coin.queue_free()
