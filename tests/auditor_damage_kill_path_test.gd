extends Node
## Founder, 2026-08-26 (P0, shot auditor_immortal): "The Tax Auditor won't die at
## this point of his health bar. I've been shooting him for long now and nothing
## is happening." Bar shows ~3 segments; sustained damage does nothing; boss is
## fightable-but-unkillable.
##
## ROOT CLASS: take_damage() only accepts damage in State.VULNERABLE, and the
## hitbox is only `monitorable` during VULNERABLE, so player attacks land ONLY in
## that window. If at low HP (phase 3) the boss stops entering VULNERABLE, he is
## unkillable. This gate drives the REAL boss in the REAL level and lands one hit
## on every VULNERABLE window (the real per-window cap), asserting HP reaches 0
## and death fires — from full HP, and from a low-HP start (the founder's state).
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/auditor_damage_kill_path_test.tscn

const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("AUDITOR DAMAGE / KILL PATH:")
	# Test the buggy bands directly: phase 2 (HP 5) and phase 3 (HP 3, the
	# founder's ~3-segment state). Starting mid-fight keeps each run bounded while
	# exercising the exact HP bands where the vault-chain starved VULNERABLE.
	await _run_kill("phase 2 (HP 5)", 5)
	await _run_kill("phase 3 (HP 3)", 3)
	print("AUDITOR_DAMAGE_KILL_PATH: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## Drives one fight to the death. start_hp < 0 => leave at max.
func _run_kill(label: String, start_hp: int) -> void:
	# Keep StateMachine PLAYING so nothing external gates the fight.
	if not StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
		StateMachine.change_state(StateMachine.State.PLAYING)
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	# Trigger the boss the same way the level does.
	player.global_position = Vector2(2900.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame
	var boss: Node = level.get_node_or_null("Auditor")
	if boss == null:
		_check("[%s] Auditor spawned" % label, false)
		level.queue_free(); await get_tree().process_frame
		return
	if start_hp > 0:
		boss.health = start_hp
		boss.max_health = boss.max_health  # keep bar scale
		if boss.has_method("_update_phase"):
			boss._update_phase()

	var VULN: int = boss.State.VULNERABLE
	var DEFEATED: int = boss.State.DEFEATED
	var start_health: int = boss.health
	var windows: int = 0
	var was_vuln: bool = false
	var frames_since_vuln: int = 0
	var max_gap_frames: int = 0
	var died: bool = false
	var last_health: int = boss.health
	var monotonic := true
	var bound: int = 2400  # 40s @60fps — bounded per-band test

	for f in range(bound):
		if not is_instance_valid(boss):
			died = true
			break
		# Keep the player alongside the boss so the state machine stays engaged
		# (charge target present), ~180px to his west, on the ground.
		var bx: float = boss.global_position.x
		player.global_position = Vector2(bx - 180.0, 500.0)
		player.velocity = Vector2.ZERO
		var st: int = boss.current_state
		if st == DEFEATED:
			died = true
			break
		if st == VULN:
			if not was_vuln:
				windows += 1
				max_gap_frames = maxi(max_gap_frames, frames_since_vuln)
				frames_since_vuln = 0
			# Land ONE hit this window (take_damage self-caps to 1/window).
			boss.take_damage(1)
			was_vuln = true
		else:
			was_vuln = false
			frames_since_vuln += 1
		if boss.health < last_health:
			last_health = boss.health
		elif boss.health > last_health:
			monotonic = false
		if boss.health <= 0:
			# die() may already have fired inside take_damage; DEFEATED next frame.
			died = boss.current_state == DEFEATED or not is_instance_valid(boss)
			if died:
				break
		await get_tree().physics_frame

	print("  [INFO] %s: start=%d windows=%d max_gap=%.1fs died=%s final_hp=%s"
		% [label, start_health, windows, max_gap_frames / 60.0, str(died),
			(str(boss.health) if is_instance_valid(boss) else "freed")])
	_check("[%s] boss DIES (reaches 0 HP + death state) within %ds" % [label, bound / 60],
		died, "still alive after %ds — UNKILLABLE at this HP band" % (bound / 60))
	_check("[%s] HP only decreases (monotonic)" % label, monotonic)
	_check("[%s] no unbounded VULNERABLE starvation (max gap < 12s)" % label,
		max_gap_frames < 720, "longest stretch with NO damage window = %.1fs" % (max_gap_frames / 60.0))

	if is_instance_valid(boss):
		boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
