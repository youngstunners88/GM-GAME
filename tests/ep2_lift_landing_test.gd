extends Node
## EP2 LIFT LANDING (P1-7, founder 2026-11-22 image4: "there needs to be at least 2 steps before getting onto the platform so that there
## isnt the random black gap"). The real MineLift chamber: from the bridge to the cage door, every 10 cm across the bridge lane, and across
## the whole shaft mouth, a board's top sits at the walking height (y 0 within 5 cm): no strip where the eye falls into the pit.
## Run: godot --headless res://tests/ep2_lift_landing_test.tscn
var failures := 0

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


## Tops of every visible mesh box near the walking height, as [Rect2 (x, z), top y].
func _decks(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.end.y < -0.12 or box.end.y > 0.12 or box.size.y > 1.0:
			continue
		out.append([Rect2(box.position.x, box.position.z, box.size.x, box.size.z), box.end.y])
	return out


## The highest deck top under (x, z), or NAN when nothing covers it.
func _top(decks: Array, x: float, z: float) -> float:
	var best: float = NAN
	for d in decks:
		if (d[0] as Rect2).has_point(Vector2(x, z)) and (is_nan(best) or float(d[1]) > best):
			best = float(d[1])
	return best


func _ready() -> void:
	await get_tree().process_frame
	print("EP2 LIFT LANDING:")
	var lift: MineLiftChamber = load("res://src/episode2/chamber/mine_lift.tscn").instantiate()
	add_child(lift)
	lift.setup()
	lift.set_process(false)
	lift.set_physics_process(false)
	await get_tree().process_frame
	var decks: Array = _decks(lift)
	check("the sill's two treads are built (both rows, full shaft width)", lift.find_children("ShaftSill_*", "", true, false).size() == 6)
	var holes: Array = []
	var worst: float = 0.0
	var z: float = -7.0
	while z <= -MineLiftChamber.CAGE_HALF:
		var x: float = -1.2
		while x <= 1.21:
			var t: float = _top(decks, x, z)
			if is_nan(t):
				holes.append("(%.1f, %.1f)" % [x, z])
			else:
				worst = maxf(worst, absf(t))
			x += 0.2
		z += 0.1
	check("bridge -> sill -> landing -> cage door: a board under every 10 cm of the walk", holes.is_empty(), "%d holes %s" % [holes.size(), str(holes.slice(0, 4))])
	check("...every board top at the walking height (no step down > 5 cm)", worst <= 0.05, "worst %.3f m" % worst)
	var mouth: Array = []
	z = MineLiftChamber.SILL_Z0 + 0.05
	while z < MineLiftChamber.SILL_Z1:
		var x2: float = -4.0
		while x2 <= 4.01:
			if is_nan(_top(decks, x2, z)):
				mouth.append("(%.1f, %.2f)" % [x2, z])
			x2 += 0.5
		z += 0.25
	check("no black gap beside the bridge either: the whole shaft mouth is boarded", mouth.is_empty(), "%d holes %s" % [mouth.size(), str(mouth.slice(0, 4))])
	lift.free()
	print("EP2_LIFT_LANDING: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)
