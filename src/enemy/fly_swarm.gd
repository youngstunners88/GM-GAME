class_name FlySwarm
extends EnemyBase

@export var hover_height: float = 0.0
@export var hover_amplitude: float = 30.0
@export var hover_speed: float = 2.0

var hover_timer: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	super()
	max_health = 1
	health = max_health
	damage = 1
	sprite.color = Color(0.7, 0.4, 0.1, 1.0)
	sprite.size = Vector2(32, 32)
	base_y = global_position.y
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	hover_timer += delta
	var sine_offset = sin(hover_timer * hover_speed * TAU) * hover_amplitude
	global_position.y = base_y + sine_offset

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var direction = sign(player.global_position.x - global_position.x)
		velocity.x = direction * speed
	else:
		velocity.x = 0
