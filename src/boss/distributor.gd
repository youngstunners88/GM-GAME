extends BossBase

enum Phase { PATROL, SHARD_THROW, VULNERABLE }

@export var patrol_speed: float = 80.0
@export var throw_cooldown: float = 2.0

var current_phase: Phase = Phase.PATROL
var throw_timer: float = 0.0
var direction: float = 1.0
var orb_count: int = 3

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	max_health = 7
	health = 7
	phase_thresholds = [4, 2]
	add_to_group("enemy")
	add_to_group("boss")
	sprite.color = Color(0.3, 0.2, 0.6, 1.0)
	sprite.size = Vector2(96, 96)
	collision.position = Vector2(48, 48)
	hitbox.position = Vector2(48, 48)
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_setup_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta

	match current_phase:
		Phase.PATROL:
			velocity.x = patrol_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				direction *= -1.0
				sprite.scale.x = 1.0 if direction > 0 else -1.0
			if throw_timer <= 0:
				_throw_shards()

		Phase.SHARD_THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			if throw_timer <= 0:
				current_phase = Phase.VULNERABLE
				sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.monitorable = true
				hitbox.monitoring = true

		Phase.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)

func _throw_shards() -> void:
	throw_timer = throw_cooldown
	current_phase = Phase.SHARD_THROW
	for i in range(3):
		var shard_angle = (i - 1) * 0.3
		var shard = preload("res://src/boss/shard_projectile.tscn")
		if shard:
			shard = shard.instantiate()
		else:
			shard = Node2D.new()
		shard.position = global_position + Vector2(0, -50)
		get_parent().add_child(shard)

func take_damage(amount: int) -> void:
	if is_dead or current_phase != Phase.VULNERABLE:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	_update_health_bar()
	if health <= 0:
		die()
	else:
		current_phase = Phase.PATROL
		throw_timer = 2.0
		sprite.color = Color(0.3, 0.2, 0.6, 1.0)
		hitbox.monitorable = false
		hitbox.monitoring = false
		_check_phase_change()

func die() -> void:
	is_dead = true
	set_physics_process(false)
	GameManager.add_score(1000)
	ScreenShake.shake(0.6, 10.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	GameManager.save_session()
	if Web3Manager.is_connected:
		Web3Manager.submit_score(GameManager.total_score)
	if health_bar:
		health_bar.queue_free()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var victory := Label.new()
	victory.text = "LEVEL COMPLETE!\nDiamonds unlocked!"
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.position = global_position - Vector2(100, 50)
	victory.add_theme_font_size_override("font_size", 32)
	get_tree().current_scene.add_child(victory)
	await get_tree().create_timer(3.0).timeout
	SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.FADE)
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
