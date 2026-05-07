extends EnemyBase

@export var fly_speed: float = 80.0
@export var amplitude: float = 30.0
@export var frequency: float = 3.0

var start_y: float = 0.0
var time: float = 0.0
var fly_direction: float = 1.0

func _ready() -> void:
    super._ready()
    health = 3
    score_value = 100
    start_y = global_position.y
    sprite.color = Color(0.2, 0.2, 0.2, 1.0) # Dark gray
    sprite.size = Vector2(24, 24)
    $CollisionShape2D.position = Vector2(12, 12)

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    time += delta
    velocity.x = fly_speed * fly_direction
    velocity.y = cos(time * frequency) * amplitude

    move_and_slide()

    # Turn at limits
    if global_position.x > start_y + 300 and fly_direction > 0:
        fly_direction = -1.0
        sprite.scale.x = -1.0
    elif global_position.x < start_y - 300 and fly_direction < 0:
        fly_direction = 1.0
        sprite.scale.x = 1.0
