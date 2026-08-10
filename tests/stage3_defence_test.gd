extends Node2D
## Stage 3 defence-of-the-realm gates.
##
## Founder: "There is a massive glistch with the final boss as he is fucking
## dumb and dies by falling off the ledge. The gnome characters also are
## stupid and fall off ledges automatically... The boss falls off the ledge and
## then Lil Blunt is unable to deal with him so the game cannot proceed."
##
## Both are measured under REAL physics on a REAL platform with a REAL void
## beside it — not by reading the AI code.

const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")
const TAX_COLLECTOR := preload("res://src/enemies/tax_collector.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("STAGE 3 DEFENCE:")
	await _test_boss_does_not_walk_off_a_ledge()
	await _test_boss_arena_clamp_catches_a_fall()
	await _test_gnome_does_not_walk_off_a_ledge()
	_test_big_axe_survives_another_powerup()
	print("STAGE3_DEFENCE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## A single platform ending at `edge_x`, with nothing beyond it.
func _make_ledge(edge_x: float, y: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1200, 80)
	cs.shape = rect
	cs.position = Vector2(edge_x - 600.0, y + 40.0)
	body.add_child(cs)
	add_child(body)
	return body

func _make_player(at: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.collision_layer = 2
	p.collision_mask = 0
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 32)
	cs.shape = r
	cs.position = Vector2(16, 16)
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

func _test_boss_does_not_walk_off_a_ledge() -> void:
	var edge_x := 1000.0
	var floor_y := 600.0
	var ledge := _make_ledge(edge_x, floor_y)
	# Player parked in the VOID past the edge — maximum temptation to walk off.
	var player := _make_player(Vector2(edge_x + 400.0, floor_y - 40.0))
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	boss.global_position = Vector2(edge_x - 300.0, floor_y - 80.0)
	for i in 240:
		await get_tree().physics_frame

	_check("boss did not fall into the void chasing a player across a gap",
		boss.global_position.y < floor_y + 200.0,
		"boss y = %.0f (floor %.0f)" % [boss.global_position.y, floor_y])
	_check("boss is still alive and fightable",
		is_instance_valid(boss) and not bool(boss.get("is_dead")))

	boss.queue_free(); player.queue_free(); ledge.queue_free()
	await get_tree().physics_frame

func _test_boss_arena_clamp_catches_a_fall() -> void:
	# No floor at all: only the arena clamp can save him.
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	boss.global_position = Vector2(4050, 500)
	boss.set("arena_min", Vector2(3790, 100))
	boss.set("arena_max", Vector2(4310, 560))
	for i in 180:
		await get_tree().physics_frame
	_check("arena clamp stops the boss falling out of the world with no floor",
		boss.global_position.y <= 561.0,
		"boss y = %.0f, clamp max 560" % boss.global_position.y)
	_check("arena clamp keeps the boss inside the arena horizontally",
		boss.global_position.x >= 3789.0 and boss.global_position.x <= 4311.0,
		"boss x = %.0f" % boss.global_position.x)
	boss.queue_free()
	await get_tree().physics_frame

func _test_gnome_does_not_walk_off_a_ledge() -> void:
	var edge_x := 1000.0
	var floor_y := 600.0
	var ledge := _make_ledge(edge_x, floor_y)
	var gnome: Node2D = TAX_COLLECTOR.instantiate()
	add_child(gnome)
	# Patrolling toward the edge with no player anywhere near.
	gnome.global_position = Vector2(edge_x - 200.0, floor_y - 32.0)
	await get_tree().physics_frame
	gnome.set("patrol_distance", 4000.0)
	gnome.set("moving_right", true)
	for i in 300:
		await get_tree().physics_frame
	_check("gnome patrol turns at the ledge instead of walking into the void",
		gnome.global_position.y < floor_y + 200.0,
		"gnome y = %.0f (floor %.0f)" % [gnome.global_position.y, floor_y])
	gnome.queue_free(); ledge.queue_free()
	await get_tree().physics_frame

func _test_big_axe_survives_another_powerup() -> void:
	# Founder: collecting the big axe "doesnt let him throw the huge axe".
	# current_power_up is a single slot, so ANY later pickup used to silently
	# cancel it. Drive the real activation path, then pick up something else.
	GameManager.activate_power_up("bigaxe", 25.0)
	_check("big axe is active right after pickup", GameManager.has_power_up("bigaxe"))
	GameManager.activate_power_up("big", 10.0)   # a magic mushroom
	_check("big axe SURVIVES collecting another power-up",
		GameManager.has_power_up("bigaxe"),
		"a mushroom cancelled the axe — the single-slot bug")
	GameManager.activate_power_up("blaze", 12.0)
	_check("big axe survives a weed leaf too", GameManager.has_power_up("bigaxe"))
	GameManager.big_axe_timer = 0.0
	_check("big axe expires on its own timer", not GameManager.has_power_up("bigaxe"))
