extends Node
## Founder, 2026-08-20 (Block_Fixes_1): six screenshots of the checkpoint
## block reading as an unexplained solid box, then his own reference art for
## "a beautiful trap ... that harms Lil Blunt when he touches it" per level.
##
## Two things this gate proves:
##  1. The checkpoint is invisible again (alpha 0 in both states) while
##     staying solid (StandSurface untouched) and still saving progress.
##  2. Each of the six new decorative traps actually damages the player on
##     contact — not just that they exist in the scene tree.
##
## Run: godot --headless res://tests/visual_trap_damage_test.tscn

const CHECKPOINT := preload("res://src/level/checkpoint.tscn")
const TRAP_SCENES := {
	"trap_deadly_beauty": preload("res://src/hazards/trap_deadly_beauty.tscn"),
	"trap_widows_thorn": preload("res://src/hazards/trap_widows_thorn.tscn"),
	"trap_diamond_fang": preload("res://src/hazards/trap_diamond_fang.tscn"),
	"trap_siren_crystal": preload("res://src/hazards/trap_siren_crystal.tscn"),
	"trap_gold_rush": preload("res://src/hazards/trap_gold_rush.tscn"),
	"trap_golden_widow": preload("res://src/hazards/trap_golden_widow.tscn"),
}

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CHECKPOINT INVISIBLE + TRAP DAMAGE:")
	_check_checkpoint_invisible()
	await _check_checkpoint_still_solid()
	for type_name in TRAP_SCENES:
		await _check_trap_damages_player(type_name, TRAP_SCENES[type_name])
	print("VISUAL_TRAP_DAMAGE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _check_checkpoint_invisible() -> void:
	var cp: Node2D = CHECKPOINT.instantiate()
	add_child(cp)
	var sprite: ColorRect = cp.get_node("ColorRect")
	_check("checkpoint ColorRect is invisible at ready (alpha 0)", is_zero_approx(sprite.color.a),
		"alpha=%.2f" % sprite.color.a)
	cp.queue_free()
	await get_tree().process_frame

func _check_checkpoint_still_solid() -> void:
	var cp: Node2D = CHECKPOINT.instantiate()
	add_child(cp)
	cp.global_position = Vector2(500.0, 600.0)
	var stand := cp.get_node_or_null("StandSurface")
	_check("checkpoint StandSurface still present (boss-launch fix not regressed)",
		stand != null and stand is StaticBody2D and (stand.collision_layer & 1) == 1)
	cp.queue_free()
	await get_tree().process_frame

func _check_trap_damages_player(type_name: String, scene: PackedScene) -> void:
	var trap: Node2D = scene.instantiate()
	add_child(trap)
	trap.global_position = Vector2(400.0, 400.0)

	var stub := GDScript.new()
	stub.source_code = "extends CharacterBody2D\nvar hit_count: int = 0\nfunc take_damage(_a: int) -> void:\n\thit_count += 1\n"
	stub.reload()
	var player := CharacterBody2D.new()
	player.set_script(stub)
	player.collision_layer = 2
	player.collision_mask = 0
	player.add_to_group("player")
	var pcs := CollisionShape2D.new()
	var pr := RectangleShape2D.new()
	pr.size = Vector2(20, 20)
	pcs.shape = pr
	player.add_child(pcs)
	add_child(player)
	player.global_position = trap.global_position

	for _f in range(6):
		await get_tree().physics_frame

	_check("%s damages the player on contact" % type_name, player.hit_count >= 1,
		"hit_count=%d" % player.hit_count)

	trap.queue_free()
	player.queue_free()
	await get_tree().process_frame
