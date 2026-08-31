extends Node2D
## Session-4 combat / tool / respawn fixes, each proven with real physics and
## each written to FAIL on the pre-fix behavior:
##   T3  Distributor crystal shard is a VISUALLY DISTINCT shape, not a recolored
##       dot identical to the Stage-1 clipboard.
##   T4a Claim Jumper faces the player even when standing still (was frozen).
##   T4c Claim Jumper dynamite deals real damage to a player standing in the
##       blast (was a no-op because of the physics_frame-before-registration
##       await bug).
##   T5  A NORMAL thrown axe breaks a breakable block (was undetectable — block
##       on World layer only, and _smash_destructible was big-axe-only).
##
## Run: godot --headless res://tests/s4_combat_fixes_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")
const DYNAMITE := preload("res://src/boss/dynamite.tscn")
const BREAKABLE := preload("res://src/level/breakable_block.tscn")
const AXE := preload("res://src/combat/axe.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 4 COMBAT FIXES:")
	await _test_crystal_shard_is_visually_distinct()
	await _test_claim_jumper_faces_player_when_still()
	await _test_dynamite_damages_a_standing_player()
	await _test_normal_axe_breaks_a_block()
	print("S4_COMBAT_FIXES: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _stub_player(at: Vector2) -> CharacterBody2D:
	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nvar hits := 0\nfunc take_damage(_a: int) -> void:\n\thits += 1\n"
	stub.reload()
	var p := CharacterBody2D.new()
	p.set_script(stub)
	p.collision_layer = 2
	p.collision_mask = 0
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 32)
	cs.shape = r
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

## T3 — the crystal shard must carry its own distinct geometry (a Polygon2D
## shard), not merely a recolored fx_dot. The founder's "same as boss 1"
## complaint is that all boss projectiles are the same tinted dot; the fix adds
## a real shard shape and hides the dot.
func _test_crystal_shard_is_visually_distinct() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	var player := _stub_player(Vector2(400, 500))
	boss.global_position = Vector2(0, 400)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	boss.set("current_phase", 1)
	await get_tree().physics_frame
	boss.call("_throw_crystal_shards")
	await get_tree().physics_frame

	var shard: Node = null
	for c in get_children():
		if c.is_in_group("boss_projectile"):
			shard = c
			break
	_check("a crystal shard spawns", shard != null)
	if shard != null:
		# Distinct geometry: a Polygon2D child (the shard shape).
		var has_poly := false
		for c in shard.get_children():
			if c is Polygon2D:
				has_poly = true
		_check("crystal shard carries a distinct Polygon2D shard shape (not just a tinted dot)",
			has_poly, "no Polygon2D child — it would render identical to the Stage-1 clipboard dot")
		# The base dot sprite is hidden (transparent tint).
		var t: Color = shard.get("tint")
		_check("crystal shard's base dot is hidden (tint alpha 0), so only the shard shows",
			t.a == 0.0, "tint=%s — the recolored dot would still show through" % str(t))

	get_tree().call_group("boss_projectile", "queue_free")
	boss.queue_free(); player.queue_free()
	await get_tree().process_frame

## T4a — face the player regardless of velocity. Park the boss stationary with
## the player to his LEFT; his sprite must face left (toward the player), not
## keep a stale right-facing (back turned).
func _test_claim_jumper_faces_player_when_still() -> void:
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape2D.new()
	var fr := RectangleShape2D.new()
	fr.size = Vector2(4000, 80)
	fcs.shape = fr
	floor_body.add_child(fcs)
	floor_body.global_position = Vector2(1000, 900)
	add_child(floor_body)
	boss.global_position = Vector2(1000, 600)
	var player := _stub_player(Vector2(400, 760))  # to the LEFT of the boss
	# A few frames for the facing logic to run; keep him from wandering by
	# muting contact so he doesn't restart the level on the stub player.
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	for i in range(8):
		await get_tree().physics_frame

	var bsprite := boss.get_node("ColorRect")  # BossSprite
	# Player is left, bandit-cart art faces right (art_faces_right true), so to
	# face left the inner sprite must be flipped. set_facing(false) -> flip_h true.
	var inner: Sprite2D = null
	for c in bsprite.get_children():
		if c is Sprite2D:
			inner = c
	_check("Claim Jumper faces the player (left) even while standing still",
		inner != null and inner.flip_h == true,
		"inner flip_h=%s — a frozen/stale facing would show his back" % (str(inner.flip_h) if inner else "no sprite"))

	boss.queue_free(); floor_body.queue_free(); player.queue_free()
	await get_tree().process_frame

## T4c — dynamite must damage a player standing in the blast, immediately, with
## no frame-delay miss.
func _test_dynamite_damages_a_standing_player() -> void:
	var dyn: Node2D = DYNAMITE.instantiate()
	dyn.set("explosion_delay", 0.05)
	add_child(dyn)
	dyn.global_position = Vector2(500, 500)
	var player := _stub_player(Vector2(500, 500))  # dead centre of the blast
	# Wait out the short fuse + a couple frames for the explosion.
	for i in range(12):
		await get_tree().physics_frame
	_check("dynamite blast damages a player standing in it (synchronous, no frame-delay miss)",
		int(player.get("hits")) >= 1,
		"player took %d hits — the await-before-registration bug returns 0" % int(player.get("hits")))
	if is_instance_valid(dyn):
		dyn.queue_free()
	player.queue_free()
	await get_tree().process_frame

## T5 — a NORMAL (non-big) thrown axe breaks a breakable block.
func _test_normal_axe_breaks_a_block() -> void:
	var block: StaticBody2D = BREAKABLE.instantiate()
	block.global_position = Vector2(600, 500)
	add_child(block)
	_check("breakable block is on the Destructible layer (axe-detectable)",
		(block.collision_layer & 128) != 0,
		"collision_layer=%d — without the Destructible bit the axe never sees it" % block.collision_layer)
	await get_tree().physics_frame

	var axe: Area2D = AXE.instantiate()
	axe.set("big", false)      # NORMAL axe, not the big axe
	axe.set("direction", 1.0)
	axe.set("speed", 0.0)      # park it on the block so the overlap is unambiguous
	add_child(axe)
	axe.global_position = Vector2(600, 500)
	# break_block() plays a ~0.25s shatter tween before queue_free(), so detect
	# the break the instant it's TRIGGERED (block starts shrinking / fading /
	# leaves the breakable group) as well as the eventual free — waiting only for
	# the free would race the tween.
	var broke := false
	var base_scale: Vector2 = block.scale
	for i in range(40):
		await get_tree().physics_frame
		await get_tree().process_frame
		if not is_instance_valid(block):
			broke = true
			break
		if block.modulate.a < 0.99 or block.scale != base_scale:
			broke = true
			break
	_check("a NORMAL thrown axe breaks the block (was big-axe-only + wrong layer)",
		broke, "block never began breaking after 40 frames of overlap with a normal axe")
	if is_instance_valid(axe):
		axe.queue_free()
	if is_instance_valid(block):
		block.queue_free()
	await get_tree().process_frame
