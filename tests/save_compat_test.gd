extends Node
## Headless regression test for the v3.0 state refactor.
##
## The risk this covers: `progression_state` and `wallet_address` were added to
## a save format that players already have on disk. If load_session() chokes on
## a save written before those keys existed, every existing player loses their
## campaign. That is the single worst outcome of this refactor, so it gets a
## test rather than an assurance.
##
## Run: godot --headless res://tests/save_compat_test.tscn
## Exit code 0 = all assertions passed.

var _failures: int = 0

func _ready() -> void:
	_test_v1_save_still_loads()
	_test_v1_save_self_heals_history()
	_test_round_trip_preserves_progression()
	_test_hostile_save_is_clamped()
	_test_crypto_state_is_not_persisted()

	if _failures == 0:
		print("SAVE_COMPAT: ALL PASS")
		get_tree().quit(0)
	else:
		print("SAVE_COMPAT: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])

func _write_save(data: Dictionary) -> void:
	var f := FileAccess.open(GameManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

## Exactly the shape v1.0 shipped: no progression_state, no wallet_address.
func _v1_save() -> Dictionary:
	return {
		"total_score": 4200,
		"coins": 37,
		"rings": 5,
		"smoke": 2,
		"health": 3,
		"max_health": 3,
		"lives": 2,
		"current_level": 2,
		"highest_unlocked_level": 3,
	}

func _test_v1_save_still_loads() -> void:
	print("v1.0 save loads without the new keys:")
	_write_save(_v1_save())
	var ok := GameManager.load_session()
	_check("load_session() returns true", ok)
	_check("score survives", GameManager.total_score == 4200,
		"got %d" % GameManager.total_score)
	_check("coins survive", GameManager.coins_collected == 37)
	_check("highest_unlocked_level survives",
		GameManager.highest_unlocked_level == 3)
	_check("progression_state has defaults",
		GameManager.progression_state.has("shooter_unlocked")
		and GameManager.progression_state["shooter_unlocked"] == false)
	_check("wallet_address defaults to empty", GameManager.wallet_address == "")

func _test_v1_save_self_heals_history() -> void:
	print("v1.0 save reconstructs levels_completed from highest_unlocked_level:")
	_write_save(_v1_save())
	GameManager.load_session()
	var completed: Array = GameManager.progression_state["levels_completed"]
	# highest_unlocked_level == 3 implies levels 1 and 2 were cleared.
	_check("levels 1 and 2 inferred", completed == [1, 2], "got %s" % str(completed))

func _test_round_trip_preserves_progression() -> void:
	print("save -> load round trip:")
	_write_save(_v1_save())
	GameManager.load_session()
	GameManager.mark_boss_defeated("auditor")
	GameManager.unlock_content("shooter")
	GameManager.set_wallet_address("0xTESTWALLET")
	GameManager.save_session()

	# Wipe in-memory state so a stale value can't fake a pass.
	GameManager.progression_state["bosses_defeated"] = []
	GameManager.progression_state["shooter_unlocked"] = false
	GameManager.wallet_address = ""

	GameManager.load_session()
	_check("boss persisted",
		"auditor" in GameManager.progression_state["bosses_defeated"])
	_check("shooter unlock persisted", GameManager.is_unlocked("shooter"))
	_check("wallet persisted", GameManager.wallet_address == "0xTESTWALLET")

func _test_hostile_save_is_clamped() -> void:
	print("hand-edited save is clamped, not trusted:")
	var evil := _v1_save()
	evil["progression_state"] = {
		"levels_completed": [1, 99, 1, -4],   # out of range + duplicate
		"bosses_defeated": ["auditor", "auditor", ""],
		"shooter_unlocked": true,
		"space_unlocked": true,
		"total_play_time": -500.0,
	}
	_write_save(evil)
	GameManager.load_session()
	var completed: Array = GameManager.progression_state["levels_completed"]
	_check("out-of-range levels dropped", not (99 in completed) and not (-4 in completed),
		"got %s" % str(completed))
	_check("duplicate levels collapsed", completed.count(1) == 1)
	_check("duplicate bosses collapsed",
		GameManager.progression_state["bosses_defeated"].count("auditor") == 1)
	_check("empty boss id dropped",
		not ("" in GameManager.progression_state["bosses_defeated"]))
	_check("negative play time floored",
		GameManager.progression_state["total_play_time"] == 0.0)

func _test_crypto_state_is_not_persisted() -> void:
	print("crypto_state stays a live cache:")
	GameManager.set_crypto_price("eth", 3456.78)
	GameManager.set_crypto_balance("smoke", 1000.0)
	GameManager.save_session()
	var f := FileAccess.open(GameManager.SAVE_PATH, FileAccess.READ)
	var raw := f.get_as_text()
	f.close()
	var data: Dictionary = JSON.parse_string(raw)
	_check("crypto_state absent from save file", not data.has("crypto_state"))
	_check("no price leaked into save", not raw.contains("3456.78"))
	# A zero price must not overwrite a good one (failed-fetch guard).
	GameManager.set_crypto_price("eth", 0.0)
	_check("zero price rejected", GameManager.get_crypto("eth_price") == 3456.78,
		"got %f" % GameManager.get_crypto("eth_price"))
