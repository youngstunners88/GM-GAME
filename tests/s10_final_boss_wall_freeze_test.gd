extends Node2D
## S10 T7 REGRESSION — the final boss (Claim Jumper) "frozen statue" bug.
##
## Root cause (Kimi-role audit, confirmed against live constants): when BODY grew
## to 280, `_clamp_to_arena` pins the boss CENTRE at arena_max.x - HALF_BODY, and
## from there `_ledge_ahead`'s probe casts at toe_x + LEDGE_PROBE_MARGIN — 16px
## PAST the arena's own SOLID boundary wall — finds no floor, and reports a
## "ledge". `_ground_chase` then zeros velocity.x every frame (no hop either),
## so the boss FREEZES the instant the chase drives him to a wall. In the ~420px
## reachable band he is always near a wall, so he read as a statue.
##
## These gates FAIL on the pre-fix code (probe past the wall returns "ledge") and
## PASS with the boundary guard, while proving interior ledge protection still
## works.
##
## Run: godot --headless res://tests/s10_final_boss_wall_freeze_test.tscn

const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")

var _fail: int = 0

# Real Gold Rush arena numbers (level_03_gold_rush.gd / level_03_data).
const ARENA_MIN_X := 3700.0
const ARENA_MAX_X := 4400.0
const FLOOR_TOP := 600.0
const BODY := 280.0
const HALF := BODY / 2.0

func _ready() -> void:
	await get_tree().process_frame
	print("S10 FINAL-BOSS WALL FREEZE:")
	await _run()
	print("S10_FINAL_BOSS_WALL_FREEZE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## A solid floor spanning [x0, x1] with its top at FLOOR_TOP, on the World layer.
func _make_floor(x0: float, x1: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var w: float = x1 - x0
	shape.size = Vector2(w, 80.0)
	col.shape = shape
	col.position = Vector2(x0 + w / 2.0, FLOOR_TOP + 40.0)
	body.add_child(col)
	add_child(body)
	return body

## Place a boss with the live arena bounds set (pre-add contract), its centre at
## world x `centre_x`, feet on FLOOR_TOP.
func _make_boss(centre_x: float) -> Node:
	var boss: Node = CLAIM_JUMPER.instantiate()
	boss.arena_min = Vector2(ARENA_MIN_X, FLOOR_TOP - 400.0)
	boss.arena_max = Vector2(ARENA_MAX_X, FLOOR_TOP + 60.0)
	add_child(boss)
	boss.global_position = Vector2(centre_x - HALF, FLOOR_TOP - BODY)
	return boss

func _run() -> void:
	# Floor spans the whole arena and STOPS at each wall — exactly like the real
	# arena, so a probe past a boundary finds no floor (the pre-fix trap).
	var arena_floor := _make_floor(ARENA_MIN_X, ARENA_MAX_X)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 1. EAST wall: boss pinned at arena_max clamp, chasing further east (facing +1)
	#    must NOT read the solid boundary as a ledge.
	var east: Node = _make_boss(ARENA_MAX_X - HALF)  # centre at the east clamp
	await get_tree().physics_frame
	_check("east boundary is NOT treated as a ledge (was the freeze)",
		east.call("_ledge_ahead", 1.0) == false,
		"_ledge_ahead(+1) at the east wall still returns true")
	east.queue_free()

	# 2. WEST wall: symmetric — pinned at arena_min clamp, chasing west (facing -1).
	var west: Node = _make_boss(ARENA_MIN_X + HALF)  # centre at the west clamp
	await get_tree().physics_frame
	_check("west boundary is NOT treated as a ledge",
		west.call("_ledge_ahead", -1.0) == false,
		"_ledge_ahead(-1) at the west wall still returns true")
	west.queue_free()

	# 3. CONTROL — mid-arena on solid floor: there IS floor ahead, so this must
	#    still be false (the guard must not blind him to real ground).
	var mid: Node = _make_boss((ARENA_MIN_X + ARENA_MAX_X) / 2.0)
	await get_tree().physics_frame
	_check("mid-arena flat ground still reads as walkable (not a false ledge)",
		mid.call("_ledge_ahead", 1.0) == false,
		"mid-arena _ledge_ahead(+1) wrongly returned true")
	mid.queue_free()
	await get_tree().physics_frame

	# 4. CONTROL — a genuine INTERIOR pit (floor ends at 4000, well inside the
	#    arena) must STILL be detected as a ledge: ledge-suicide protection lives.
	#    Free the arena-wide floor first so it can't mask the pit under the probe.
	arena_floor.queue_free()
	await get_tree().physics_frame
	var pit_floor := _make_floor(ARENA_MIN_X, 4000.0)  # floor stops mid-arena
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Boss centre at 3950 (well inside the arena, guard does NOT apply here),
	# facing east toward the real pit edge at 4000.
	var at_pit: Node = _make_boss(3950.0)
	await get_tree().physics_frame
	_check("a genuine interior pit is STILL sensed as a ledge (no suicide)",
		at_pit.call("_ledge_ahead", 1.0) == true,
		"interior pit edge not detected — ledge protection broke")
	at_pit.queue_free()
	pit_floor.queue_free()
	await get_tree().physics_frame
