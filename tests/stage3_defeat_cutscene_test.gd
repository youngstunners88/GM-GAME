extends Node
## Gate for src/level/stage3_boss_defeat_cutscene.gd — the Stage 3 FINAL
## boss-defeat progress beat (Episode 1 close) wired into
## bandit_boss.gd::die() in place of the plain "GAME COMPLETE!" Label + 3s
## wait.
##
## Same failure-safety contract as tests/stage1_defeat_cutscene_test.gd and
## stage2_defeat_cutscene_test.gd (both shipped in PR #63): the sequence
## must reach `finished` in bounded time and free itself afterward.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/stage3_defeat_cutscene_test.tscn

const CUTSCENE := preload("res://src/level/stage3_boss_defeat_cutscene.gd")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("STAGE3 DEFEAT CUTSCENE:")
	await _run_normal()
	print("STAGE3_DEFEAT_CUTSCENE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _run_normal() -> void:
	var cutscene: CanvasLayer = CUTSCENE.new()
	add_child(cutscene)
	var start_ms := Time.get_ticks_msec()
	cutscene.play()
	await cutscene.finished
	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	_check("finishes", true)
	_check("finishes well under its own 15s hard deadline (took %.1fs)" % elapsed,
		elapsed < 13.0, "took %.1fs — deadline path likely triggered instead of normal completion" % elapsed)
	# queue_free() defers actual deallocation to end-of-frame. This cutscene
	# frees many children (debris pieces, tokens, boss parts) in the same
	# frame as itself — Stage 2's gate observed a one-frame flake here, so
	# this one starts with two frames of margin already.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("frees itself after finishing", not is_instance_valid(cutscene))
