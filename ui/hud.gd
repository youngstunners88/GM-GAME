extends CanvasLayer

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var health_container: HBoxContainer = $MarginContainer/VBoxContainer/HealthContainer
@onready var coin_label: Label = $MarginContainer/VBoxContainer/CoinLabel
@onready var ring_label: Label = $MarginContainer/VBoxContainer/RingLabel
@onready var powerup_label: Label = $MarginContainer/VBoxContainer/PowerUpLabel
@onready var powerup_bar: ProgressBar = $MarginContainer/VBoxContainer/PowerUpBar

var heart_full: String = "❤"
var heart_empty: String = "♡"

func _ready() -> void:
    GameManager.score_changed.connect(_on_score_changed)
    GameManager.health_changed.connect(_on_health_changed)
    GameManager.coins_changed.connect(_on_coins_changed)
    GameManager.rings_changed.connect(_on_rings_changed)
    GameManager.power_up_changed.connect(_on_power_up_changed)
    GameManager.player_died.connect(_on_player_died)

    _on_score_changed(GameManager.total_score)
    _on_health_changed(GameManager.player_health)
    _on_coins_changed(GameManager.coins_collected)
    _on_rings_changed(GameManager.ethereum_rings_collected)
    powerup_label.text = ""
    powerup_bar.visible = false

func _process(_delta: float) -> void:
    if GameManager.power_up_timer > 0 and GameManager.current_power_up != "":
        var max_time := 12.0 if GameManager.current_power_up == "blaze" else (10.0 if GameManager.current_power_up == "big" else 8.0)
        powerup_bar.value = (GameManager.power_up_timer / max_time) * 100.0
    else:
        powerup_bar.visible = false

func _on_score_changed(new_score: int) -> void:
    score_label.text = "SCORE: %06d" % new_score

func _on_health_changed(new_health: int) -> void:
    # Clear and rebuild hearts
    for child in health_container.get_children():
        child.queue_free()
    for i in range(GameManager.max_health):
        var heart := Label.new()
        heart.text = heart_full if i < new_health else heart_empty
        heart.add_theme_font_size_override("font_size", 32)
        health_container.add_child(heart)

func _on_coins_changed(new_count: int) -> void:
    coin_label.text = "🪙 %d" % new_count

func _on_rings_changed(new_count: int) -> void:
    ring_label.text = "💍 %d" % new_count

func _on_power_up_changed(type: String, _duration: float) -> void:
    if type == "":
        powerup_label.text = ""
        powerup_bar.visible = false
        return
    var names := {"blaze": "🔥 BLAZE MODE", "big": "🍄 BIG MODE", "diamond": "💎 DIAMOND SHIELD"}
    powerup_label.text = names.get(type, type.to_upper())
    powerup_bar.visible = true
    powerup_bar.value = 100.0

func _on_player_died() -> void:
    var game_over := Label.new()
    game_over.text = "YOU DIED\nRespawning..."
    game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_over.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2 - 50)
    game_over.add_theme_font_size_override("font_size", 48)
    add_child(game_over)
    await get_tree().create_timer(1.5).timeout
    game_over.queue_free()
