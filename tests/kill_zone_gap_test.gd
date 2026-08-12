extends Node
## Regression test for `level_base.gd`'s new `kill_zone_gaps` mechanism
## (T1/T2, "complete vault sections" — a vault chamber needs to extend past
## the old level-wide kill band's airspace without disabling pit-death
## everywhere else).
##
## Tests the interval-splitting logic directly (`_kill_zone_strip_intervals`
## depends only on `kill_zone_gaps` + a width parameter, not on the node being
## in the scene tree or any @onready state, so it's callable on a freshly
## constructed instance with no risk of hitting LevelBase's real `_ready()`
## chain, which expects real child nodes like $PlayerSpawn that a synthetic
## test instance doesn't have). The end-to-end real-physics proof — a player
## surviving inside a registered gap while the rest of the level-wide band
## stays lethal — lives in the actual vault tests against the real level
## scenes, where a real gap is really registered.
##
## Run: godot --headless res://tests/kill_zone_gap_test.tscn

var _fail: int = 0

func _ready() -> void:
	print("KILL ZONE GAP MECHANISM (interval logic):")
	_test_empty_gaps_produces_one_full_width_strip()
	_test_registered_gap_splits_into_two_strips()
	_test_two_gaps_produce_three_strips_sorted_by_x()
	_test_gap_clamped_to_level_bounds()
	print("KILL_ZONE_GAP: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## A LevelBase constructed but never added to the tree: _kill_zone_strip_
## intervals() touches only `kill_zone_gaps` (a plain var) and its own
## parameter, so it's safe to call without ever running _ready() (which would
## fail on the missing $PlayerSpawn/$BossTrigger/$BossSpawn children a real
## level scene provides).
func _bare_level() -> LevelBase:
	return LevelBase.new()

func _test_empty_gaps_produces_one_full_width_strip() -> void:
	var lvl := _bare_level()
	var intervals: Array = lvl._kill_zone_strip_intervals(4800.0)
	_check("empty kill_zone_gaps -> exactly one strip spanning the whole level (unaffected levels)",
		intervals.size() == 1 and intervals[0] == Vector2(0.0, 4800.0),
		"intervals=%s" % str(intervals))

func _test_registered_gap_splits_into_two_strips() -> void:
	var lvl := _bare_level()
	lvl.kill_zone_gaps.append(Vector2(2340, 2560))
	var intervals: Array = lvl._kill_zone_strip_intervals(4800.0)
	_check("one registered gap -> two strips, excluding exactly that range",
		intervals.size() == 2
			and intervals[0] == Vector2(0.0, 2340.0)
			and intervals[1] == Vector2(2560.0, 4800.0),
		"intervals=%s" % str(intervals))

func _test_two_gaps_produce_three_strips_sorted_by_x() -> void:
	var lvl := _bare_level()
	# Registered out of order on purpose — the splitter must sort them itself.
	lvl.kill_zone_gaps.append(Vector2(3000, 3200))
	lvl.kill_zone_gaps.append(Vector2(1000, 1200))
	var intervals: Array = lvl._kill_zone_strip_intervals(4800.0)
	_check("two registered gaps -> three strips, in x order regardless of registration order",
		intervals.size() == 3
			and intervals[0] == Vector2(0.0, 1000.0)
			and intervals[1] == Vector2(1200.0, 3000.0)
			and intervals[2] == Vector2(3200.0, 4800.0),
		"intervals=%s" % str(intervals))

func _test_gap_clamped_to_level_bounds() -> void:
	var lvl := _bare_level()
	# A gap that overruns the level's own width must not produce a
	# negative-width or out-of-bounds strip.
	lvl.kill_zone_gaps.append(Vector2(-500.0, 6000.0))
	var intervals: Array = lvl._kill_zone_strip_intervals(4800.0)
	_check("a gap wider than the level itself clamps to zero strips, not a negative-width one",
		intervals.is_empty(),
		"intervals=%s" % str(intervals))
