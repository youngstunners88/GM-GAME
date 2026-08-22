extends Node
## DIAGNOSTIC (throwaway): does the Claim Jumper's WORLD X actually move while
## a bot kites him? Logs the real collider contacts every sample, exactly like
## the probe that cracked the Stage 1 "floating" bug.
##
## Arena: level_03_data.tres boss_arena start_x=3700 end_x=4400, spawn (4050,500).

const LEVEL := preload("res://src/level/level_03_gold_rush.tscn")

func _ready() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(3900.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss: CharacterBody2D = null
	for c in level.get_children():
		var sc: Script = c.get_script()
		if sc and "claim_jumper" in str(sc.resource_path):
			boss = c
			break
	if boss == null:
		print("NO_BOSS")
		get_tree().quit(1)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	for ch in boss.get_children():
		if ch is CollisionShape2D and ch.shape is RectangleShape2D:
			print("BOSS SHAPE pos=%s size=%s" % [ch.position, ch.shape.size])
	print("arena_min=%s arena_max=%s" % [boss.get("arena_min"), boss.get("arena_max")])

	var min_x: float = INF
	var max_x: float = -INF
	var frozen: int = 0
	var max_frozen: int = 0
	var prev_x: float = boss.global_position.x
	var air_hops: int = 0
	var prev_vy: float = 0.0
	var glued: int = 0
	var n: int = 1080  # 18s

	for f in range(n):
		# Fleeing bot: run WEST away from the boss, across the arena.
		var t: float = float(f) / 60.0
		player.global_position = Vector2(4300.0 - fmod(t * 160.0, 560.0), 500.0)
		if not is_instance_valid(boss):
			print("BOSS_FREED")
			break
		var vy: float = boss.velocity.y
		if not boss.is_on_floor() and vy < -400.0 and vy < prev_vy - 100.0:
			air_hops += 1
		prev_vy = vy
		var bx: float = boss.global_position.x
		min_x = minf(min_x, bx)
		max_x = maxf(max_x, bx)
		if absf(bx - prev_x) < 0.5:
			frozen += 1
			max_frozen = maxi(max_frozen, frozen)
		else:
			frozen = 0
		prev_x = bx
		if absf(bx - player.global_position.x) < 110.0:
			glued += 1
		if f % 30 == 0:
			var parts: Array[String] = []
			for i in range(boss.get_slide_collision_count()):
				var col: KinematicCollision2D = boss.get_slide_collision(i)
				var o = col.get_collider()
				if o == null:
					continue
				var nn: Vector2 = col.get_normal()
				var kind := "side"
				if nn.y < -0.7:
					kind = "FLOOR"
				elif nn.y > 0.7:
					kind = "CEIL"
				var op: Vector2 = (o.global_position if o is Node2D else Vector2.ZERO)
				parts.append("%s:%s@(%.0f,%.0f)" % [kind, o.name, op.x, op.y])
			print("t=%.1f boss=(%.0f,%.0f) vx=%.0f vy=%.0f player_x=%.0f state=%s wall=%s floor=%s | %s"
				% [t, bx, boss.global_position.y, boss.velocity.x, vy,
					player.global_position.x, boss.get("current_state"),
					boss.is_on_wall(), boss.is_on_floor(), ", ".join(parts)])
		await get_tree().physics_frame

	print("RESULT x_range=[%.0f,%.0f] span=%.0fpx max_frozen=%.2fs air_hops=%d glued=%.1f%%"
		% [min_x, max_x, max_x - min_x, max_frozen / 60.0, air_hops, 100.0 * glued / n])
	get_tree().quit(0)
