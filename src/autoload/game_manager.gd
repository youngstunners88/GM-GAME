extends Node

signal score_changed(new_score: int)
signal health_changed(new_health: int)
signal power_up_changed(type: String, duration: float)
signal coins_changed(new_count: int)
signal rings_changed(new_count: int)
signal smoke_changed(new_count: int)
signal player_died

# Persistent player data only — no state booleans (those live in StateMachine).
var total_score: int = 0
var coins_collected: int = 0
var ethereum_rings_collected: int = 0
var smoke_collected: int = 0
# Blaze Rush (secret dash mode) bookkeeping.
var blaze_rush_completed: Dictionary = {}   # level_index -> true once one-time bonuses paid
var dash_return: Dictionary = {}            # transient: scene_path/position/level_index for the return trip
var player_health: int = 3
var max_health: int = 3
var current_power_up: String = ""
var power_up_timer: float = 0.0
var current_level: int = 1
var level_checkpoints: Dictionary = {}
var player_position: Vector2 = Vector2.ZERO

const SAVE_PATH: String = "user://save.json"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_session()

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

## Bank $SMOKE tokens earned in Blaze Rush runs.
func add_smoke(amount: int) -> void:
    if amount <= 0:
        return
    smoke_collected += amount
    smoke_changed.emit(smoke_collected)

func take_damage(amount: int) -> void:
    if current_power_up == "diamond":
        deactivate_power_up()
        return
    player_health -= amount
    if player_health < 0:
        player_health = 0
    health_changed.emit(player_health)
    if player_health <= 0:
        GoldMineSystem.on_player_death()
        player_died.emit()
        StateMachine.change_state(StateMachine.State.GAME_OVER)

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
    # The HUD in the incoming level _ready()s BEFORE the player spawns and
    # reads these values — without this emit it keeps showing the previous
    # level's damaged heart count until the next hit.
    health_changed.emit(player_health)

func reset_session() -> void:
    player_health = max_health
    current_power_up = ""
    power_up_timer = 0.0
    health_changed.emit(player_health)
    total_score = 0
    coins_collected = 0
    ethereum_rings_collected = 0
    smoke_collected = 0
    smoke_changed.emit(0)
    blaze_rush_completed.clear()
    dash_return = {}
    level_checkpoints.clear()
    GoldMineSystem.reset_session()

func save_checkpoint(level: int, checkpoint_id: int, pos: Vector2) -> void:
    level_checkpoints[level] = {"id": checkpoint_id, "pos": pos}

func get_checkpoint(level: int) -> Vector2:
    if level in level_checkpoints:
        return level_checkpoints[level].pos
    return Vector2.ZERO

func save_session() -> bool:
    var data: Dictionary = {
        "total_score": total_score,
        "coins": coins_collected,
        "rings": ethereum_rings_collected,
        "smoke": smoke_collected,
        "blaze_rush": _serialize_blaze_completions(),
        "health": player_health,
        "max_health": max_health,
        "current_level": current_level,
        "checkpoints": _serialize_checkpoints(),
        "goldmine": GoldMineSystem.get_save_data(),
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        push_error("GameManager.save_session: cannot open %s" % SAVE_PATH)
        return false
    f.store_string(JSON.stringify(data))
    f.close()
    return true

func load_session() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return false
    var raw := f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var data: Dictionary = parsed
    total_score = int(data.get("total_score", 0))
    coins_collected = int(data.get("coins", 0))
    ethereum_rings_collected = int(data.get("rings", 0))
    smoke_collected = int(data.get("smoke", 0))
    _deserialize_blaze_completions(data.get("blaze_rush", {}))
    player_health = int(data.get("health", max_health))
    max_health = int(data.get("max_health", 3))
    current_level = int(data.get("current_level", 1))
    _deserialize_checkpoints(data.get("checkpoints", {}))
    if data.has("goldmine"):
        GoldMineSystem.load_save_data(data.get("goldmine", {}))
    return true

func _serialize_checkpoints() -> Dictionary:
    var out: Dictionary = {}
    for level in level_checkpoints.keys():
        var cp: Dictionary = level_checkpoints[level]
        out[str(level)] = {
            "id": cp.id,
            "x": cp.pos.x,
            "y": cp.pos.y,
        }
    return out

func _serialize_blaze_completions() -> Dictionary:
    var out: Dictionary = {}
    for level in blaze_rush_completed.keys():
        out[str(level)] = bool(blaze_rush_completed[level])
    return out

func _deserialize_blaze_completions(raw: Dictionary) -> void:
    blaze_rush_completed.clear()
    for k in raw.keys():
        blaze_rush_completed[int(k)] = bool(raw[k])

func _deserialize_checkpoints(raw: Dictionary) -> void:
    level_checkpoints.clear()
    for k in raw.keys():
        var entry: Dictionary = raw[k]
        level_checkpoints[int(k)] = {
            "id": int(entry.get("id", 0)),
            "pos": Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
        }
