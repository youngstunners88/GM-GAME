extends Node2D
## Regression gate for PROMPT_STAGE3_HUD_PROPS_AXE_RESIDUAL.md (2026-08-17),
## the six founder screenshot defects not already covered by
## stage3_clutter_test / boss_standoff_assay_test:
##
##   1. Solid black SCORE/HUD backing plate — removed from all 3 levels.
##   2. HUD stat text shrunk from 26-30px to 18-22px.
##   3/5. The two mine carts were a bare ColorRect with a genuinely dead
##      board_player()/unboard_player() (zero call sites anywhere) — now real
##      cart art with a working Area2D trigger that actually grants wBTC.
##   6a. timed_door.tscn carried an orphaned static ColorRect+CollisionShape2D
##      duplicate of what the script builds at runtime — and because open()/
##      close() only ever toggled the SCRIPT's own collision shape, that
##      leftover static collider stayed solid forever, permanently blocking
##      the path even while the door visually looked open. Both removed.
##   6b. wbtc/coin_btc collision+visual scale bumped for on-screen clarity.
##
## Also covers a bug a live Playwright playtest capture found AFTER PR #41
## shipped (founder directive PROMPT_VERIFY_PR41_HARD_REFRESH.md): both carts
## snapped to world x~0 on the very first physics tick instead of shuttling
## around their authored spawn position, because the old code wrote
## `position.x = cycle_position * move_distance` — LOCAL position from the
## level origin, discarding wherever EntitySpawner actually placed the cart.
## See `_check_mine_cart_stays_near_spawn()`.
##
## Run: godot --headless res://tests/hud_props_axe_residual_test.tscn

const MINE_CART := preload("res://src/level/mine_cart.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("HUD/PROPS/AXE RESIDUAL:")
	_check_hud_mask_removed()
	_check_hud_font_sizes()
	_check_timed_door_no_orphans()
	_check_wbtc_coin_scale()
	await _check_mine_cart_reward()
	await _check_mine_cart_stays_near_spawn()
	print("HUD_PROPS_AXE_RESIDUAL: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _check_hud_mask_removed() -> void:
	for level_path in [
		"res://src/level/level_01_smoke_realm.tscn",
		"res://src/level/level_02_crystal_caverns.tscn",
		"res://src/level/level_03_gold_rush.tscn",
	]:
		var src := FileAccess.get_file_as_string(level_path)
		_check("%s has no opaque HUDMask backing plate" % level_path.get_file(),
			src.find("HUDMask") == -1,
			"still declares a HUDMask node")

func _check_hud_font_sizes() -> void:
	var src := FileAccess.get_file_as_string("res://src/ui/hud.tscn")
	var lines := src.split("\n")
	var current_node := ""
	for line in lines:
		if line.begins_with("[node name="):
			current_node = line.split("\"")[1]
		if line.strip_edges().begins_with("theme_override_font_sizes/font_size = "):
			var size := int(line.strip_edges().replace("theme_override_font_sizes/font_size = ", ""))
			if current_node == "ScoreLabel":
				_check("ScoreLabel font_size shrunk (<=24, was 30)", size <= 24 and size >= 16,
					"font_size=%d" % size)
			elif current_node == "TokensHeader":
				_check("TokensHeader font_size shrunk (<=16)", size <= 16, "font_size=%d" % size)
			elif current_node.find("Label") != -1:
				_check("%s font_size shrunk (<=20, was 26)" % current_node, size <= 20 and size >= 14,
					"font_size=%d" % size)

func _check_timed_door_no_orphans() -> void:
	var src := FileAccess.get_file_as_string("res://src/level/timed_door.tscn")
	_check("timed_door.tscn has no orphaned static ColorRect", src.find("type=\"ColorRect\"") == -1)
	_check("timed_door.tscn has no orphaned static CollisionShape2D (the one that never toggled with open/close)",
		src.find("CollisionShape2D") == -1)

func _check_wbtc_coin_scale() -> void:
	var wbtc_src := FileAccess.get_file_as_string("res://src/collectibles/wbtc.gd")
	_check("wbtc.gd collision radius enlarged (>=20, was 15)", wbtc_src.find("radius = 20") != -1)
	var coin_src := FileAccess.get_file_as_string("res://src/collectibles/coin_btc.tscn")
	_check("coin_btc.tscn collision enlarged (>=55, was 44)", coin_src.find("size = Vector2(57, 57)") != -1)

## The actual behavioural proof: walk a fake player into a fast mine cart and
## confirm wBTC actually increases — this is the exact "no impact... too
## small to see" complaint, proven false via a real Area2D overlap, not a
## grep. Also confirms the visual is a real Sprite2D (not the old bare
## ColorRect) with a distinct texture per cart type.
func _check_mine_cart_reward() -> void:
	var cart: Node = MINE_CART.instantiate()
	cart.cart_type = 0  # CartType.FAST
	cart.global_position = Vector2(400, 300)
	add_child(cart)
	await get_tree().process_frame
	await get_tree().process_frame

	var visual := cart.get_node_or_null("Sprite2D") if cart.has_node("Sprite2D") else null
	# The runtime-built child isn't named explicitly, so find it by type instead.
	var sprite_child: Sprite2D = null
	for child in cart.get_children():
		if child is Sprite2D:
			sprite_child = child
	_check("mine cart visual is a real Sprite2D (not the old bare ColorRect)", sprite_child != null)
	if sprite_child != null:
		_check("mine cart sprite has a real texture assigned",
			sprite_child.texture != null and sprite_child.texture.resource_path.find("minecart-fast") != -1,
			"texture path=%s" % (sprite_child.texture.resource_path if sprite_child.texture else "null"))

	var trigger := cart.get_node_or_null("BoardTrigger")
	_check("mine cart has a real BoardTrigger Area2D", trigger != null and trigger is Area2D)

	var before: int = GoldMineSystem.wbtc_balance
	var player := CharacterBody2D.new()
	player.collision_layer = 2
	player.collision_mask = 0
	player.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 28)
	cs.shape = r
	player.add_child(cs)
	player.global_position = cart.global_position
	add_child(player)

	# Keep the player pinned to wherever the cart's own cycling motion puts
	# it — the cart drives its own position.x every physics frame (that is
	# real product behaviour, not a test artifact), so a one-time placement
	# would drift out of the trigger before the overlap ever fires.
	for _i in range(10):
		player.global_position = cart.global_position
		await get_tree().physics_frame

	var after: int = GoldMineSystem.wbtc_balance
	_check("walking into the mine cart actually awards wBTC (was dead code, zero call sites)",
		after > before, "before=%d after=%d" % [before, after])

	player.queue_free()
	cart.queue_free()
	await get_tree().process_frame

## Regression for the real bug a live playtest capture found: a cart spawned
## far from the level origin must stay near ITS OWN spawn point, oscillating
## by at most `move_distance`, not collapse toward world x=0.
func _check_mine_cart_stays_near_spawn() -> void:
	var cart: Node = MINE_CART.instantiate()
	cart.cart_type = 1  # CartType.SLOW
	cart.move_distance = 500.0
	var spawn_x := 2400.0
	cart.global_position = Vector2(spawn_x, 280)
	add_child(cart)

	for _i in range(90):  # 1.5s — well past a full departure cycle at this stage
		await get_tree().physics_frame

	var x_after: float = cart.global_position.x
	var drift: float = x_after - spawn_x
	_check("mine cart oscillates around its OWN spawn point, not the level origin",
		drift >= -1.0 and drift <= cart.move_distance + 1.0,
		"spawn_x=%.0f move_distance=%.0f but cart is now at x=%.0f (drift=%.0f) — it collapsed toward world origin"
			% [spawn_x, cart.move_distance, x_after, drift])

	cart.queue_free()
	await get_tree().process_frame
