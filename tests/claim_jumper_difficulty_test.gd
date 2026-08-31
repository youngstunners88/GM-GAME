extends Node
## S-BOSS — Claim Jumper "not too easy" gate.
##
## Founder: "the third boss is now way too easy to defeat ... we resolved it and
## now it's back." Root cause (Kimi K3): the VULNERABLE_DRIFT fix drifted him
## point-blank onto the player's axe, so a whole window could be bursted down.
## The retune adds a PER-WINDOW DAMAGE CAP (MAX_VULN_DAMAGE_PER_WINDOW) that
## ends the window early once hit, forcing >= ceil(HP/cap) separate windows.
##
## This gate drives take_damage() deterministically (physics paused so the state
## machine can't auto-transition mid-window) and asserts:
##   1. at most MAX_VULN_DAMAGE_PER_WINDOW HP is stripped per vulnerable window
##      (further hits that window are refused — state left VULNERABLE),
##   2. killing him takes >= ceil(max_health / cap) windows (no single-burst melt).
##
## Run: godot --headless res://tests/claim_jumper_difficulty_test.tscn

const BOSS := preload("res://src/boss/claim_jumper.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CLAIM JUMPER DIFFICULTY:")
	var boss: Node = BOSS.instantiate()
	add_child(boss)
	await get_tree().process_frame
	# Pause the state machine so windows don't auto-close on the timer — we are
	# testing the DAMAGE CAP, not the timer.
	boss.set_physics_process(false)

	var cap: int = boss.MAX_VULN_DAMAGE_PER_WINDOW
	var hp0: int = boss.health
	var windows: int = 0
	var worst_window_damage: int = 0
	var guard: int = 0
	while not boss.is_dead and guard < 200:
		guard += 1
		boss._begin_vulnerable()   # open a fresh window
		var before: int = boss.health
		# Hammer the window with more hits than the cap allows.
		for _i in range(cap + 3):
			boss.take_damage(1)
			if boss.is_dead:
				break
		var landed: int = before - boss.health
		worst_window_damage = maxi(worst_window_damage, landed)
		windows += 1

	var min_windows: int = int(ceil(float(hp0) / float(cap)))
	_check("no window lets more than the cap through (worst=%d, cap=%d)" % [worst_window_damage, cap],
		worst_window_damage <= cap)
	_check("kill takes >= %d windows (took %d) — not a single-burst melt" % [min_windows, windows],
		windows >= min_windows and boss.is_dead)
	print("  hp0=%d cap=%d windows_to_kill=%d (min %d)" % [hp0, cap, windows, min_windows])

	print("CLAIM_JUMPER_DIFFICULTY: %s" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fail += 1
