extends Node
const LEVEL := preload("res://src/level/level_01_smoke_realm.tscn")

func _ready() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(150.0, 620.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame
	var boss := level.get_node_or_null("Auditor")
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)
	var logging := false
	for f in range(2700):
		player.global_position = Vector2(150.0, 620.0)
		if not is_instance_valid(boss):
			print("FREED"); break
		var bx: float = boss.global_position.x
		if bx < 1260.0:
			logging = true
		if logging and f % 15 == 0:
			var parts: Array[String] = []
			for i in range(boss.get_slide_collision_count()):
				var col: KinematicCollision2D = boss.get_slide_collision(i)
				var o = col.get_collider()
				if o == null: continue
				var nn: Vector2 = col.get_normal()
				var kind := "side"
				if nn.y < -0.7: kind = "FLOOR"
				elif nn.y > 0.7: kind = "CEIL"
				var op: Vector2 = (o.global_position if o is Node2D else Vector2.ZERO)
				parts.append("%s:%s@(%.0f,%.0f)" % [kind, o.name, op.x, op.y])
			print("f=%d x=%.0f y=%.0f vx=%.0f vy=%.0f st=%s wall=%s floor=%s ceil=%s leapcd=%.2f airjmp=%s sidestep=%.2f commit=%.0f | %s"
				% [f, bx, boss.global_position.y, boss.velocity.x, boss.velocity.y,
					boss.get("current_state"), boss.is_on_wall(), boss.is_on_floor(), boss.is_on_ceiling(),
					boss.get("_leap_cooldown"), boss.get("_air_jump_ready"), boss.get("_ceiling_sidestep"),
					boss.get("_leap_commit_dir"), ", ".join(parts)])
		await get_tree().physics_frame
	get_tree().quit(0)
