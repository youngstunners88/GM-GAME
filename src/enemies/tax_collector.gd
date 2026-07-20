extends EnemyBase

@export var patrol_speed: float = 60.0
@export var patrol_distance: float = 200.0

var start_x: float = 0.0
var moving_right: bool = true

func _ready() -> void:
    super._ready()
    start_x = global_position.x
    analytics_id = "tax"
    # Invisible adaptive difficulty (task #23): players who die to Tax
    # Collectors repeatedly get 15% slower patrols. No UI, no announcement.
    patrol_speed *= DifficultyManager.tax_speed_scale

func _physics_process(delta: float) -> void:
    # Kimi audit: don't let gravity accumulate unbounded while grounded.
    if is_on_floor() and velocity.y > 0.0:
        velocity.y = 0.0
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
