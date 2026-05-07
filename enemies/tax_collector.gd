extends EnemyBase

@export var patrol_speed: float = 60.0
@export var patrol_distance: float = 200.0

var start_x: float = 0.0
var moving_right: bool = true

func _ready() -> void:
    super._ready()
    start_x = global_position.x
    sprite.color = Color(0.3, 0.2, 0.13, 1.0) # Brown

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    var speed := patrol_speed
    if not moving_right:
        speed = -patrol_speed

    velocity.x = speed
    velocity.y += 980.0 * delta

    move_and_slide()

    # Turn around at patrol limits
    if global_position.x > start_x + patrol_distance:
        moving_right = false
        sprite.scale.x = -1.0
    elif global_position.x < start_x - patrol_distance:
        moving_right = true
        sprite.scale.x = 1.0

    # Also turn at walls
    if is_on_wall():
        moving_right = not moving_right
        sprite.scale.x = 1.0 if moving_right else -1.0
