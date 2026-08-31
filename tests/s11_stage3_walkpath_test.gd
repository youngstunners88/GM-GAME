extends Node2D
## S11 — Stage 3 main-path WALKABILITY probe.
##
## The founder is highly sensitive to "forced to jump on flat ground" walk-blocks,
## and the S11 layout redesign made the main ground continuous where it used to
## have gaps — which risked turning the old pit-secret walls into chest-high
## blocks on the flat run. This probe proves the walk CORRIDOR (the band the
## player's standing box occupies, y≈615–645, just above the y=650 floor) is
## clear of any solid (layer-1) collider across every flat ground span. A secret
## wall, prop, or stray StaticBody intruding into that band is a hard FAIL.
##
## It also asserts the two 220px+ unfair gaps from the OLD layout are gone
## (every main-path gap ≤170, single-jump-legal).
##
## Run: godot --headless res://tests/s11_stage3_walkpath_test.tscn

const LEVEL := preload("res://src/level/level_03_gold_rush.tscn")

var _fail: int = 0

# New flat ground spans (x0, x1) — sample INSIDE these, away from the gate/door.
const FLAT_SPANS := [
	Vector2(40, 540), Vector2(720, 1200), Vector2(1340, 1500),
	Vector2(1680, 2600), Vector2(2780, 3540),
]
# Set-piece x's to skip (gate/door/pit — legitimately not flat walk corridor).
const FLOOR_Y := 650.0

func _ready() -> void:
	await get_tree().process_frame
	print("S11 STAGE 3 WALKPATH:")
	await _run()
	print("S11_STAGE3_WALKPATH: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	var level: Node = LEVEL.instantiate()
	add_child(level)
	# Let the level build its geometry + props and settle a few physics frames.
	for _i in range(6):
		await get_tree().physics_frame

	var space := get_world_2d().direct_space_state
	# The player's standing box is 32x32 with its top ~618 when grounded on y=650.
	# Probe a band JUST ABOVE the floor (y 615..645) so the floor itself (650+)
	# never registers, but any ground-line blocker (a secret wall at ~586..618,
	# a stray prop) does.
	var probe := RectangleShape2D.new()
	probe.size = Vector2(20.0, 26.0)   # x±10, y±13 -> covers 615..641 at centre 628
	var blockers: Array[String] = []
	for span: Vector2 in FLAT_SPANS:
		var x: float = span.x
		while x <= span.y:
			var params := PhysicsShapeQueryParameters2D.new()
			params.shape = probe
			params.transform = Transform2D(0.0, Vector2(x, 628.0))
			params.collision_mask = 1          # World geometry only
			params.collide_with_bodies = true
			var hits := space.intersect_shape(params, 4)
			if not hits.is_empty():
				# Identify the intruding node for the failure message.
				var names := ""
				for h in hits:
					var c = h.get("collider")
					if c and is_instance_valid(c):
						names += c.name + "(" + c.get_class() + ") "
				blockers.append("x=%.0f: %s" % [x, names])
			x += 60.0
	_check("main-path walk corridor is clear of blockers on every flat span",
		blockers.is_empty(), "blockers -> " + "; ".join(blockers))

	# Gap fairness: the redesign's gaps are all ≤170 (single-jump-legal). Assert
	# no two consecutive flat spans leave a gap > 170 (the old layout had 220s).
	var data = level.get("level_data")
	var segs: Array = data.ground_segments
	# Sort by x, then check consecutive gaps.
	var xs: Array = []
	for s in segs:
		xs.append(Vector2(s.x, s.x + s.z))
	xs.sort_custom(func(a, b): return a.x < b.x)
	var worst := 0.0
	var worst_at := 0.0
	for i in range(xs.size() - 1):
		var gap: float = xs[i + 1].x - xs[i].y
		if gap > worst:
			worst = gap
			worst_at = xs[i].y
	# The Fort Knox vault pit (2620..2760) is BRIDGED in the script, so a raw
	# 140 gap there is walkable; every raw gap is ≤170 regardless.
	_check("every main-path ground gap is <=170px (single-jump-legal; no 220s)",
		worst <= 170.0, "worst raw gap %.0fpx at x=%.0f" % [worst, worst_at])

	level.queue_free()
	await get_tree().process_frame
