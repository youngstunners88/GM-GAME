extends Node
## Gate for the STAGE 3 WEAPON SWAP — golden revolver, not the axe.
##
## Founder lock (2026-09-16, golden Remington reference art): Lil Blunt picks
## up the golden revolver from the smashed bus between the Stage 2 boss video
## and Stage 3 (see stage2_revolver_reveal.gd), so Stage 3's base attack is a
## fired bullet, not a thrown axe.
##
## Founder's explicit instruction: "when he grabs the axe and the hammer just
## changes accordingly" — the pickaxe/bigaxe power-up tiers must still do
## EXACTLY what they do to axe.gd (same damage, same boss-damage caps, same
## big-tier piercing), just skinned as an upgraded shot. So this gate asserts
## parity against axe.gd's own tier constants, not new made-up numbers:
##   * Stage 3 attack spawns a revolver bullet and ZERO axes.
##   * Stage 1 and Stage 2 are unaffected — the swap is gated, not global.
##   * Default / pickaxe / bigaxe damage numbers match axe.gd exactly.
##   * Boss-damage caps match axe.gd exactly (never a one-shot on a boss).
##   * The bullet travels dead straight (no gravity leak) — same standard as
##     the smoke bomb's post-founder-correction gate.
##   * Purple Power in Stage 3 fans three BULLETS, not three axes.
##
## FAILING-FIRST: every assertion below was false before 2026-09-16 — Stage 3
## threw axes and revolver_bullet.tscn did not exist.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/ep3_stage3_golden_revolver_test.tscn

const BULLET := preload("res://src/combat/revolver_bullet.tscn")
const AXE := preload("res://src/combat/axe.tscn")
const PLAYER := preload("res://src/player/player.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


class DummyEnemy extends Area2D:
	var hp: int = 20
	var hits: int = 0
	func _init(is_boss: bool = false) -> void:
		add_to_group("enemy")
		if is_boss:
			add_to_group("boss")
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 16.0
		cs.shape = c
		add_child(cs)
	func take_damage(d: int) -> void:
		hp -= d
		hits += 1


func _count_in_scene(node: Node, script_path: String) -> int:
	var n := 0
	var s: Script = node.get_script()
	if s != null and s.resource_path == script_path:
		n += 1
	for c in node.get_children():
		n += _count_in_scene(c, script_path)
	return n


func _clear_projectiles() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	for path in ["res://src/combat/revolver_bullet.gd", "res://src/combat/axe.gd"]:
		_free_by_script(root, path)


func _free_by_script(node: Node, script_path: String) -> void:
	for c in node.get_children():
		_free_by_script(c, script_path)
	var sc: Script = node.get_script()
	if sc != null and sc.resource_path == script_path:
		node.free()


func _attack_at_stage(stage: int) -> Dictionary:
	GameManager.current_level = stage
	var host := Node2D.new()
	add_child(host)

	var p = PLAYER.instantiate()
	host.add_child(p)
	await get_tree().process_frame

	var handler = p.get_node_or_null("CombatHandler")
	if handler == null:
		for c in p.get_children():
			if c is CombatHandler:
				handler = c
	if handler == null:
		return {"error": "no CombatHandler on the player"}

	var root: Node = get_tree().current_scene
	var before_bullets := _count_in_scene(root, "res://src/combat/revolver_bullet.gd")
	var before_axes := _count_in_scene(root, "res://src/combat/axe.gd")

	handler._throw_axe()
	await get_tree().process_frame

	var res := {
		"bullets": _count_in_scene(root, "res://src/combat/revolver_bullet.gd") - before_bullets,
		"axes": _count_in_scene(root, "res://src/combat/axe.gd") - before_axes,
	}
	host.queue_free()
	await get_tree().process_frame
	_clear_projectiles()
	return res


func _ready() -> void:
	await get_tree().process_frame
	print("EP3 STAGE 3 GOLDEN REVOLVER:")

	# --- 1. the swap, gated by stage --------------------------------------
	var s1: Dictionary = await _attack_at_stage(1)
	_check("Stage 1 attack spawns NO revolver bullet", int(s1.get("bullets", -1)) == 0, str(s1))

	var s2: Dictionary = await _attack_at_stage(2)
	_check("Stage 2 still throws the axe", int(s2.get("axes", 0)) >= 1, str(s2))
	_check("Stage 2 throws no revolver bullet", int(s2.get("bullets", -1)) == 0, str(s2))

	var s3: Dictionary = await _attack_at_stage(3)
	_check("Stage 3 attack spawns a revolver bullet", int(s3.get("bullets", 0)) >= 1, str(s3))
	_check("Stage 3 attack spawns NO axe", int(s3.get("axes", -1)) == 0, str(s3))

	# --- 2. damage tiers match axe.gd exactly ------------------------------
	var default_bullet = BULLET.instantiate()
	add_child(default_bullet)
	await get_tree().process_frame
	var default_axe = AXE.instantiate()
	add_child(default_axe)
	await get_tree().process_frame
	_check("default tier damage matches axe.gd's default",
		default_bullet.damage == default_axe.damage,
		"(bullet %d, axe %d)" % [default_bullet.damage, default_axe.damage])

	var pick_bullet = BULLET.instantiate()
	pick_bullet.heavy = true
	add_child(pick_bullet)
	await get_tree().process_frame
	_check("pickaxe-tier damage matches axe.gd's PICK_DAMAGE",
		pick_bullet.damage == default_axe.PICK_DAMAGE,
		"(bullet %d, axe.PICK_DAMAGE %d)" % [pick_bullet.damage, default_axe.PICK_DAMAGE])

	var big_bullet = BULLET.instantiate()
	big_bullet.big = true
	add_child(big_bullet)
	await get_tree().process_frame
	_check("bigaxe-tier damage matches axe.gd's BIG_DAMAGE",
		big_bullet.damage == default_axe.BIG_DAMAGE,
		"(bullet %d, axe.BIG_DAMAGE %d)" % [big_bullet.damage, default_axe.BIG_DAMAGE])

	# --- 3. boss-damage caps match axe.gd exactly (never a one-shot) ------
	var boss := DummyEnemy.new(true)
	add_child(boss)
	await get_tree().process_frame
	big_bullet._hit(boss)
	_check("BIG tier boss damage matches axe.gd's BIG_BOSS_DAMAGE (never a one-shot)",
		boss.hits == 1 and boss.hp == (20 - default_axe.BIG_BOSS_DAMAGE),
		"(hits %d, hp %d, expected dmg %d)" % [boss.hits, boss.hp, default_axe.BIG_BOSS_DAMAGE])

	var boss2 := DummyEnemy.new(true)
	add_child(boss2)
	await get_tree().process_frame
	pick_bullet._hit(boss2)
	_check("PICK tier boss damage matches axe.gd's PICK_BOSS_DAMAGE",
		boss2.hits == 1 and boss2.hp == (20 - default_axe.PICK_BOSS_DAMAGE),
		"(hits %d, hp %d, expected dmg %d)" % [boss2.hits, boss2.hp, default_axe.PICK_BOSS_DAMAGE])

	# --- 4. straight flight — no gravity leak -------------------------------
	default_bullet.vertical = 0.0
	var y0: float = default_bullet.position.y
	for i in 10:
		default_bullet._physics_process(1.0 / 60.0)
	var y1: float = default_bullet.position.y
	for i in 10:
		default_bullet._physics_process(1.0 / 60.0)
	var y2: float = default_bullet.position.y
	_check("the bullet flies DEAD STRAIGHT — no gravity, no dip",
		y0 == y1 and y1 == y2, "(y %.2f -> %.2f -> %.2f)" % [y0, y1, y2])

	default_bullet.queue_free()
	pick_bullet.queue_free()
	big_bullet.queue_free()
	default_axe.queue_free()
	boss.queue_free()
	boss2.queue_free()

	# --- 5. Purple Power in Stage 3 fans BULLETS ----------------------------
	GameManager.current_level = 3
	var host2 := Node2D.new()
	add_child(host2)
	var p2 = PLAYER.instantiate()
	host2.add_child(p2)
	await get_tree().process_frame
	var h2 = p2.get_node_or_null("CombatHandler")
	if h2 == null:
		for c in p2.get_children():
			if c is CombatHandler:
				h2 = c
	if h2:
		_clear_projectiles()
		var root2: Node = get_tree().current_scene
		var fb := _count_in_scene(root2, "res://src/combat/revolver_bullet.gd")
		var fa := _count_in_scene(root2, "res://src/combat/axe.gd")
		h2._throw_fan()
		await get_tree().process_frame
		var got_b := _count_in_scene(root2, "res://src/combat/revolver_bullet.gd") - fb
		var got_a := _count_in_scene(root2, "res://src/combat/axe.gd") - fa
		_check("Purple fan in Stage 3 fires THREE revolver bullets", got_b == 3, str(got_b))
		_check("...and no axes", got_a == 0, str(got_a))
	host2.queue_free()

	await get_tree().process_frame
	if _fail == 0:
		print("EP3_STAGE3_GOLDEN_REVOLVER: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP3_STAGE3_GOLDEN_REVOLVER: %d FAILED" % _fail)
		get_tree().quit(1)
