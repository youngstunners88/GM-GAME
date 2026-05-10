class_name TaxCollector
extends EnemyBase

@export var patrol_speed: float = 80.0
@export var charge_range: float = 200.0

var direction: float = 1.0
var charge_timer: float = 0.0
var patrol_timer: float = 0.0

func _ready() -> void:
	super()
	max_health = 2
	health = max_health
	speed = patrol_speed
	sprite.color = Color(0.4, 0.3, 0.2, 1.0)
	sprite.size = Vector2(48, 48)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	patrol_timer += delta

	velocity.y += 980.0 * delta
	velocity.x = direction * speed
	move_and_slide()

	if is_on_wall():
		direction *= -1.0
		sprite.scale.x = 1.0 if direction > 0 else -1.0

	if patrol_timer > 2.0:
		patrol_timer = 0.0
		_attempt_charge()

func _attempt_charge() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < charge_range:
		speed = 200.0
		charge_timer = 0.5
	else:
		speed = patrol_speed
