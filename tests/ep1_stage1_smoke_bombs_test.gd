extends Node
## Gate for the STAGE 1 WEAPON SWAP — smoke bombs, not axes.
##
## Founder lock (2026-09-14,
## `artifacts/PROMPT_2026-09-14_STAGE1_SMOKE_BOMBS_NOT_AXES.md`): Lil Blunt
## does not throw axes in Stage 1, because he only finds the pickaxe / mining
## gear AFTER beating the Stage 1 Tax Collector. Stage 1's attack is a thrown
## smoke bomb; Stage 2 keeps the axe; Stage 3's big axe / hammer are untouched.
##
## The brief's own warning is what shapes this gate: **"Do not 'fix' this by
## hiding the axe poorly. Replace the Stage 1 projectile for real."** So the
## assertions are about what actually SPAWNS and whether it actually DAMAGES,
## not about what is drawn:
##
##   * Stage 1 attack spawns a smoke bomb and ZERO axes.
##   * Stage 2 and Stage 3 still spawn axes — the swap is gated, not global.
##   * The bomb damages an ordinary enemy AND a boss, so the Auditor fight is
##     still winnable with the only weapon Stage 1 gives you. A weapon that
##     cannot hurt the boss would soft-lock the whole episode.
##   * Purple Power in Stage 1 fans three BOMBS, not three axes.
##   * The bomb travels DEAD STRAIGHT — no gravity, no dip, no lob. Founder
##     playtest (2026-09-16) explicitly REJECTED a prior version of this gate
##     that asserted the opposite (that the bomb "ARCS"). A build that leaks
##     gravity onto this projectile again must fail this gate.
##   * A hit spawns the green smoke explosion VFX — a real, visible burst,
##     not the old 5-puff impact that reused a damaging projectile as its own
##     impact effect.
##   * The impact puff does NOT damage. smoke_puff is itself a damaging
##     projectile (Blaze Mode's auto-puff); if the bomb's impact VFX ever
##     reused that wiring, the "same weight class as the axe" claim would be
##     false by a large factor.
##
## FAILING-FIRST: every assertion below was false before 2026-09-14 — Stage 1
## threw axes and `smoke_bomb.tscn` did not exist. The straight-flight and
## explosion-VFX assertions were added 2026-09-16 to gate the founder's
## playtest correction (the 2026-09-14 build shipped with an arc, which was
## then explicitly rejected).
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/ep1_stage1_smoke_bombs_test.tscn

const BOMB := preload("res://src/combat/smoke_bomb.tscn")
const PUFF := preload("res://src/effects/smoke_puff.tscn")
const EXPLOSION_SCRIPT := "res://src/effects/one_shot_effect.gd"
const PLAYER := preload("res://src/player/player.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


## A stand-in enemy: the real contract a projectile sees is `enemy` group +
## take_damage(). Using a dummy keeps the gate about the WEAPON rather than
## about any one enemy's AI.
class DummyEnemy extends Area2D:
	var hp: int = 10
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


## Remove every live projectile from the scene.
##
## Load-bearing between stages. Projectiles are added to
## `get_tree().current_scene`, NOT to the player — so freeing the player host
## leaves them behind, and the first version of this gate counted a Stage 1
## bomb again while checking Stage 2 and reported a failure the code did not
## have. Counting deltas (below) makes that impossible, and this makes the
## numbers readable while debugging.
func _clear_projectiles() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	for path in ["res://src/combat/smoke_bomb.gd", "res://src/combat/axe.gd"]:
		_free_by_script(root, path)


func _free_by_script(node: Node, script_path: String) -> void:
	for c in node.get_children():
		_free_by_script(c, script_path)
	var sc: Script = node.get_script()
	if sc != null and sc.resource_path == script_path:
		node.free()


## Drive one real attack press through the real CombatHandler at a given stage,
## and report what it spawned into the scene.
##
## Counts are DELTAS across the press, not absolute totals — see
## `_clear_projectiles()` for why an absolute count lies.
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
	var before_b := _count_in_scene(root, "res://src/combat/smoke_bomb.gd")
	var before_a := _count_in_scene(root, "res://src/combat/axe.gd")

	handler._throw_axe()          # the base attack entry point
	await get_tree().process_frame

	var res := {
		"bombs": _count_in_scene(root, "res://src/combat/smoke_bomb.gd") - before_b,
		"axes": _count_in_scene(root, "res://src/combat/axe.gd") - before_a,
	}
	host.queue_free()
	await get_tree().process_frame
	_clear_projectiles()
	return res


func _ready() -> void:
	await get_tree().process_frame
	print("EP1 STAGE 1 SMOKE BOMBS:")

	# --- 1. the swap, gated by stage --------------------------------------
	var s1: Dictionary = await _attack_at_stage(1)
	_check("Stage 1 attack spawns a smoke bomb", int(s1.get("bombs", 0)) >= 1, str(s1))
	_check("Stage 1 attack spawns NO axe", int(s1.get("axes", -1)) == 0, str(s1))

	var s2: Dictionary = await _attack_at_stage(2)
	_check("Stage 2 still throws the axe", int(s2.get("axes", 0)) >= 1, str(s2))
	_check("Stage 2 throws no smoke bomb", int(s2.get("bombs", -1)) == 0, str(s2))

	var s3: Dictionary = await _attack_at_stage(3)
	_check("Stage 3 weapons unchanged (still axe)", int(s3.get("axes", 0)) >= 1, str(s3))

	# --- 2. it actually kills things --------------------------------------
	var bomb = BOMB.instantiate()
	add_child(bomb)
	var mob := DummyEnemy.new(false)
	add_child(mob)
	await get_tree().process_frame
	bomb._hit(mob)
	_check("a smoke bomb damages an ordinary enemy", mob.hits == 1 and mob.hp == 9,
		"(hits %d, hp %d)" % [mob.hits, mob.hp])

	var boss := DummyEnemy.new(true)
	add_child(boss)
	await get_tree().process_frame
	bomb._hit(boss)
	# The Auditor is the Stage 1 boss and the smoke bomb is the only weapon
	# Stage 1 hands you. If this ever returns 0 damage, Episode 1 is
	# unfinishable — which is a soft-lock, not a balance note.
	_check("a smoke bomb damages the BOSS (Auditor must stay killable)",
		boss.hits == 1 and boss.hp == 9, "(hits %d, hp %d)" % [boss.hits, boss.hp])
	_check("same weight class as the axe it replaced (1 damage)", bomb.damage == 1,
		str(bomb.damage))

	# --- 3. straight flight — no gravity leak -------------------------------
	# Founder-mandated gate (2026-09-16): fails if Y velocity grows after
	# spawn. `vertical` is a constant drift term (fan spread), so with
	# vertical == 0 the Y position must never move at all across many physics
	# steps; with a nonzero vertical it must move at a CONSTANT rate (no
	# acceleration), which the two-sample check below proves.
	bomb.vertical = 0.0
	var y0: float = bomb.position.y
	for i in 10:
		bomb._physics_process(1.0 / 60.0)
	var y1: float = bomb.position.y
	for i in 10:
		bomb._physics_process(1.0 / 60.0)
	var y2: float = bomb.position.y
	_check("the bomb flies DEAD STRAIGHT — no gravity, no dip",
		y0 == y1 and y1 == y2, "(y %.2f -> %.2f -> %.2f)" % [y0, y1, y2])

	bomb.vertical = 40.0
	var vy_start: float = bomb.position.y
	for i in 10:
		bomb._physics_process(1.0 / 60.0)
	var vy_delta_a: float = bomb.position.y - vy_start
	var vy_mid: float = bomb.position.y
	for i in 10:
		bomb._physics_process(1.0 / 60.0)
	var vy_delta_b: float = bomb.position.y - vy_mid
	_check("fan-spread vertical drift is CONSTANT velocity, not accelerating (gravity leak check)",
		absf(vy_delta_a - vy_delta_b) < 0.01,
		"(delta_a %.4f, delta_b %.4f)" % [vy_delta_a, vy_delta_b])

	# --- 3b. a hit spawns a real, visible explosion, not a tiny puff --------
	var root3: Node = get_tree().current_scene
	var fx_before := _count_in_scene(root3, EXPLOSION_SCRIPT)
	bomb._burst()
	await get_tree().process_frame
	var fx_after := _count_in_scene(root3, EXPLOSION_SCRIPT)
	_check("a hit spawns the green smoke explosion VFX", fx_after > fx_before,
		"(before %d, after %d)" % [fx_before, fx_after])

	mob.queue_free()
	boss.queue_free()

	# --- 4. the impact puff must not deal a second helping of damage -------
	var harmful = PUFF.instantiate()
	add_child(harmful)
	await get_tree().process_frame
	_check("a normal smoke puff IS a damaging projectile (Blaze Mode)",
		harmful.is_in_group("projectile"))
	harmful.queue_free()

	var vfx = PUFF.instantiate()
	vfx.harmless = true
	add_child(vfx)
	await get_tree().process_frame
	_check("the bomb's impact puff is pure VFX and deals no damage",
		not vfx.is_in_group("projectile"))
	vfx.queue_free()

	# --- 5. Purple Power in Stage 1 fans BOMBS ------------------------------
	GameManager.current_level = 1
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
		var fb := _count_in_scene(root2, "res://src/combat/smoke_bomb.gd")
		var fa := _count_in_scene(root2, "res://src/combat/axe.gd")
		h2._throw_fan()
		await get_tree().process_frame
		var got_b := _count_in_scene(root2, "res://src/combat/smoke_bomb.gd") - fb
		var got_a := _count_in_scene(root2, "res://src/combat/axe.gd") - fa
		_check("Purple fan in Stage 1 throws THREE smoke bombs", got_b == 3, str(got_b))
		_check("...and no axes", got_a == 0, str(got_a))
	host2.queue_free()

	await get_tree().process_frame
	if _fail == 0:
		print("EP1_STAGE1_SMOKE_BOMBS: ALL PASS")
		get_tree().quit(0)
	else:
		print("EP1_STAGE1_SMOKE_BOMBS: %d FAILED" % _fail)
		get_tree().quit(1)
