extends Node2D
## Session-6 T1 (Diamond Vault clerk stake/crush) + T4 (Fort Knox depth),
## each written to FAIL on the pre-fix code:
##   T1a Blaze Diamond economy: add clamps to the stack limit; crush clamps to
##       held and mints the right number of $DIAMONDS through the autoload
##       (never the UI). crush_blaze_diamonds / blaze_diamonds don't exist
##       pre-fix, so this cannot even load against old goldmine_system.gd.
##   T1b Old-save compat: load_save_data() without a `blaze_diamonds` key must
##       default to 0, not crash (DeepSeek s6 regression risk).
##   T1c Clerk flow: the Diamond Vault realm has a clerk, and driving its
##       stake->crush state machine moves the REAL balances with clamps.
##   T4  Fort Knox realm exposes a second-chamber `assay_scale` interactable,
##       and staking through it moves gold into Fort Knox shares.
##
## Run: godot --headless res://tests/s6_vault_utility_test.tscn

const DIAMOND_VAULT := preload("res://src/level/diamond_vault_realm.tscn")
const FORT_KNOX := preload("res://src/level/fort_knox_realm.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 6 VAULT UTILITY:")
	_test_blaze_diamond_economy_clamps()
	_test_old_save_loads_without_blaze_diamonds()
	await _test_clerk_flow_moves_real_balances()
	await _test_fort_knox_has_assay_scale_and_stakes()
	print("S6_VAULT_UTILITY: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## T1a — the crushable Blaze Diamond resource + its clamps live in the autoload.
func _test_blaze_diamond_economy_clamps() -> void:
	GoldMineSystem.reset_session()
	# add_blaze_diamonds clamps to the stack limit.
	GoldMineSystem.add_blaze_diamonds(1000)
	var limit: int = GoldMineSystem.BLAZE_DIAMOND_STACK_LIMIT
	_check("Blaze Diamonds clamp to the stack limit on collection",
		GoldMineSystem.blaze_diamonds == limit,
		"blaze_diamonds=%d, expected %d" % [GoldMineSystem.blaze_diamonds, limit])

	# crush clamps to held and mints held * yield $DIAMONDS.
	GoldMineSystem.reset_session()
	GoldMineSystem.add_blaze_diamonds(4)
	var diamonds_before: int = GoldMineSystem.diamonds_balance
	var minted: int = GoldMineSystem.crush_blaze_diamonds(999)  # over-ask
	var yield_each: int = GoldMineSystem.BLAZE_DIAMOND_CRUSH_YIELD
	_check("crush clamps to held (can't crush more than owned)",
		minted == 4 * yield_each and GoldMineSystem.blaze_diamonds == 0,
		"minted=%d (expected %d), blaze left=%d" % [minted, 4 * yield_each, GoldMineSystem.blaze_diamonds])
	_check("crush mints the right number of $DIAMONDS tokens into the balance",
		GoldMineSystem.diamonds_balance == diamonds_before + 4 * yield_each,
		"diamonds %d -> %d" % [diamonds_before, GoldMineSystem.diamonds_balance])
	_check("crushing zero is a safe no-op",
		GoldMineSystem.crush_blaze_diamonds(0) == 0)

## T1b — a save written before session 6 (no blaze_diamonds key) loads as 0.
func _test_old_save_loads_without_blaze_diamonds() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.add_blaze_diamonds(7)
	# Deliberately omit "blaze_diamonds" from the dict, mimicking an old save.
	var old_save := {"gold": 10, "diamonds": 5, "diamond_shares": 2}
	GoldMineSystem.load_save_data(old_save)
	_check("old save without a blaze_diamonds key loads as 0 (no crash)",
		GoldMineSystem.blaze_diamonds == 0,
		"blaze_diamonds=%d after loading a keyless save" % GoldMineSystem.blaze_diamonds)

## T1c — the clerk exists in the Diamond Vault and its flow moves real balances.
func _test_clerk_flow_moves_real_balances() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.diamonds_balance = 100
	GoldMineSystem.add_blaze_diamonds(10)
	var realm: Node = DIAMOND_VAULT.instantiate()
	add_child(realm)
	await get_tree().process_frame

	var clerk := realm.get_node_or_null("VaultClerk")
	_check("Diamond Vault has a vault clerk NPC to talk to", clerk != null,
		"no VaultClerk node — the founder's 'speak to a character' is missing")

	var shares_before: int = GoldMineSystem.diamond_shares
	# Drive the clerk directly (UI-independent, headless-safe). Session 7: the
	# panel now shows BOTH rows and a single CONFIRM applies stake + crush.
	realm.call("clerk_open")                 # stake_amt -> 100, crush_amt -> 10 (clamped)
	realm.call("clerk_confirm")              # applies stake(100) + crush(10)
	var yield_each: int = GoldMineSystem.BLAZE_DIAMOND_CRUSH_YIELD

	_check("clerk stake consumed the staked $DIAMONDS and minted shares",
		GoldMineSystem.diamond_shares > shares_before,
		"diamond_shares %d -> %d" % [shares_before, GoldMineSystem.diamond_shares])
	_check("clerk crush cleared the Blaze Diamonds",
		GoldMineSystem.blaze_diamonds == 0,
		"blaze_diamonds=%d after crush" % GoldMineSystem.blaze_diamonds)
	# Staked all 100, then crushed 10 -> minted 10*yield back into the balance.
	_check("net $DIAMONDS balance reflects stake-all then crush-mint",
		GoldMineSystem.diamonds_balance == 10 * yield_each,
		"diamonds_balance=%d, expected %d" % [GoldMineSystem.diamonds_balance, 10 * yield_each])

	realm.queue_free()
	await get_tree().process_frame

## T4 — Fort Knox second chamber: a reachable Assay Scale that stakes gold.
func _test_fort_knox_has_assay_scale_and_stakes() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.gold_balance = 400
	var realm: Node = FORT_KNOX.instantiate()
	add_child(realm)
	await get_tree().process_frame

	var scales := get_tree().get_nodes_in_group("assay_scale")
	_check("Fort Knox has a second-chamber Assay Scale interactable",
		scales.size() >= 1, "no node in group 'assay_scale' — Fort Knox is still one room")

	var shares_before: int = GoldMineSystem.fort_knox_shares
	realm.call("_stake_at", "assay")
	_check("weighing gold at the Assay Scale mints Fort Knox shares",
		GoldMineSystem.fort_knox_shares > shares_before and GoldMineSystem.gold_balance < 400,
		"fort_knox_shares %d -> %d, gold %d" % [shares_before, GoldMineSystem.fort_knox_shares, GoldMineSystem.gold_balance])

	realm.queue_free()
	GoldMineSystem.reset_session()
	await get_tree().process_frame
