extends CanvasLayer

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var health_container: HBoxContainer = $MarginContainer/VBoxContainer/HealthContainer
@onready var coin_label: Label = $MarginContainer/VBoxContainer/CoinLabel
@onready var ring_label: Label = $MarginContainer/VBoxContainer/RingLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/GoldLabel
@onready var wbtc_label: Label = $MarginContainer/VBoxContainer/WbtcLabel
@onready var xaut_label: Label = $MarginContainer/VBoxContainer/XautLabel
@onready var diamond_label: Label = $MarginContainer/VBoxContainer/DiamondLabel
@onready var smoke_label: Label = $MarginContainer/VBoxContainer/SmokeLabel
@onready var powerup_label: Label = $MarginContainer/VBoxContainer/PowerUpLabel
@onready var powerup_bar: ProgressBar = $MarginContainer/VBoxContainer/PowerUpBar

# Heart pips are ColorRects, not glyphs: the web export's default font has no
# emoji, so ❤/🪙/💎 render as tofu boxes (see 2026-07-11 stress screenshots).
const HEART_FULL_COLOR := Color(0.95, 0.25, 0.35, 1.0)
const HEART_EMPTY_COLOR := Color(0.25, 0.22, 0.28, 0.9)

var heart_pips: Array[ColorRect] = []
var _prev_health: int = -1
var _flash_rect: ColorRect
var _combo_label: Label

func _ready() -> void:
    GameManager.score_changed.connect(_on_score_changed)
    GameManager.health_changed.connect(_on_health_changed)
    GameManager.coins_changed.connect(_on_coins_changed)
    GameManager.rings_changed.connect(_on_rings_changed)
    GameManager.smoke_changed.connect(_on_smoke_changed)
    GameManager.power_up_changed.connect(_on_power_up_changed)
    GameManager.player_died.connect(_on_player_died)
    GoldMineSystem.gold_changed.connect(_on_gold_changed)
    GoldMineSystem.wbtc_changed.connect(_on_wbtc_changed)
    GoldMineSystem.xaut_changed.connect(_on_xaut_changed)
    GoldMineSystem.diamonds_changed.connect(_on_diamonds_changed)
    GoldMineSystem.auction_complete.connect(_on_auction_complete)
    GoldMineSystem.certificate_earned.connect(_on_certificate_earned)

    # Pre-build heart pips once
    for i in range(GameManager.max_health):
        var heart := ColorRect.new()
        heart.color = HEART_FULL_COLOR
        heart.custom_minimum_size = Vector2(22, 22)
        health_container.add_child(heart)
        heart_pips.append(heart)
    health_container.add_theme_constant_override("separation", 6)

    ComboSystem.combo_changed.connect(_on_combo_changed)
    StateMachine.state_changed.connect(_on_state_changed)

    # White damage flash — sits over gameplay, ignores input, starts invisible.
    _flash_rect = ColorRect.new()
    _flash_rect.color = Color(1, 1, 1, 0)
    _flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_flash_rect)

    # Combo counter — pops center-top when a streak is running.
    _combo_label = Label.new()
    _combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _combo_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 80, 60)
    _combo_label.add_theme_font_size_override("font_size", 32)
    _combo_label.add_theme_constant_override("outline_size", 6)
    _combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    _combo_label.text = ""
    add_child(_combo_label)

    _on_score_changed(GameManager.total_score)
    _on_health_changed(GameManager.player_health)
    _on_coins_changed(GameManager.coins_collected)
    _on_rings_changed(GameManager.ethereum_rings_collected)
    _on_smoke_changed(GameManager.smoke_collected)
    _on_gold_changed(GoldMineSystem.gold_balance)
    _on_wbtc_changed(GoldMineSystem.wbtc_balance)
    _on_xaut_changed(GoldMineSystem.xaut_balance)
    _on_diamonds_changed(GoldMineSystem.diamonds_balance)
    powerup_label.text = ""
    powerup_bar.visible = false

func _process(_delta: float) -> void:
    if GameManager.power_up_timer > 0 and GameManager.current_power_up != "":
        var durations := {"blaze": 12.0, "big": 10.0, "diamond": 8.0, "purple": 15.0, "pickaxe": 20.0, "torch": 20.0}
        var max_time: float = durations.get(GameManager.current_power_up, 8.0)
        powerup_bar.value = (GameManager.power_up_timer / max_time) * 100.0
    else:
        powerup_bar.visible = false

func _on_score_changed(new_score: int) -> void:
    score_label.text = "SCORE: %06d" % new_score

func _on_health_changed(new_health: int) -> void:
    for i in range(heart_pips.size()):
        heart_pips[i].color = HEART_FULL_COLOR if i < new_health else HEART_EMPTY_COLOR
    # Damage feedback: brief white screen flash + heart-row shake — only when
    # health went DOWN (not on heal/respawn refill).
    if _prev_health >= 0 and new_health < _prev_health:
        var flash := create_tween()
        flash.tween_property(_flash_rect, "color:a", 0.3, 0.03)
        flash.tween_property(_flash_rect, "color:a", 0.0, 0.1)
        var base_x := health_container.position.x
        var shake := create_tween()
        for offset in [6.0, -5.0, 3.0, 0.0]:
            shake.tween_property(health_container, "position:x", base_x + offset, 0.04)
    _prev_health = new_health

## Combo pop: scales with a bounce and heats white → gold → red as it climbs.
func _on_combo_changed(value: int) -> void:
    if value < 2:
        _combo_label.text = ""
        return
    _combo_label.text = "COMBO x%d" % value
    if value >= 8:
        _combo_label.modulate = Color(1.0, 0.3, 0.25)
    elif value >= 4:
        _combo_label.modulate = Color(1.0, 0.84, 0.2)
    else:
        _combo_label.modulate = Color.WHITE
    _combo_label.scale = Vector2.ONE
    var tween := create_tween()
    tween.tween_property(_combo_label, "scale", Vector2(1.3, 1.3), 0.08)
    tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.12)

## Victory confetti the moment the level completes, at the player's position.
func _on_state_changed(_from: String, to_state: String) -> void:
    if to_state == "LEVEL_COMPLETE":
        EffectSpawner.burst("confetti", GameManager.player_position + Vector2(0, -40))

func _on_coins_changed(new_count: int) -> void:
    coin_label.text = "COINS %d" % new_count

func _on_rings_changed(new_count: int) -> void:
    ring_label.text = "RINGS %d" % new_count

func _on_smoke_changed(new_count: int) -> void:
    smoke_label.text = "PUFFS %d" % new_count

func _on_power_up_changed(type: String, _duration: float) -> void:
    if type == "":
        powerup_label.text = ""
        powerup_bar.visible = false
        return
    var names := {"blaze": "BLAZE MODE", "big": "BIG MODE", "diamond": "DIAMOND SHIELD", "purple": "PURPLE POWER", "pickaxe": "PICKAXE", "torch": "TORCH"}
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

func _on_gold_changed(new_amount: int) -> void:
    gold_label.text = "GOLD %d" % new_amount

func _on_wbtc_changed(new_amount: int) -> void:
    wbtc_label.text = "wBTC %d" % new_amount

func _on_xaut_changed(new_amount: int) -> void:
    xaut_label.text = "XAUT %d" % new_amount

func _on_diamonds_changed(new_amount: int) -> void:
    diamond_label.text = "DIAMONDS %d" % new_amount

func _on_auction_complete(xaut_won: int, multiplier: float) -> void:
    var toast := Label.new()
    toast.text = "GOLD RUSH AUCTION\n+%d XAUT (%.1f%% share)" % [xaut_won, multiplier * 100.0]
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.position = Vector2(get_viewport().size.x / 2 - 150, 120)
    toast.add_theme_font_size_override("font_size", 28)
    toast.modulate = Color(1.0, 0.84, 0.0, 1.0)
    add_child(toast)
    var tween := create_tween()
    tween.tween_interval(2.5)
    tween.tween_property(toast, "modulate:a", 0.0, 0.4)
    tween.finished.connect(toast.queue_free)

func _on_certificate_earned(count: int) -> void:
    var toast := Label.new()
    toast.text = "GOLD CLAIM CERTIFICATE x%d" % count
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.position = Vector2(get_viewport().size.x / 2 - 150, 180)
    toast.add_theme_font_size_override("font_size", 24)
    toast.modulate = Color(0.0, 1.0, 0.8, 1.0)
    add_child(toast)
    var tween := create_tween()
    tween.tween_interval(3.0)
    tween.tween_property(toast, "modulate:a", 0.0, 0.4)
    tween.finished.connect(toast.queue_free)
