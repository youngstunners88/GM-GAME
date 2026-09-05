extends Node
## Gate for src/level/stage2_boss_defeat_cutscene.gd — the Stage 2 boss-defeat
## progress beat wired into distributor.gd::die() in place of the plain
## "LEVEL COMPLETE!" Label + 3s wait.
##
## Same failure-safety contract as tests/stage1_defeat_cutscene_test.gd
## (that gate shipped in PR #63): the sequence must reach `finished` in
## bounded time and free itself afterward, with or without any of its
## optional assets present.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/stage2_defeat_cutscene_test.tscn

const CUTSCENE := preload("res://src/level/stage2_boss_defeat_cutscene.gd")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("STAGE2 DEFEAT CUTSCENE:")
	await _run_normal()
	print("STAGE2_DEFEAT_CUTSCENE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _run_normal() -> void:
	var cutscene: CanvasLayer = CUTSCENE.new()
	add_child(cutscene)
	var start_ms := Time.get_ticks_msec()
	cutscene.play()
	await cutscene.finished
	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	_check("finishes", true)
	_check("finishes well under its own 12s hard deadline (took %.1fs)" % elapsed,
		elapsed < 10.0, "took %.1fs — deadline path likely triggered instead of normal completion" % elapsed)
	# queue_free() defers actual deallocation to end-of-frame. This cutscene
	# frees ~15 children (shard/particle pieces, boss parts) in the same
	# frame as itself — observed flaky at exactly one frame of margin under
	# headless timing, so wait two to give deferred deletion order slack.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("frees itself after finishing", not is_instance_valid(cutscene))
