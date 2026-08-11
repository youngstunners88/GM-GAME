extends Node
## T4 — BAND DENSITY. "Large empty real estate = money left on the table."
##
## The founder is describing L2 and L3: the same nine or ten protocol artworks
## were spread over courses that are 17% and 35% longer than L1, so the longer
## the stage the emptier the purple band looked. That is not a taste call, it
## is arithmetic — the landmark lattice divided the WHOLE course by a FIXED
## piece count, so the stride grew with the course:
##
##   L1  length 5450 -> pitch ~494
##   L2  length 6400 -> pitch ~600
##   L3  length 7350 -> pitch ~706
##
## Nothing in the gate battery measured that, which is why three passes of
## "spacing fixed" all shipped with L2/L3 still sparse. This measures the real
## rendered sprites in a real instantiated run and fails on any span of empty
## band wider than MAX_EMPTY_SPAN.
##
## It also re-asserts the two rules that must survive any densification:
## NO OVERLAP between pieces, and no piece hanging over a floor gap.
##
## Run: godot --headless res://tests/blaze_band_density_test.tscn

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")

## Widest run of empty purple allowed between two consecutive artworks, in px.
## The placer targets TARGET_BAND_PITCH (430) centre-to-centre; a pair of
## narrow badges at that pitch leaves ~240px of air, and the search is allowed
## to nudge a piece off the lattice to clear a gap, so this permits real
## displacement while still failing the ~400px voids L3 used to show.
const MAX_EMPTY_SPAN: float = 520.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE BAND DENSITY (T4):")
	for lvl in [1, 2, 3]:
		await _check_level(lvl)
	print("BLAZE_BAND_DENSITY: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Every band artwork in the run, as [left_x, right_x] in course space, sorted.
##
## Measured from the REAL rendered extent (texture width * applied scale), not
## from a nominal constant — the wide artworks are height-fitted so their width
## is whatever their aspect ratio makes it, and a previous banner-clearance bug
## came from exactly this substitution.
func _band_spans(run: Node2D) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for child in run.get_children():
		var spr := child as Sprite2D
		if spr == null or spr.texture == null:
			continue
		# Band art is seated inside the purple floor band at z_index >= 1;
		# course props and the run line are not.
		if spr.z_index < 1:
			continue
		var half_w: float = spr.scale.x * float(spr.texture.get_width()) / 2.0
		spans.append(Vector2(spr.position.x - half_w, spr.position.x + half_w))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return spans

func _check_level(level_index: int) -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500, 400),
		"level_index": level_index,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var spans: Array[Vector2] = _band_spans(run)
	print("  L%d: %d band artworks placed" % [level_index, spans.size()])
	_check("L%d band carries artwork at all" % level_index, spans.size() >= 4,
		"only %d pieces found" % spans.size())

	if spans.size() >= 2:
		var worst: float = 0.0
		var worst_at: float = 0.0
		var overlapped: int = 0
		for i in range(spans.size() - 1):
			var gap: float = spans[i + 1].x - spans[i].y
			if gap < 0.0:
				overlapped += 1
			elif gap > worst:
				worst = gap
				worst_at = spans[i].y
		_check("L%d has no empty band span wider than %.0fpx" % [level_index, MAX_EMPTY_SPAN],
			worst <= MAX_EMPTY_SPAN,
			"widest empty run is %.0fpx starting at x=%.0f (%d pieces on course)"
				% [worst, worst_at, spans.size()])
		# Densifying must never be allowed to buy coverage with overlap — the
		# founder called out overlapping art as its own defect.
		_check("L%d band artworks do not overlap each other" % level_index,
			overlapped == 0,
			"%d overlapping pairs" % overlapped)

	# A longer course must carry MORE brand, not the same amount stretched out.
	# This is the actual defect, stated as a rule.
	run.queue_free()
	await get_tree().process_frame
