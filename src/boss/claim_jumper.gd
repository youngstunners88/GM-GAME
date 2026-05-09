extends CharacterBody2D

enum State { PATROL, THROW, VULNERABLE, DEFEATED }

@export var max_health: int = 6
@export var patrol_speed: float = 100.0
@export var throw_cooldown: float = 1.5

var current_state: State = State.PATROL
var health: int = 6
var phase: int = 1
var throw_timer: float = 0.0
var direction: float = 1.0

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	health = max_health
	sprite.color = Color(0.6, 0.4, 0.2, 1.0)
	sprite.size = Vector2(80, 80)
	collision.position = Vector2(40, 40)
	hitbox.position = Vector2(40, 40)
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	if current_state == State.DEFEATED:
		return

	throw_timer -= delta

	match current_state:
		State.PATROL:
			velocity.x = patrol_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				direction *= -1.0
				sprite.scale.x = 1.0 if direction > 0 else -1.0
			if throw_timer <= 0:
				_throw_dynamite()

		State.THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 150.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)

func _throw_dynamite() -> void:
	throw_timer = throw_cooldown
	var dyn_scene = preload("res://src/boss/dynamite.tscn")
	if dyn_scene == null:
		var dyn = preload("res://src/boss/dynamite.gd").new()
		dyn.position = global_position + Vector2(0, -50)
		get_parent().add_child(dyn)
	else:
		var dyn = dyn_scene.instantiate()
		dyn.position = global_position + Vector2(0, -50)
		get_parent().add_child(dyn)

func take_damage(amount: int) -> void:
	if current_state == State.DEFEATED:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	if health <= 0:
		die()
	else:
		_update_phase()

func _update_phase() -> void:
	phase = 3 - (health / 2)
	if phase >= 2:
		patrol_speed = 150.0

func die() -> void:
	current_state = State.DEFEATED
	GameManager.add_score(750)
	ScreenShake.shake(0.6, 10.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	GameManager.save_session()
	if Web3Manager.is_connected:
		Web3Manager.submit_score(GameManager.total_score)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var victory := Label.new()
	victory.text = "LEVEL COMPLETE!\nGoldMine conquered!"
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
