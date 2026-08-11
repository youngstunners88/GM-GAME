extends Node
## T4 follow-up (Fable-5 review). GameManager.current_level used to be set at
## the END of LevelBase._ready(), AFTER _setup_entities() has already spawned
## and _ready()'d every collectible in the level. coin.gd reads
## GameManager.current_level in its OWN _ready() to decide which stage's
## protocol logo to wear AND, since this pass, which system to credit
## (add_titanx / GoldMineSystem.collect_diamonds / mine_gold). On a level
## TRANSITION, that meant a newly-entered level's coins spawned while
## current_level still held the PREVIOUS level's index — harmless when it only
## picked cosmetic art, no longer harmless now that it also decides which
## currency a pickup credits.
##
## Proven here rather than reasoned about: preset current_level to a WRONG
## stale value (simulating "just left level 3, entering level 1"), load the
## real level_01 scene, and check its real coin.gd instances actually see the
## CORRECT level 1 identity, not the stale one.
##
## Run: godot --headless res://tests/level_entry_current_level_order_test.tscn

const LEVEL_1 := preload("res://src/level/level_01_smoke_realm.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("LEVEL ENTRY current_level ORDERING:")
	await _run()
	print("LEVEL_ENTRY_CURRENT_LEVEL_ORDER: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	# Simulate "just came from level 3" — the exact stale value that would
	# leak into level 1's freshly-spawned coins if the ordering regressed.
	GameManager.current_level = 3
	GameManager.dash_return = {}

	var level: Node2D = LEVEL_1.instantiate()
	add_child(level)
	await get_tree().process_frame

	_check("current_level reads as this level (1), not the stale previous value (3)",
		GameManager.current_level == 1,
		"current_level = %d after entering level 1" % GameManager.current_level)

	var coins: Array = []
	for child in level.get_children():
		# EXACT match, not a suffix check: "crypto_coin.gd" also ends with the
		# substring "coin.gd" and would silently be swept in too — a different
		# script, with no _credit_target property, which would then be
		# miscounted as "wrong" for a reason that has nothing to do with what
		# this test is actually checking.
		if child.get_script() != null \
				and child.get_script().resource_path == "res://src/collectibles/coin.gd":
			coins.append(child)
	_check("level 1 spawned at least one plain coin to check", coins.size() > 0,
		"found %d" % coins.size())

	if coins.size() > 0:
		var mismatched := 0
		for c in coins:
			if str(c.get("_credit_target")) != "titanx":
				mismatched += 1
		_check("every level-1 coin credits titanx (not stale/empty from a wrong current_level read)",
			mismatched == 0,
			"%d of %d coins have the wrong _credit_target" % [mismatched, coins.size()])

	level.queue_free()
	await get_tree().process_frame
