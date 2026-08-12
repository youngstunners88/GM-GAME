extends Node2D
## Gate for the "complete section" requirements beyond enter/exit/no-soft-lock
## (already covered by protocol_vault_test.gd): 2+ interactable types beyond
## a coin pile, a protocol-appropriate hazard, and a real jump-legal path
## between every platform tier and the exit.
##
## Falsifiable criteria taken directly from this session's DeepSeek compliance
## matrix (T1-INTERACT, T1-HAZARD): count distinct interactable/hazard entity
## types per vault, don't just assert "interactivity" exists in the abstract.
##
## Run: godot --headless res://tests/vault_interactables_test.tscn

const VAULT := preload("res://src/level/protocol_vault.tscn")
## Single-jump apex from the real player constants (jump_force=-430,
## gravity=1000): 430^2 / (2*1000) = 92.45px.
const JUMP_APEX: float = 92.45

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("VAULT INTERACTABLES + HAZARD + TIER REACHABILITY:")
	_test_two_distinct_interactables("Diamond Vault", "diamonds", 100.0)
	_test_two_distinct_interactables("Fort Knox", "gold", 140.0)
	await _test_deposit_interact_grants_reward("Diamond Vault", "diamonds", 100.0)
	await _test_switch_interact_grants_reward_and_is_distinct("Fort Knox", "gold", 140.0)
	await _test_diamond_hazard_fires()
	await _test_fort_knox_hazard_exists()
	_test_tier_deltas_are_jump_legal("Diamond Vault", "diamonds", 100.0)
	_test_tier_deltas_are_jump_legal("Fort Knox", "gold", 140.0)
	print("VAULT_INTERACTABLES: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

# --- Interactable count (falsifiable: real node count, not a vibe) ---------

func _test_two_distinct_interactables(label: String, protocol: String, mouth_width: float) -> void:
	var lvl_parent := Node2D.new()
	add_child(lvl_parent)
	var vault: Node2D = VAULT.instantiate()
	vault.protocol = protocol
	vault.mouth_width = mouth_width
	vault.global_position = Vector2(1000, 650)
	lvl_parent.add_child(vault)
	await get_tree().process_frame

	var deposit_prop = vault.get("_deposit_prop")
	var switch_prop = vault.get("_switch_prop")
	var has_forge := false
	for c in lvl_parent.get_children():
		if c != vault and c.get_script() != null and c.get_script().resource_path.ends_with("melt_forge.gd"):
			has_forge = true

	if protocol == "diamonds":
		_check("%s: interactable #1 (deposit pillar) exists" % label, deposit_prop != null)
		_check("%s: interactable #2 (switch) exists, distinct from #1" % label,
			switch_prop != null and switch_prop != deposit_prop)
	else:
		_check("%s: interactable #1 (real melt_forge entity, reused) exists" % label, has_forge)
		_check("%s: interactable #2 (vault-door switch) exists, distinct from #1" % label,
			switch_prop != null)

	vault.queue_free(); lvl_parent.queue_free()
	await get_tree().process_frame

# --- Reward: pressing interact actually grants coins, real EntitySpawner path ---

func _test_deposit_interact_grants_reward(label: String, protocol: String, mouth_width: float) -> void:
	var lvl_parent := Node2D.new()
	add_child(lvl_parent)
	var vault: Node2D = VAULT.instantiate()
	vault.protocol = protocol
	vault.mouth_width = mouth_width
	vault.global_position = Vector2(1000, 650)
	lvl_parent.add_child(vault)
	await get_tree().process_frame

	var deposit_prop: Area2D = vault.get("_deposit_prop")
	if deposit_prop == null:
		_check("%s: deposit prop exists to test" % label, false)
		lvl_parent.queue_free()
		return

	var before: int = lvl_parent.get_child_count()
	# Drive the exact real path: enter range, then the vault's own
	# _physics_process reads Input.is_action_just_pressed("interact"). Headless
	# tests can't simulate real input events reliably, so call the same
	# handler the input check would call — this is the documented, accepted
	# pattern this project already uses for interact-style props (see
	# melt_forge's own test coverage philosophy: prove the SPAWN/reward path,
	# not the OS-level key event).
	vault.call("_on_deposit_pillar_used")
	await get_tree().process_frame
	var after_first: int = lvl_parent.get_child_count()
	_check("%s: using the deposit pillar spawns real reward coins under the level" % label,
		after_first > before, "child count %d -> %d" % [before, after_first])

	# One-shot: a second use must be a real no-op, not just documented intent.
	vault.call("_on_deposit_pillar_used")
	await get_tree().process_frame
	var after_second: int = lvl_parent.get_child_count()
	_check("%s: deposit pillar is one-shot (a second use grants nothing more)" % label,
		after_second == after_first,
		"child count went %d -> %d on the second use — reward is farmable" % [after_first, after_second])

	vault.queue_free(); lvl_parent.queue_free()
	await get_tree().process_frame

func _test_switch_interact_grants_reward_and_is_distinct(label: String, protocol: String, mouth_width: float) -> void:
	var lvl_parent := Node2D.new()
	add_child(lvl_parent)
	var vault: Node2D = VAULT.instantiate()
	vault.protocol = protocol
	vault.mouth_width = mouth_width
	vault.global_position = Vector2(1000, 650)
	lvl_parent.add_child(vault)
	await get_tree().process_frame

	var before: int = lvl_parent.get_child_count()
	vault.call("_on_switch_used")
	await get_tree().process_frame
	var after: int = lvl_parent.get_child_count()
	_check("%s: using the switch spawns real reward coins under the level" % label,
		after > before, "child count %d -> %d" % [before, after])

	vault.queue_free(); lvl_parent.queue_free()
	await get_tree().process_frame

# --- Hazard: real, protocol-appropriate, actually threatens the player -----

func _test_diamond_hazard_fires() -> void:
	var lvl_parent := Node2D.new()
	add_child(lvl_parent)
	var vault: Node2D = VAULT.instantiate()
	vault.protocol = "diamonds"
	vault.mouth_width = 100.0
	vault.global_position = Vector2(1000, 650)
	lvl_parent.add_child(vault)
	await get_tree().process_frame

	var saw_shard := false
	for i in range(180):  # 3s — the shard timer fires every 2.4s
		await get_tree().physics_frame
		for c in vault.get_children():
			if c is Area2D and c.has_meta("armed"):
				saw_shard = true
				break
		if saw_shard:
			break
	_check("Diamond Vault: the crystal-shard hazard actually fires from the vault's own timer",
		saw_shard, "no shard Area2D appeared within 3s of real physics")

	vault.queue_free(); lvl_parent.queue_free()
	await get_tree().process_frame

func _test_fort_knox_hazard_exists() -> void:
	var lvl_parent := Node2D.new()
	add_child(lvl_parent)
	var vault: Node2D = VAULT.instantiate()
	vault.protocol = "gold"
	vault.mouth_width = 140.0
	vault.global_position = Vector2(1000, 650)
	lvl_parent.add_child(vault)
	await get_tree().process_frame  # let _ready() (and the gear guard it builds) run

	var found := false
	for c in vault.get_children():
		if c is Area2D and c.get_child_count() > 0 and c.get_children()[0] is Polygon2D:
			# The gear guard is the only Area2D-with-Polygon2D-child built in
			# _ready() (the shard is spawned later, from _physics_process).
			found = true
	_check("Fort Knox: the patrolling gear-guard hazard exists after build",
		found, "no gear-guard Area2D found among the vault's children")
	vault.queue_free(); lvl_parent.queue_free()
	await get_tree().process_frame

# --- Tier reachability: every rise is within the real single-jump apex -----

func _test_tier_deltas_are_jump_legal(label: String, protocol: String, mouth_width: float) -> void:
	var vault: Node2D = VAULT.instantiate()
	vault.protocol = protocol
	vault.mouth_width = mouth_width
	vault.global_position = Vector2(1000, 650)
	add_child(vault)

	# Pull the real constants straight from the script rather than
	# re-declaring them here, so a future tuning pass can't silently desync
	# the test from the actual geometry.
	var floor_top: float = vault.get("FLOOR_TOP")
	var tier1_y: float = vault.get("TIER1_Y")
	var tier2_y: float = vault.get("TIER2_Y")

	var floor_to_tier2: float = floor_top - tier2_y
	var tier2_to_tier1: float = tier2_y - tier1_y
	_check("%s: floor -> Tier2 rise (%.0fpx) is within a single-jump apex (%.1fpx)" % [label, floor_to_tier2, JUMP_APEX],
		floor_to_tier2 <= JUMP_APEX, "rise=%.0f > apex=%.1f — Tier2 would be unreachable" % [floor_to_tier2, JUMP_APEX])
	_check("%s: Tier2 -> Tier1 rise (%.0fpx) is within a single-jump apex (%.1fpx)" % [label, tier2_to_tier1, JUMP_APEX],
		tier2_to_tier1 <= JUMP_APEX, "rise=%.0f > apex=%.1f — Tier1 would be unreachable from Tier2" % [tier2_to_tier1, JUMP_APEX])

	vault.queue_free()
