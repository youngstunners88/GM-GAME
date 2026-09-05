extends Node
## Gate for src/level/stage1_boss_defeat_cutscene.gd — the Stage 1 boss-defeat
## progress beat wired into auditor.gd::die() before victory_screen.
##
## Both design-review passes (Grok 4.5 + gpt-6-astra-pro, see
## docs/model-responses/2026-09-05-*-stage1-defeat-cutscene.md) converged on
## the same failure-safety spine: the sequence must reach `finished` in
## bounded time under normal conditions, AND it must still reach `finished`
## even when the player node it looks up doesn't exist (this project's own
## freeze-bug history is entirely sequences that assumed some other node
## would still be there a frame later).
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/stage1_defeat_cutscene_test.tscn

const CUTSCENE := preload("res://src/level/stage1_boss_defeat_cutscene.gd")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("STAGE1 DEFEAT CUTSCENE:")
	await _run_without_player()
	await _run_with_player()
	print("STAGE1_DEFEAT_CUTSCENE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## Failure-safety case: no "player" group member exists at all. The cutscene
## must not hang or error trying to reach into a node that isn't there.
func _run_without_player() -> void:
	var cutscene: CanvasLayer = CUTSCENE.new()
	add_child(cutscene)
	var start_ms := Time.get_ticks_msec()
	cutscene.play()
	await cutscene.finished
	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	_check("finishes with no player present", true)
	_check("finishes well under its own 14s hard deadline (took %.1fs)" % elapsed,
		elapsed < 12.0, "took %.1fs — deadline path likely triggered instead of normal completion" % elapsed)
	# queue_free() defers actual deallocation to end-of-frame, so give it one
	# frame before checking — this is a test-timing wait, not a game wait.
	await get_tree().process_frame
	_check("frees itself after finishing", not is_instance_valid(cutscene))

## Normal case: a real player node exists and gets the MINER outfit.
func _run_with_player() -> void:
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	var player: CharacterBody2D = preload("res://src/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(500, 300)
	await get_tree().physics_frame

	var cutscene: CanvasLayer = CUTSCENE.new()
	add_child(cutscene)
	var start_ms := Time.get_ticks_msec()
	cutscene.play()
	await cutscene.finished
	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	_check("finishes with a real player present (took %.1fs)" % elapsed, elapsed < 12.0)
	_check("player was given the MINER outfit (same call level_02 makes)",
		is_instance_valid(player) and player.current_outfit == Player.Outfit.MINER)
	_check("player node itself was never freed or hidden by the cutscene",
		is_instance_valid(player) and player.modulate.a > 0.0)

	if is_instance_valid(player):
		player.queue_free()
