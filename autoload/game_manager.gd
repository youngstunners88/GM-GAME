extends Node

signal score_changed(new_score: int)
signal health_changed(new_health: int)
signal power_up_changed(type: String, duration: float)
signal coins_changed(new_count: int)
signal rings_changed(new_count: int)
signal player_died

var total_score: int = 0
var coins_collected: int = 0
var ethereum_rings_collected: int = 0
var player_health: int = 3
var max_health: int = 3
var current_power_up: String = ""
var power_up_timer: float = 0.0
var current_level: int = 1
var level_checkpoints: Dictionary = {}
var player_position: Vector2 = Vector2.ZERO

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func add_score(points: int) -> void:
    total_score += points
    score_changed.emit(total_score)

func add_coin() -> void:
    coins_collected += 1
    coins_changed.emit(coins_collected)
    add_score(10)

func add_ethereum_ring() -> void:
    ethereum_rings_collected += 1
    rings_changed.emit(ethereum_rings_collected)
    add_score(50)

func take_damage(amount: int) -> void:
    if current_power_up == "diamond":
        deactivate_power_up()
        return
    player_health -= amount
    if player_health < 0:
        player_health = 0
    health_changed.emit(player_health)
    if player_health <= 0:
        player_died.emit()

func heal(amount: int) -> void:
    player_health = min(player_health + amount, max_health)
    health_changed.emit(player_health)

func activate_power_up(type: String, duration: float) -> void:
    current_power_up = type
    power_up_timer = duration
    power_up_changed.emit(type, duration)
    AudioManager.play_sfx("powerup")

func deactivate_power_up() -> void:
    current_power_up = ""
    power_up_timer = 0.0
    power_up_changed.emit("", 0.0)

func has_power_up(type: String) -> bool:
    return current_power_up == type

func _process(delta: float) -> void:
    if power_up_timer > 0:
        power_up_timer -= delta
        if power_up_timer <= 0:
            deactivate_power_up()

func reset_level() -> void:
    player_health = max_health
    current_power_up = ""
    power_up_timer = 0.0
    total_score = 0
    coins_collected = 0
    ethereum_rings_collected = 0

func save_checkpoint(level: int, checkpoint_id: int, pos: Vector2) -> void:
    level_checkpoints[level] = {"id": checkpoint_id, "pos": pos}

func get_checkpoint(level: int) -> Vector2:
    if level in level_checkpoints:
        return level_checkpoints[level].pos
    return Vector2.ZERO
