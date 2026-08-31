extends Node
## Founder hard-refresh (2026-08-25): "the boss walks through EVERYTHING." The
## previous version of this gate was GAMEABLE — it measured raycasts (which ignore
## collision exceptions), so it went green while the live boss phased straight
## through the platforms. This version measures the boss's ACTUAL BODY overlap
## against the real WALL platforms, so a boss that ghosts them FAILS.
##
## The shipped design (see auditor.gd): the boss is SOLID against every chase-lane
## wall at ALL times (no runtime collision phasing — every phase-toggle scheme
## either ghosted the level or wedged him inside a 20px deck), and clears them
## with a sized SOLID jump; overhead platforms (above his grounded head) are
## excepted once at spawn so his jump-arc can't clip their undersides and stall.
##
## Level 1's real chase-lane WALLS (band intersects his grounded body, feet 650 /
## head 430): (1100,450), (300,500) and the breakable block (1850,500). This gate
## drives Lil Blunt fleeing the whole stage west and asserts:
##   A. His grounded body is essentially NEVER inside a wall (no ground-level
##      walk-through of the platforms Lil Blunt hides behind) — the founder's fix.
##   B. The walls genuinely BLOCK him (planted-at-a-wall beats > 0 = spacing).
##   C. He still CLOSES the fled player (chase works).
##   D. He never wedges (no runaway downward velocity, no multi-second freeze).
##
## Run: godot --headless res://tests/auditor_solid_wall_traverse_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")
const BODY := 220.0
const GROUNDED_HEAD_Y := 430.0   # Level 1 ground y=650 minus BODY.

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR SOLID-WALL TRAVERSE:")
	await _run()
	print("AUDITOR_SOLID_WALL_TRAVERSE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _platform_rect(pl: Node) -> Rect2:
	for c in pl.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
			var sz: Vector2 = ((c as CollisionShape2D).shape as RectangleShape2D).size
			return Rect2((pl as Node2D).global_position + (c as CollisionShape2D).position - sz * 0.5, sz)
	return Rect2()

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(2900.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame
	var boss := level.get_node_or_null("Auditor") as Node2D
	if boss == null:
		_check("Auditor spawned", false)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	# The real chase-lane WALLS: soft platforms whose band reaches his grounded
	# body (bottom below his head). Overhead platforms are excluded — he passes
	# under/through those and they are not what Lil Blunt hides behind.
	var wall_rects: Array = []
	for pl in get_tree().get_nodes_in_group("boss_soft_platform"):
		var r: Rect2 = _platform_rect(pl)
		if r.size != Vector2.ZERO and (r.position.y + r.size.y) > GROUNDED_HEAD_Y + 6.0:
			wall_rects.append(r)
	_check("Level 1 exposes real chase-lane walls to test", wall_rects.size() >= 2,
		"only %d wall platforms found" % wall_rects.size())

	var ground_in_wall := 0
	var blocked_beats := 0
	var was_blocked := false
	var last_x: float = boss.global_position.x
	var stuck := 0
	var max_stuck := 0
	var max_abs_vy := 0.0
	var n := 2600
	for f in range(n):
		var t: float = float(f) / 60.0
		player.global_position = Vector2(maxf(150.0, 2900.0 - t * 80.0), 500.0)
		if not is_instance_valid(boss):
			_check("Auditor survives the pursuit", false, "freed mid-run")
			return
		var grounded: bool = bool(boss.call("is_on_floor"))
		# A: grounded body inside a WALL platform = a real ground-level walk-through.
		if grounded:
			var bp := Rect2(boss.global_position, Vector2(BODY, BODY)).grow(-8.0)
			for r: Rect2 in wall_rects:
				if bp.intersects(r):
					ground_in_wall += 1
					break
		# B: blocked beat — grounded, stalled, a wall right ahead.
		var blk: bool = grounded and absf(boss.velocity.x) < 40.0
		if blk and not was_blocked:
			blocked_beats += 1
		was_blocked = blk
		# D: wedge signatures.
		max_abs_vy = maxf(max_abs_vy, absf(boss.velocity.y))
		if absf(boss.global_position.x - last_x) < 2.0:
			stuck += 1
			max_stuck = maxi(max_stuck, stuck)
		else:
			stuck = 0
		last_x = boss.global_position.x
		await get_tree().physics_frame

	var gap: float = absf(boss.global_position.x - player.global_position.x)
	print("  [INFO] ground-inside-wall=%d/%d (%.1f%%) blocked_beats=%d gap=%.0f max_stuck=%d max_abs_vy=%.0f"
		% [ground_in_wall, n, 100.0 * ground_in_wall / n, blocked_beats, gap, max_stuck, max_abs_vy])

	# A: essentially never inside a wall on the ground. A small transient budget
	# (<2%) covers a frame or two of landing depenetration; a boss that ghosts the
	# walls sits at tens of percent (measured 26-83% on the broken builds).
	_check("A. Grounded body ~never inside a spacing WALL (no ground walk-through)",
		ground_in_wall < int(0.02 * n), "inside a wall %d frames (%.1f%%)" % [ground_in_wall, 100.0 * ground_in_wall / n])
	_check("B. The walls actually BLOCK him (planted beats > 0 = spacing)",
		blocked_beats > 0, "0 blocked beats")
	_check("C. Closes to striking distance of a fully-fled player (gap < 400px)",
		gap < 400.0, "gap=%.0f" % gap)
	_check("D. Never wedges (no runaway velocity, no multi-second freeze)",
		max_abs_vy < 2000.0 and max_stuck < 300,
		"max_abs_vy=%.0f max_stuck=%d" % [max_abs_vy, max_stuck])

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
