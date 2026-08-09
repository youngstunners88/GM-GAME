extends Node
## B6 — "Smoke Lounge callout / branding must appear in the Blaze banner on
## every stage (L1/L2/L3 Blaze), not once."
##
## First job is to find out whether it currently does. The landmark placer gives
## every artwork one slot on an even lattice and DROPS any that cannot clear a
## floor gap, so whether the Smoke Lounge banner survives is a function of each
## course's gap layout — which is exactly the kind of thing that silently
## differs per stage.

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")
const LOUNGE_ART := "smoke_lounge"

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE LOUNGE BANNER (B6):")
	for lvl in [1, 2, 3]:
		await _check_level(lvl)
	print("BLAZE_LOUNGE_BANNER: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

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

	var found := false
	for child in run.get_children():
		var spr := child as Sprite2D
		if spr != null and spr.texture != null \
				and spr.texture.resource_path.contains(LOUNGE_ART):
			found = true
	# The dedicated banner node, once it exists.
	if run.get_node_or_null("SmokeLoungeBanner") != null:
		found = true
	_check("L%d Blaze carries a Smoke Lounge callout" % level_index, found,
		"no Smoke Lounge branding was placed on this course")

	# The dedicated anticipation banner specifically — presence of the older
	# wide artwork is not a substitute, since that one can be dropped by the
	# landmark placer whenever a course's gaps move.
	var banner := run.get_node_or_null("SmokeLoungeBanner") as Node2D
	_check("L%d Blaze builds the dedicated anticipation banner" % level_index,
		banner != null, "SmokeLoungeBanner node missing")
	if banner != null:
		_check("L%d banner sits on the purple band, not in the sky" % level_index,
			banner.position.y > 500.0,
			"y = %.0f" % banner.position.y)
		_check("L%d banner is placed late in the run (anticipation)" % level_index,
			banner.position.x > float(run.get("_course_length")) * 0.5,
			"x = %.0f of %.0f" % [banner.position.x, float(run.get("_course_length"))])
		var over_gap: bool = bool(run.call("_x_over_gap", banner.position.x, 150.0))
		_check("L%d banner is NOT over a floor gap" % level_index, not over_gap)
	run.queue_free()
	await get_tree().process_frame
