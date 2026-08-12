extends Node2D
## Regression test for "Lil Blunt will die completely without even touching
## the boss for some reason" (founder, L1 — but the same bug existed on the
## Stage 2 boss too).
##
## Root cause (Kimi K3, verified by hand against the actual .tscn + .gd):
## auditor.gd/distributor.gd's _ready() used to move the Hitbox Area2D itself
## to (BODY/2, BODY/2) ON TOP OF the Hitbox/CollisionShape2D child, which
## already carried that same offset in the .tscn — stacking both put the
## hurtbox's true centre a full half-body diagonally off the visible sprite.
## The kill zone covered air well past the boss's right/bottom edge while his
## left/top half could be stood inside with no death at all.
##
## This checks the GEOMETRY directly (exact, deterministic, independent of
## physics timing) — the hurtbox's real world-space rect must sit close to
## the boss's own body box, not offset by an extra half-body — and then
## proves genuine contact still ends the run via the real GameManager path,
## the same way tests/boss_stakes_test.gd proves the general stakes rule.
##
## Run: godot --headless res://tests/boss_ghost_death_hurtbox_test.tscn

const AUDITOR := preload("res://src/boss/auditor.tscn")
const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BOSS GHOST-DEATH HURTBOX GEOMETRY:")
	_test_hurtbox_geometry("Auditor (L1)", AUDITOR, 168.0)
	_test_hurtbox_geometry("Distributor (L2)", DISTRIBUTOR, 240.0)
	await _test_real_contact_still_kills()
	print("BOSS_GHOST_DEATH_HURTBOX: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## The bug's exact signature: the hurtbox shape's centre, in the boss's own
## local space, must be close to the body box's own centre (BODY/2, BODY/2)
## — NOT shifted a further BODY/2 away (which is what double-applying the
## offset produced: centre at (BODY, BODY) instead of (BODY/2, BODY/2)).
func _test_hurtbox_geometry(label: String, scene: PackedScene, body: float) -> void:
	var boss: Node2D = scene.instantiate()
	add_child(boss)
	var hitbox := boss.get_node("Hitbox") as Area2D
	var shape_node := hitbox.get_node("CollisionShape2D") as CollisionShape2D
	# World-space centre of the hurtbox shape.
	var shape_centre: Vector2 = hitbox.global_position + shape_node.position
	var body_centre: Vector2 = boss.global_position + Vector2(body / 2.0, body / 2.0)
	var drift: float = shape_centre.distance_to(body_centre)
	_check("%s: hurtbox centre stays near the body's own centre (no double offset)" % label,
		drift < body * 0.35,
		"hurtbox centre %s vs body centre %s — drifted %.0fpx (body=%.0f); the double-offset bug put this at a full half-body away"
			% [str(shape_centre), str(body_centre), drift, body])
	# The hurtbox must not be larger than the body box either — it should be
	# trimmed to the visible art, not merely re-centred.
	var shape: RectangleShape2D = shape_node.shape
	_check("%s: hurtbox is not larger than the body box (trimmed to visible art)" % label,
		shape.size.x <= body and shape.size.y <= body,
		"hurtbox size %s vs body %.0fx%.0f" % [str(shape.size), body, body])
	boss.queue_free()

## Real GameManager path: a player who genuinely overlaps the (now-corrected)
## hurtbox must still lose the run, exactly like tests/boss_stakes_test.gd
## already proves for the general case. This is the "contact -> normal rules
## only" half of the founder's gate; the geometry test above is the "no
## contact -> no death" half.
func _test_real_contact_still_kills() -> void:
	Engine.time_scale = 1.0
	GameManager.reset_boss_restart_flag()
	GameManager.total_score = 500
	var boss: Node2D = AUDITOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(1000, 500)

	# A script-less CharacterBody2D has no take_damage() method, and
	# _on_hitbox_body_entered() requires one before it will act on contact at
	# all — so a stand-in without it silently never triggers the restart,
	# regardless of overlap.
	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nfunc take_damage(_amount: int) -> void:\n\tpass\n"
	stub.reload()
	var player := CharacterBody2D.new()
	player.set_script(stub)
	player.collision_layer = 2
	player.collision_mask = 0
	player.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 32)
	cs.shape = r
	cs.position = Vector2(16, 16)
	player.add_child(cs)
	# Centre the player squarely inside the CORRECTED hurtbox (local centre
	# ~(86,80) on a 168-body boss), which genuinely overlaps the visible art.
	player.global_position = Vector2(1000 + 86 - 16, 500 + 80 - 16)
	add_child(player)

	for i in range(10):
		await get_tree().physics_frame

	_check("player standing inside the boss's real silhouette DOES trigger boss_contact_restart",
		GameManager.total_score == 0,
		"score is %d — genuine contact stopped ending the run" % GameManager.total_score)

	boss.queue_free()
	player.queue_free()
	GameManager.reset_boss_restart_flag()
	await get_tree().process_frame
