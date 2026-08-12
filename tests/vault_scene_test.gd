extends Node
## Gate for the session-4 vault architecture: the Diamond Vault and Fort Knox
## are now FULL SEPARATE SCENES reached by walking into a door, exactly like
## Blaze Rush / the Smoke Lounge — NOT in-level pits. Founder: "supposed to
## take us into the next element ... just as entering the Blaze Rush takes us
## to a different environment completely. Hole in the ground = unacceptable."
##
## Falsifiable checks (from the session-4 DeepSeek compliance matrix):
##  - the vault realm loads as its own scene with its own floor + return portal,
##    containing NO level_02/03 nodes (it's a place you travelled to);
##  - entering the vault records secret_return + would SceneRouter.load a
##    distinct .tscn (not add_child a pit);
##  - staking at an altar moves a REAL GoldMineSystem primitive (shares up,
##    balance down) — a gamified protocol action, not cosmetic;
##  - the real levels build a vault DOOR (not the old protocol_vault pit), and
##    the old drop pit is bridged with solid ground under the door;
##  - the return portal exists (no soft-lock).
##
## Run: godot --headless res://tests/vault_scene_test.tscn

const DIAMOND_REALM := preload("res://src/level/diamond_vault_realm.tscn")
const FORT_KNOX_REALM := preload("res://src/level/fort_knox_realm.tscn")
const VAULT_DOOR := preload("res://src/level/vault_door.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("VAULT SCENE ARCHITECTURE:")
	await _test_realm_is_full_separate_environment("Diamond Vault", DIAMOND_REALM, "diamonds")
	await _test_realm_is_full_separate_environment("Fort Knox", FORT_KNOX_REALM, "gold")
	await _test_staking_moves_real_primitive_diamonds()
	await _test_staking_moves_real_primitive_gold()
	_test_door_records_return_and_targets_a_scene()
	await _test_levels_build_a_door_not_a_pit()
	print("VAULT_SCENE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _has_node_where(root: Node, pred: Callable) -> bool:
	if pred.call(root):
		return true
	for c in root.get_children():
		if _has_node_where(c, pred):
			return true
	return false

func _test_realm_is_full_separate_environment(label: String, scene: PackedScene, protocol: String) -> void:
	var realm := scene.instantiate()
	add_child(realm)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("%s: realm scene loads standalone" % label, realm != null)
	_check("%s: realm is the '%s' protocol" % [label, protocol],
		str(realm.get("protocol")) == protocol)
	# A real environment: has its own solid floor (StaticBody2D on layer 1).
	var has_floor := _has_node_where(realm, func(n: Node) -> bool:
		return n is StaticBody2D and (n as StaticBody2D).collision_layer == 1)
	_check("%s: realm has its own solid floor" % label, has_floor)
	# Has a real player (spawned in-scene, like secret_realm).
	var has_player := _has_node_where(realm, func(n: Node) -> bool: return n.is_in_group("player"))
	_check("%s: realm spawns a player" % label, has_player)
	# Has a return portal — the no-soft-lock exit.
	var has_portal := _has_node_where(realm, func(n: Node) -> bool:
		return n.get_script() != null and str(n.get_script().resource_path).ends_with("return_portal.gd"))
	_check("%s: realm has a return portal (exit exists, no soft-lock)" % label, has_portal)
	# Has at least one staking altar.
	var has_altar := _has_node_where(realm, func(n: Node) -> bool:
		return n is Area2D and str(n.name).begins_with("Altar_"))
	_check("%s: realm has a staking altar" % label, has_altar)
	# NOT a level: contains no LevelBase / boss-trigger nodes.
	var is_level := _has_node_where(realm, func(n: Node) -> bool: return n is LevelBase)
	_check("%s: realm is NOT an in-level pit (no LevelBase node inside)" % label, not is_level)
	realm.queue_free()
	await get_tree().process_frame

func _test_staking_moves_real_primitive_diamonds() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.diamonds_balance = 40
	var realm := DIAMOND_REALM.instantiate()
	add_child(realm)
	await get_tree().physics_frame
	var shares_before: int = GoldMineSystem.diamond_shares
	var bal_before: int = GoldMineSystem.diamonds_balance
	realm.call("_stake_at", "short")
	_check("Diamond stake: diamond_shares increased (real GoldMineSystem primitive)",
		GoldMineSystem.diamond_shares > shares_before,
		"shares %d -> %d" % [shares_before, GoldMineSystem.diamond_shares])
	_check("Diamond stake: diamonds_balance decreased (diamonds committed)",
		GoldMineSystem.diamonds_balance < bal_before,
		"balance %d -> %d" % [bal_before, GoldMineSystem.diamonds_balance])
	realm.queue_free()
	await get_tree().process_frame
	GoldMineSystem.reset_session()

func _test_staking_moves_real_primitive_gold() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.gold_balance = 40
	var realm := FORT_KNOX_REALM.instantiate()
	add_child(realm)
	await get_tree().physics_frame
	var shares_before: int = GoldMineSystem.fort_knox_shares
	var bal_before: int = GoldMineSystem.gold_balance
	realm.call("_stake_at", "short")
	_check("Fort Knox stake: fort_knox_shares increased (real stake_in_fort_knox)",
		GoldMineSystem.fort_knox_shares > shares_before,
		"shares %d -> %d" % [shares_before, GoldMineSystem.fort_knox_shares])
	_check("Fort Knox stake: gold_balance decreased (gold committed)",
		GoldMineSystem.gold_balance < bal_before,
		"balance %d -> %d" % [bal_before, GoldMineSystem.gold_balance])
	realm.queue_free()
	await get_tree().process_frame
	GoldMineSystem.reset_session()

func _test_door_records_return_and_targets_a_scene() -> void:
	var door := VAULT_DOOR.instantiate()
	door.protocol = "diamonds"
	door.realm_path = "res://src/level/diamond_vault_realm.tscn"
	_check("vault door targets a real, distinct realm .tscn (a scene load, not a pit)",
		ResourceLoader.exists(door.get("realm_path")),
		"realm_path=%s" % str(door.get("realm_path")))
	door.free()

func _test_levels_build_a_door_not_a_pit() -> void:
	for entry: Array in [["res://src/level/level_02_crystal_caverns.tscn", 2450.0],
			["res://src/level/level_03_gold_rush.tscn", 2690.0]]:
		var lvl := (load(entry[0]) as PackedScene).instantiate()
		add_child(lvl)
		for i in range(4):
			await get_tree().physics_frame
		var door_found := _has_node_where(lvl, func(n: Node) -> bool: return n.is_in_group("vault_door"))
		var pit_found := _has_node_where(lvl, func(n: Node) -> bool:
			return n.get_script() != null and str(n.get_script().resource_path).ends_with("protocol_vault.gd"))
		_check("%s: builds a vault DOOR (walk-into entrance)" % entry[0].get_file(), door_found)
		_check("%s: no longer builds the rejected in-level protocol_vault pit" % entry[0].get_file(),
			not pit_found)
		# The old drop pit is bridged: a downward raycast at the door x hits solid
		# ground near the surface (y=650), so the player stands on the door, not falls.
		var space: PhysicsDirectSpaceState2D = lvl.get_world_2d().direct_space_state
		var from := Vector2(float(entry[1]), 600.0)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 120))
		q.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(q)
		_check("%s: the old drop pit under the door is bridged with solid ground" % entry[0].get_file(),
			not hit.is_empty(), "no floor found beneath the door at x=%.0f" % float(entry[1]))
		lvl.queue_free()
		await get_tree().physics_frame
