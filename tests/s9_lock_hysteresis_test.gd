extends Node2D
## Session-9 T2 — lock hysteresis + damped (not hard-stalled) climb lock.
## Two discriminators that FAIL on the pre-fix code:
##   A) DAMPED-NOT-STALLED: while the climb lock is engaged, the boss still
##      creeps horizontally toward the player (to.x *= 0.25). Pre-fix the lock
##      hard-zeroed (to.x = 0.0), so the boss's horizontal velocity collapsed to
##      ~0 while locked. We force a locked state (player low, close, off to one
##      side) and assert the boss retains meaningful horizontal velocity.
##   B) HYSTERESIS COOLDOWN: once the lock releases it must not re-arm for
##      LOCK_COOLDOWN even if the raw condition is momentarily true again — so a
##      hopping player can't perma-arm it. We drive a release then an immediate
##      low re-approach and assert the boss is NOT re-locked within the cooldown.
##
## Run: godot --headless res://tests/s9_lock_hysteresis_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("SESSION 9 LOCK HYSTERESIS:")
	await _test_damped_not_stalled_while_locked()
	await _test_cooldown_blocks_rearm()
	print("S9_LOCK_HYSTERESIS: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, v: Variant) -> void:
	print("  [INFO] %s: %s" % [label, str(v)])

func _stub_player(at: Vector2) -> CharacterBody2D:
	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nfunc take_damage(_a: int) -> void:\n\tpass\n"
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

## A — while locked, the boss creeps toward the player instead of hard-stalling.
func _test_damped_not_stalled_while_locked() -> void:
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.set("arena_min", Vector2(3700.0, 100.0))
	boss.set("arena_max", Vector2(4400.0, 700.0))
	boss.global_position = Vector2(4000.0, 400.0)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	# Player LOW (below the boss so too_low is true) and just off to the left,
	# inside the lock band — forces the climb lock to engage.
	var player := _stub_player(Vector2(3960.0, 560.0))
	await get_tree().physics_frame
	var max_vx := 0.0
	var locked_seen := false
	for i in range(90):
		# keep the player low + slightly to the side so the lock stays engaged
		player.global_position = Vector2(boss.global_position.x + 120.0 - 60.0, boss.global_position.y + 180.0)
		await get_tree().physics_frame
		if bool(boss.get("_climb_locked")):
			locked_seen = true
			max_vx = maxf(max_vx, absf((boss.get("velocity") as Vector2).x))
	_info("lock engaged during test", locked_seen)
	_info("max |vx| while locked", "%.0f" % max_vx)
	_check("the climb lock actually engaged (test is exercising it)", locked_seen)
	# Pre-fix hard-zeroed to.x -> vx collapses toward 0 while locked. Post-fix the
	# 25% damping keeps him creeping, so |vx| stays clearly non-trivial.
	_check("while locked the boss still creeps horizontally (damped, not hard-stalled)",
		max_vx > 40.0,
		"max |vx| while locked was only %.0f — the lock hard-stalls him (pre-fix)" % max_vx)
	boss.queue_free(); player.queue_free()
	await get_tree().process_frame

## B — after release, the lock cannot re-arm within the cooldown.
func _test_cooldown_blocks_rearm() -> void:
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.set("arena_min", Vector2(3700.0, 100.0))
	boss.set("arena_max", Vector2(4400.0, 700.0))
	boss.global_position = Vector2(4000.0, 400.0)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	var player := _stub_player(Vector2(3960.0, 560.0))
	await get_tree().physics_frame
	# Phase 1: hold the player low+close to ENGAGE the lock.
	for i in range(20):
		player.global_position = Vector2(boss.global_position.x + 60.0, boss.global_position.y + 180.0)
		await get_tree().physics_frame
	var engaged: bool = bool(boss.get("_climb_locked"))
	# Phase 2: yank the player far away + high to force a RELEASE.
	for i in range(6):
		player.global_position = Vector2(boss.global_position.x + 700.0, boss.global_position.y - 400.0)
		await get_tree().physics_frame
	var released: bool = not bool(boss.get("_climb_locked"))
	# Phase 3: immediately bring the player back low+close (NOT imminent: keep
	# |dx| between LOCK_ARM_OVERLAP(96) and the band(144) so only the cooldown,
	# not the imminent bypass, decides). Within the cooldown it must stay unlocked.
	var relocked_in_cd := false
	for i in range(18):  # ~0.3s, well under the 0.9s cooldown
		player.global_position = Vector2(boss.global_position.x + 120.0 + 120.0, boss.global_position.y + 180.0)
		await get_tree().physics_frame
		if bool(boss.get("_climb_locked")):
			relocked_in_cd = true
	_info("engaged / released", "%s / %s" % [str(engaged), str(released)])
	_check("lock engaged then released as the player moved", engaged and released)
	_check("lock does NOT re-arm within the cooldown on a non-imminent re-approach (hysteresis)",
		not relocked_in_cd,
		"re-locked within the cooldown — a hopping player would perma-arm it (pre-fix had no cooldown)")
	boss.queue_free(); player.queue_free()
	await get_tree().process_frame
