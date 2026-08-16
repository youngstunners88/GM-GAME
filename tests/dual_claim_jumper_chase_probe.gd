extends Node
## S-DUAL — Claim Jumper ground-chase PROBE (real level_03).
##
## The real-level sim showed the Claim Jumper crawling ~63px/s against a
## patrol_speed of 290 — the founder's "final boss doesn't move / doesn't
## chase". This probe instruments the REAL boss in the REAL arena frame by
## frame to find WHY: is he grounded? is his velocity.x being zeroed by a
## phantom ledge every frame? is he stuck hopping? The player is pinned at the
## far WEST wall so there is a long chase runway and contact does not fire for
## the first ~1s of measurement.
##
## Run: godot --headless res://tests/dual_claim_jumper_chase_probe.tscn

const SCENE := "res://src/level/level_03_gold_rush.tscn"

func _ready() -> void:
	await get_tree().process_frame
	var level: Node = load(SCENE).instantiate()
	add_child(level)
	for _i in range(8):
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var arena: Dictionary = level.level_data.boss_arena
	var start_x: float = float(arena.get("start_x", 0.0))
	var end_x: float = float(arena.get("end_x", 0.0))
	player.global_position = Vector2(start_x + 120.0, player.global_position.y)
	level._on_boss_trigger(player)
	for _i in range(4):
		await get_tree().process_frame

	var boss := get_tree().get_first_node_in_group("boss") as Node2D
	print("boss=%s pos=%s arena_min=%s arena_max=%s" % [
		boss.name, str(boss.global_position), str(boss.get("arena_min")), str(boss.get("arena_max"))])
	# MEASUREMENT ONLY: silence the contact hitbox so reaching the player does
	# not fire boss_contact_restart (which reloads the level and would tangle
	# this probe's awaits). We are measuring the CHASE, not contact.
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)
	# Pin the player at the FAR WEST wall — long runway, no immediate contact.
	var west_x: float = start_x + 40.0
	var last_x: float = boss.global_position.x
	for f in range(120):  # 2.0s
		if not is_instance_valid(boss) or not is_instance_valid(player):
			print("  [frame %d] boss/player freed (contact restart) — stopping" % f)
			break
		player.global_position.x = west_x
		await get_tree().physics_frame
		if f % 6 == 0:  # every 0.1s
			var bx: float = boss.global_position.x
			var vx: float = boss.velocity.x
			var onfloor: bool = boss.is_on_floor()
			var st: Variant = boss.get("current_state")
			print("  t=%.1fs boss_x=%.0f (Δ%+.0f) vx=%.0f on_floor=%s state=%s player_x=%.0f" % [
				f / 60.0, bx, bx - last_x, vx, str(onfloor), str(st), west_x])
			last_x = bx
	if is_instance_valid(boss):
		print("RESULT: boss ended at x=%.0f (spawn-relative travel toward west wall)" % boss.global_position.x)
	get_tree().quit(0)
