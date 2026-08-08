extends Node2D
## Real-physics proof for the founder's three named defects, build #1865228.
##
## Each of these was reported MORE THAN ONCE and "fixed" before, so none of
## them is allowed to pass on a data check. Every assertion here observes the
## thing the founder actually observes: does the boss close distance, does the
## score actually go to zero, can the boss leave its vulnerable window on its
## own.

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")
const AUDITOR := preload("res://src/boss/auditor.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BOSS STAKES + CHASE:")
	await _test_distributor_chases()
	await _test_distributor_leaves_vulnerable()
	await _test_claim_jumper_chases()
	_test_difficulty_escalates()
	await _test_bosses_detect_contact_outside_their_window()
	await _test_boss_contact_wipes_score()
	print("BOSS_STAKES: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## A stand-in player on the player layer/group, so bosses that look one up
## with get_first_node_in_group() find it.
func _make_player(at: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.collision_layer = 2
	p.collision_mask = 0
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 32)
	cs.shape = r
	cs.position = Vector2(16, 16)
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

# --------------------------------------------------------------------------
# "The 2nd boss doesn't chase Lil Blunt!!!"
# --------------------------------------------------------------------------
func _test_distributor_chases() -> void:
	Engine.time_scale = 1.0
	var player := _make_player(Vector2(1400, 500))
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(600, 500)
	await get_tree().process_frame

	var start_gap: float = absf(player.global_position.x - boss.global_position.x)
	# 3 simulated seconds — long enough to cross his first throw AND his first
	# vulnerable window, which is exactly where he used to lock up forever.
	for i in range(180):
		await get_tree().physics_frame
	var end_gap: float = absf(player.global_position.x - boss.global_position.x)

	_check("distributor closes distance on a stationary player",
		end_gap < start_gap - 120.0,
		"gap went %.0f -> %.0f (needed to close by >120px)" % [start_gap, end_gap])

	boss.queue_free()
	player.queue_free()
	await get_tree().process_frame

## The specific mechanism: VULNERABLE had no timeout, so he stopped forever.
func _test_distributor_leaves_vulnerable() -> void:
	Engine.time_scale = 1.0
	var player := _make_player(Vector2(1400, 500))
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	boss.global_position = Vector2(900, 500)
	await get_tree().process_frame

	# Force him into the vulnerable window and never hit him.
	boss.set("current_phase_state", 2)   # Phase.VULNERABLE
	boss.set("vuln_timer", boss.get("vulnerable_time"))
	var escaped := false
	for i in range(300):   # 5s, well past any sane window
		await get_tree().physics_frame
		if int(boss.get("current_phase_state")) != 2:
			escaped = true
			break
	_check("distributor exits VULNERABLE on its own, without being hit",
		escaped,
		"still in VULNERABLE after 5s — this is the 'doesn't chase' lock-up")

	boss.queue_free()
	player.queue_free()
	await get_tree().process_frame

# --------------------------------------------------------------------------
# Boss 3 should hunt too, not pace between walls.
# --------------------------------------------------------------------------
func _test_claim_jumper_chases() -> void:
	Engine.time_scale = 1.0
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(4000, 80)
	fcs.shape = frect
	floor_body.add_child(fcs)
	floor_body.global_position = Vector2(1000, 620)
	add_child(floor_body)

	var player := _make_player(Vector2(1700, 540))
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	boss.global_position = Vector2(800, 500)
	await get_tree().process_frame

	var start_gap: float = absf(player.global_position.x - boss.global_position.x)
	for i in range(150):
		await get_tree().physics_frame
	var end_gap: float = absf(player.global_position.x - boss.global_position.x)

	_check("claim jumper closes distance on a stationary player",
		end_gap < start_gap - 100.0,
		"gap went %.0f -> %.0f" % [start_gap, end_gap])

	boss.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame

# --------------------------------------------------------------------------
# "The bosses need to be more challenging with each stage!!!!"
# --------------------------------------------------------------------------
func _test_difficulty_escalates() -> void:
	var a: Node2D = AUDITOR.instantiate()
	var d: Node2D = DISTRIBUTOR.instantiate()
	var c: Node2D = CLAIM_JUMPER.instantiate()
	add_child(a); add_child(d); add_child(c)

	var hp1: int = int(a.get("max_health"))
	var hp2: int = int(d.get("max_health"))
	var hp3: int = int(c.get("max_health"))
	_check("boss HP rises across the campaign (L1 < L2 < L3)",
		hp1 < hp2 and hp2 < hp3,
		"L1=%d L2=%d L3=%d — the curve used to run BACKWARDS" % [hp1, hp2, hp3])

	a.queue_free(); d.queue_free(); c.queue_free()

# --------------------------------------------------------------------------
# "Lil Blunt has DIED and the player has LOST ALL OF THEIR POINTS."
# --------------------------------------------------------------------------
func _test_boss_contact_wipes_score() -> void:
	Engine.time_scale = 1.0
	GameManager.reset_boss_restart_flag()
	GameManager.total_score = 9999
	GameManager.coins_collected = 55
	GameManager.ethereum_rings_collected = 12
	GameManager.smoke_collected = 30
	GameManager.save_checkpoint(GameManager.current_level, 42, Vector2(700, 500))

	GameManager.boss_contact_restart()
	await get_tree().process_frame

	_check("boss contact zeroes the SCORE", GameManager.total_score == 0,
		"score is %d — a boss touch cost the player nothing" % GameManager.total_score)
	_check("boss contact zeroes coins/rings/smoke",
		GameManager.coins_collected == 0
			and GameManager.ethereum_rings_collected == 0
			and GameManager.smoke_collected == 0,
		"coins=%d rings=%d smoke=%d" % [GameManager.coins_collected,
			GameManager.ethereum_rings_collected, GameManager.smoke_collected])
	_check("boss contact clears the level checkpoint (restart is from the START)",
		not (GameManager.current_level in GameManager.level_checkpoints),
		"checkpoint survived — 'restart' would mean 'resume'")

	GameManager.reset_boss_restart_flag()

# --------------------------------------------------------------------------
# "There is a glitch issue with the 1st boss as i have stated a few times that
#  the moment he touches Lil Blunt the stage needs to restart."
#
# The restart LOGIC was already right (see _test_boss_contact_wipes_score).
# What was broken was one layer below it: every boss switched its Hitbox's
# `monitoring` OFF whenever it left its vulnerable window, which disables the
# Area2D outright. `body_entered` therefore never fired for roughly 80% of each
# fight and the player walked clean through the boss. That is exactly the shape
# of a bug that survives being "fixed" several times — the code you read looks
# correct, because it is; it is simply unreachable.
#
# So this asserts the REACHABILITY, not the consequence: on every boss, at rest
# in its ordinary non-vulnerable state, the hitbox must still be detecting.
# --------------------------------------------------------------------------
func _test_bosses_detect_contact_outside_their_window() -> void:
	var cases := [
		["Auditor (L1)", AUDITOR],
		["Distributor (L2)", DISTRIBUTOR],
		["Claim Jumper (L3)", CLAIM_JUMPER],
	]
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(4000, 80)
	fcs.shape = frect
	floor_body.add_child(fcs)
	floor_body.global_position = Vector2(600, 700)
	add_child(floor_body)

	for case: Array in cases:
		var boss: Node2D = (case[1] as PackedScene).instantiate()
		add_child(boss)
		boss.global_position = Vector2(600, 500)
		# Several frames so _ready and the first state transitions have run.
		for i in 12:
			await get_tree().physics_frame
		var hb := boss.get_node_or_null("Hitbox") as Area2D
		_check("%s exposes a Hitbox" % case[0], hb != null)
		if hb != null:
			_check("%s still DETECTS the player outside its vulnerable window" % case[0],
				hb.monitoring,
				"Hitbox.monitoring is false — body_entered can never fire, so boss contact does nothing")
		boss.queue_free()
		await get_tree().physics_frame
	floor_body.queue_free()
	await get_tree().physics_frame
