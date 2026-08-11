extends Node
## T1/T3 — "PUFFS" -> "BLAZE DIAMONDS" is roughly twice as many characters at
## the same font_size 52, and T3 then adds a face-art icon into the same HUD
## row ahead of the TAP OUT button. Either change alone could silently push
## the row wider than the 1280px viewport, or make two elements overlap —
## a code diff can look fine and still overflow on screen.
##
## This does NOT hand-calculate an "available space" budget from constants
## (that number drifted the moment T3 added the face icon, which is exactly
## the kind of silent staleness a hand-tracked budget invites). Instead it
## lets Godot actually LAY OUT the real HUD row and reads back the real
## Control rects, so it can only ever be as stale as the row itself.
##
## Run: godot --headless res://tests/blaze_hud_label_fit_test.tscn

const BLAZE_RUSH := preload("res://src/dashmode/blaze_rush.tscn")
const VIEWPORT_WIDTH: float = 1280.0

var _fail: int = 0
var _checks_run: int = 0
const MIN_EXPECTED_CHECKS: int = 2

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE HUD LABEL FIT (T1/T3):")
	await _run()
	# Guard against exactly the bug this file's own first draft had: `_run()`
	# contains `await`s, so calling it WITHOUT `await` here let `_ready()`
	# race ahead to this line and report "ALL PASS" with zero checks having
	# actually executed yet — a false green caught only by noticing the
	# per-check [PASS]/[FAIL] lines were silently missing from the log.
	if _checks_run < MIN_EXPECTED_CHECKS:
		_fail += 1
		print("  [FAIL] only %d/%d expected checks ran — a false green, not a real pass"
			% [_checks_run, MIN_EXPECTED_CHECKS])
	print("BLAZE_HUD_LABEL_FIT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks_run += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Depth-first search for the first HBoxContainer under `n` — the HUD row is
## built fresh by _build_hud() with no stored reference, so this is how the
## test finds it rather than assuming a node path/index that build order
## could silently change.
func _find_hbox(n: Node) -> HBoxContainer:
	if n is HBoxContainer:
		return n
	for child in n.get_children():
		var found := _find_hbox(child)
		if found != null:
			return found
	return null

func _run() -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500, 400),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var smoke_label: Label = run.get("_smoke_label")
	var attempt_label: Label = run.get("_attempt_label")
	var row := _find_hbox(run)
	_check("run built its HUD labels and row", smoke_label != null and attempt_label != null and row != null)
	if smoke_label == null or attempt_label == null or row == null:
		run.queue_free()
		return

	# Worst realistic case: two-digit collect count, two-digit attempt number
	# ("Attempt 17" in the founder's own screenshot; "99" is a safe ceiling).
	smoke_label.text = "BLAZE DIAMONDS 99"
	attempt_label.text = "ATTEMPT 99 "
	# Let the container re-flow with the new text before reading rects back.
	await get_tree().process_frame
	await get_tree().process_frame

	var kids := row.get_children()
	_check("HUD row carries the diamond count, attempt count, face art and TAP OUT button",
		kids.size() >= 4, "row has %d children" % kids.size())

	# No two visible Controls in the row may overlap, and the whole row must
	# stay inside the viewport — checked from REAL rects, not estimates.
	var overlaps: Array[String] = []
	var offscreen: Array[String] = []
	for i in range(kids.size()):
		var a := kids[i] as Control
		if a == null or not a.visible or a.size == Vector2.ZERO:
			continue
		var a_rect := Rect2(a.global_position, a.size)
		if a_rect.position.x < -1.0 or a_rect.end.x > VIEWPORT_WIDTH + 1.0:
			offscreen.append("%s x[%.0f,%.0f]" % [a.name if a.name != "" else str(a), a_rect.position.x, a_rect.end.x])
		for j in range(i + 1, kids.size()):
			var b := kids[j] as Control
			if b == null or not b.visible or b.size == Vector2.ZERO:
				continue
			var b_rect := Rect2(b.global_position, b.size)
			if a_rect.intersects(b_rect):
				overlaps.append("%s <-> %s" % [
					a.name if a.name != "" else str(a),
					b.name if b.name != "" else str(b)])

	_check("no two HUD row elements overlap at worst-case text length",
		overlaps.is_empty(), "; ".join(overlaps))
	_check("the HUD row stays inside the %dpx viewport" % int(VIEWPORT_WIDTH),
		offscreen.is_empty(), "; ".join(offscreen))

	run.queue_free()
	await get_tree().process_frame
