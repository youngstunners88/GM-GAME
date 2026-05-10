class_name RollingBoulder
extends EnemyBase

@export var roll_speed: float = 150.0
@export var roll_acceleration: float = 200.0

var current_speed: float = 0.0
var direction: float = 1.0

func _ready() -> void:
	super()
	max_health = 3
	health = max_health
	damage = 2
	sprite.color = Color(0.5, 0.5, 0.5, 1.0)
	sprite.size = Vector2(40, 40)
	current_speed = 0.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	velocity.y += 980.0 * delta

	current_speed = move_toward(current_speed, roll_speed * direction, roll_acceleration * delta)
	velocity.x = current_speed

	move_and_slide()

	if is_on_wall():
		direction *= -1.0
		sprite.rotation = Vector2(velocity.x, 0).angle()

	sprite.rotation += (velocity.x / 40.0) * delta
