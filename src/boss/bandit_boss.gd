extends BossBase

enum Phase { PATROL, THROW, CHARGE, VULNERABLE }

@export var patrol_speed: float = 100.0
@export var charge_speed: float = 300.0
@export var throw_cooldown: float = 1.5

var current_phase_local: Phase = Phase.PATROL
var throw_timer: float = 0.0
var direction: float = 1.0

@onready var sprite: BossSprite = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	max_health = 10
	health = 10
	phase_thresholds = [6, 3]
	add_to_group("enemy")
	add_to_group("boss")
	sprite.color = Color(0.5, 0.3, 0.1, 1.0)
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

	match current_phase_local:
		Phase.PATROL:
			velocity.x = patrol_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				direction *= -1.0
				sprite.scale.x = 1.0 if direction > 0 else -1.0
			if throw_timer <= 0:
				_throw_dynamite()

		Phase.THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			if throw_timer <= 0:
				current_phase_local = Phase.CHARGE

		Phase.CHARGE:
			velocity.x = charge_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				current_phase_local = Phase.VULNERABLE
				sprite.color = Color(1.0, 0.2, 0.2, 1.0)
				hitbox.monitorable = true
				hitbox.monitoring = true
				throw_timer = 1.0

		Phase.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta * 60.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)
			if throw_timer <= 0:
				current_phase_local = Phase.PATROL
				sprite.color = Color(0.5, 0.3, 0.1, 1.0)
				hitbox.monitorable = false
				hitbox.monitoring = false
				throw_timer = 2.0

func _throw_dynamite() -> void:
	throw_timer = throw_cooldown
	current_phase_local = Phase.THROW
	var dyn = preload("res://src/boss/dynamite.tscn")
	if dyn:
		dyn = dyn.instantiate()
	else:
		dyn = Node2D.new()
	dyn.position = global_position + Vector2(0, -50)
	get_parent().add_child(dyn)

func take_damage(amount: int) -> void:
	if is_dead or current_phase_local != Phase.VULNERABLE:
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
		_check_phase_change()

func die() -> void:
	is_dead = true
	set_physics_process(false)
	GameManager.add_score(2000)
	ScreenShake.shake(0.8, 12.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	ScreenShake.zoom_to(1.0, 0.6)
	ScreenShake.heavy()
	GameManager.save_session()
	if health_bar:
		health_bar.queue_free()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var victory := Label.new()
	victory.text = "GAME COMPLETE!\nLil Blunt victorious!"
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.position = global_position - Vector2(100, 50)
	victory.add_theme_font_size_override("font_size", 32)
	get_tree().current_scene.add_child(victory)
	await get_tree().create_timer(3.0).timeout
	SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.DIAMOND)
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
