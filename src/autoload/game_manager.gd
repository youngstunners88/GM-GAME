extends Node

signal score_changed(new_score: int)
signal health_changed(new_health: int)
signal power_up_changed(type: String, duration: float)
signal coins_changed(new_count: int)
signal rings_changed(new_count: int)
signal smoke_changed(new_count: int)
signal player_died
signal lives_changed(new_lives: int)

# Persistent player data only — no state booleans (those live in StateMachine).
var total_score: int = 0
var coins_collected: int = 0
var ethereum_rings_collected: int = 0
var smoke_collected: int = 0
# Blaze Rush (secret dash mode) bookkeeping.
var blaze_rush_completed: Dictionary = {}   # level_index -> true once one-time bonuses paid
var dash_return: Dictionary = {}            # transient: scene_path/position/level_index for the return trip
var secret_return: Dictionary = {}          # transient: scene_path/position to return from a secret realm
var player_health: int = 3
var max_health: int = 3
## Lives — a hard fail (falling into a pit) costs one. Out of lives = game over.
var lives: int = 3
var max_lives: int = 3
var current_power_up: String = ""
var power_up_timer: float = 0.0
var current_level: int = 1
var level_checkpoints: Dictionary = {}
var player_position: Vector2 = Vector2.ZERO
## Analytics attribution (task #23): the last thing that hurt the player
## ("tax", "boulder", "vine", "fly", "pit", boss ids). Written by enemies/
## hazards on contact, read by player death reporting. Display-only data.
var last_damage_source: String = ""

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

## Spend a life (pit fall). Returns true if that was the LAST life (game over).
## On a surviving loss, health refills so the checkpoint respawn is fair.
func lose_life() -> bool:
    lives -= 1
    if lives < 0:
        lives = 0
    lives_changed.emit(lives)
    if lives <= 0:
        GoldMineSystem.on_player_death()
        player_died.emit()
        StateMachine.change_state(StateMachine.State.GAME_OVER)
        return true
    player_health = max_health
    health_changed.emit(player_health)
    return false

func activate_power_up(type: String, duration: float) -> void:
    current_power_up = type
    power_up_timer = duration
    power_up_changed.emit(type, duration)
    AudioManager.play_sfx("powerup")
    if type == "blaze":
        AudioManager.play_sfx("fresh_boost")
    # Analytics (task #23): which power-ups actually get used feeds the
    # founder digest + future tuning. Fire-and-forget, no-op offline.
    Web3Bridge.report_metric("powerup_used", {"type": type})

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
    lives = max_lives
    lives_changed.emit(lives)
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
        "lives": lives,
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
    # Clamp everything from disk: user://save.json is player-editable, and
    # unclamped values (9999 health, level 42) corrupt the session state.
    # max_health loads FIRST so the health clamp uses the loaded ceiling
    # (the old order clamped against the previous session's value).
    total_score = maxi(0, int(data.get("total_score", 0)))
    coins_collected = maxi(0, int(data.get("coins", 0)))
    ethereum_rings_collected = maxi(0, int(data.get("rings", 0)))
    smoke_collected = maxi(0, int(data.get("smoke", 0)))
    _deserialize_blaze_completions(data.get("blaze_rush", {}))
    max_health = clampi(int(data.get("max_health", 3)), 1, 10)
    player_health = clampi(int(data.get("health", max_health)), 1, max_health)
    # Lives persist too (Kimi audit): reloading mid-run must not refill them.
    lives = clampi(int(data.get("lives", max_lives)), 0, max_lives)
    lives_changed.emit(lives)
    current_level = clampi(int(data.get("current_level", 1)), 1, 3)
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

# ---- Offline mode (task: offline-mode skill, Video-Game Layer) -------------
# The game adapts to network state without breaking: a banner appears when the
# backend is unreachable, disappears on silent reconnect+sync (Web3Bridge owns
# probing, queueing, and cache; this owns the player-facing flag + banner).

## Global flag other systems may consult (oracle panel, menu wallet button).
var offline_mode: bool = false
var _offline_banner: CanvasLayer

func _enter_tree() -> void:
    # Deferred: Web3Bridge loads after GameManager in autoload order.
    call_deferred("_wire_offline_mode")

func _wire_offline_mode() -> void:
    if not has_node("/root/Web3Bridge"):
        return
    Web3Bridge.connectivity_changed.connect(_on_connectivity_changed)

func _on_connectivity_changed(online: bool) -> void:
    offline_mode = not online
    if offline_mode:
        _show_offline_banner()
    else:
        _hide_offline_banner()

func _show_offline_banner() -> void:
    if _offline_banner != null and is_instance_valid(_offline_banner):
        return
    _offline_banner = CanvasLayer.new()
    _offline_banner.layer = 99
    var lbl := Label.new()
    lbl.name = "Banner"
    lbl.text = "OFFLINE MODE — scores saved locally, will sync when reconnected"
    lbl.add_theme_font_size_override("font_size", 14)
    lbl.modulate = Color(1.0, 0.85, 0.5, 0.95)
    lbl.position = Vector2(12, 6)
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.08, 0.02, 0.75)
    bg.size = Vector2(520, 26)
    bg.position = Vector2(6, 4)
    _offline_banner.add_child(bg)
    _offline_banner.add_child(lbl)
    get_tree().root.add_child.call_deferred(_offline_banner)

func _hide_offline_banner() -> void:
    if _offline_banner != null and is_instance_valid(_offline_banner):
        _offline_banner.queue_free()
    _offline_banner = null

# ---- Shareable taglines (content engine feeds this list weekly) ------------
# Rotated into snapshot-moment X shares. PRIMARY source: the 50-seed
# res://src/autoload/share_taglines.json (Kimi K3, human-reviewed, packed into
# the export). The const below is the guaranteed fallback if the JSON is
# missing/corrupt. Weekly refreshes: content_engine/score_card_taglines.js.

var _loaded_taglines: Array = []

func _load_share_taglines() -> void:
    const PATH := "res://src/autoload/share_taglines.json"
    if not FileAccess.file_exists(PATH):
        return
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f == null:
        return
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        var arr: Variant = (parsed as Dictionary).get("taglines", [])
        if typeof(arr) == TYPE_ARRAY and (arr as Array).size() >= 5:
            _loaded_taglines = arr

const SHARE_TAGLINES: Array[String] = [
    "Diamond hands, cloud feet.",
    "HODL my bong, I'm going in.",
    "Gas fees can't tax a double-jump.",
    "Bear market? My vibes are up only.",
    "Chill is the ultimate utility.",
    "Rug pulls fear the double-jump.",
    "Proof of Chill > Proof of Work.",
    "Staked, baked, and never shaked.",
    "My portfolio dips, Lil Blunt don't.",
    "Smoke Realm: where floors are lava, not prices.",
]

func random_tagline() -> String:
    if _loaded_taglines.is_empty():
        _load_share_taglines()
    if not _loaded_taglines.is_empty():
        return str(_loaded_taglines[randi() % _loaded_taglines.size()])
    return SHARE_TAGLINES[randi() % SHARE_TAGLINES.size()]
