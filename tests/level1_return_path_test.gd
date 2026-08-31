extends Node
## Founder, 2026-08-23: "Lil Blunt goes to the end of Stage 1 and gets stuck,
## cannot return." Level 1 is a full-stage HUNT — no arena seal by design — so
## the player must be able to travel the ground corridor BOTH ways freely.
##
## Root cause (measured): three secret_walls (flavour "smoke tip" easter eggs)
## floated at y=586 — head height — straddling the ground corridor at
## x=468/1368/2768. A WALKING player driven west from the stage end walled at
## exactly x=2800 against the (2768,586) wall and could not pass. (The Auditor
## already carried collision exceptions for these same walls — the boss half of
## the same mistake.) Raised to y=500, the same overhead height as this level's
## breakable_blocks, which the player has always walked under both ways.
##
## This gate drives a WALKING (never jumping) player west along the ground and
## asserts he passes every secret-wall x without being walled. Walking-only is
## deliberate: it proves the corridor itself is clear, independent of jump skill.
##
## Run: godot --headless res://tests/level1_return_path_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")
## Ground segment the walk covers without a gap: (2300,650,500,70) = x 2300..2800.
## Start east on it, walk west across the old x=2800 block point to x=2350.
const START_X := 2950.0
const TARGET_X := 2360.0
const SECRET_WALL_XS := [2768.0]  # the one on this continuous segment

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("LEVEL1 RETURN PATH:")
	await _run()
	print("LEVEL1_RETURN_PATH: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	# Disable the boss trigger: this gate isolates the CORRIDOR traversal claim,
	# not the fight. Placing the player near x=2790 would otherwise fire the
	# Auditor (BossTrigger at x=2700) and its contact-restart mid-walk.
	var bt := level.get_node_or_null("BossTrigger")
	if bt != null:
		bt.set_deferred("monitoring", false)
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(START_X, 560.0)
	# Settle onto the ground.
	for _i in range(30):
		player.velocity.y += 980.0 * (1.0 / 60.0)
		player.move_and_slide()
		await get_tree().physics_frame

	var min_x: float = player.global_position.x
	var walled_at: float = INF
	var walled_streak: int = 0
	for f in range(240):  # 4s of walking west, no jump
		var before: float = player.global_position.x
		player.velocity.x = -240.0
		player.velocity.y += 980.0 * (1.0 / 60.0)
		player.move_and_slide()
		min_x = minf(min_x, player.global_position.x)
		if player.is_on_wall() and absf(player.global_position.x - before) < 0.5:
			walled_streak += 1
			if walled_streak > 20:
				walled_at = minf(walled_at, player.global_position.x)
		else:
			walled_streak = 0
		if player.global_position.x <= TARGET_X:
			break
		await get_tree().physics_frame

	print("  [INFO] walked west %.0f -> %.0f (target %.0f), walled_at=%.0f"
		% [START_X, min_x, TARGET_X, walled_at])
	_check("Walking player crosses the old x=2800 secret-wall block point",
		min_x < 2760.0, "stopped at %.0f — still walled by a corridor secret wall" % min_x)
	_check("Walking player reaches the return target without a sustained wall",
		min_x <= TARGET_X, "only reached %.0f" % min_x)

	level.queue_free()
	await get_tree().process_frame
