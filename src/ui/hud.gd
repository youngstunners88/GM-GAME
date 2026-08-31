extends CanvasLayer

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var health_container: HBoxContainer = $MarginContainer/VBoxContainer/HealthContainer
@onready var coin_label: Label = $MarginContainer/VBoxContainer/CoinLabel
@onready var ring_label: Label = $MarginContainer/VBoxContainer/RingLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/GoldLabel
@onready var wbtc_label: Label = $MarginContainer/VBoxContainer/WbtcLabel
@onready var xaut_label: Label = $MarginContainer/VBoxContainer/XautLabel
@onready var diamond_label: Label = $MarginContainer/VBoxContainer/DiamondLabel
## $TITANX — the 4th protocol token, grouped under the "TOKENS" header with
## GOLD/DIAMONDS/wBTC/XAUT. Founder: "$TITANX, $DIAMONDS, AND $GOLD are
## tokens and not coins."
@onready var titanx_label: Label = $MarginContainer/VBoxContainer/TitanxLabel
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
var _lives_label: Label

func _ready() -> void:
    _build_fullscreen_button()
    GameManager.score_changed.connect(_on_score_changed)
    GameManager.health_changed.connect(_on_health_changed)
    GameManager.coins_changed.connect(_on_coins_changed)
    GameManager.rings_changed.connect(_on_rings_changed)
    GameManager.smoke_changed.connect(_on_smoke_changed)
    GameManager.titanx_changed.connect(_on_titanx_changed)
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
    GameManager.lives_changed.connect(_on_lives_changed)

    # Lives counter — top-right, so the pit-fall stakes are always visible.
    _lives_label = Label.new()
    _lives_label.add_theme_font_size_override("font_size", 22)
    _lives_label.add_theme_constant_override("outline_size", 5)
    _lives_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    _lives_label.position = Vector2(get_viewport().get_visible_rect().size.x - 150, 14)
    add_child(_lives_label)
    _on_lives_changed(GameManager.lives)

    # BUILD TAG — bottom-left corner, always visible (merged 2026-08-26 residual
    # Phase 0). A founder hard-refresh must SEE this string; if it shows an older
    # tag than the ship, they are on a stale cache and every other check is moot.
    var build_label := Label.new()
    build_label.text = "BUILD %s" % GameManager.BUILD_TAG
    build_label.add_theme_font_size_override("font_size", 13)
    build_label.add_theme_constant_override("outline_size", 4)
    build_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 0.85))
    build_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    build_label.position = Vector2(10, get_viewport().get_visible_rect().size.y - 26)
    add_child(build_label)

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

    _show_control_hint()

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
        var durations := {"blaze": 12.0, "big": 10.0, "diamond": 8.0, "purple": 15.0, "pickaxe": 20.0, "torch": 20.0, "fly": 10.0}
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
        for offset: float in [6.0, -5.0, 3.0, 0.0]:
            shake.tween_property(health_container, "position:x", base_x + offset, 0.04)
    _prev_health = new_health

## Bottom-center controls reminder at level start — attacking was
## undiscoverable (no prompt that J / ATK throws). Fades out after 6s.
func _show_control_hint() -> void:
    var hint := Label.new()
    # Input-aware: keyboard players see keys, touch players see tap targets
    # (showing "A/D · W/Space" on a phone with no keyboard was useless — Kimi
    # font-audit 2026-08-01). Full controls live in the HOW TO PLAY panel.
    var touch := OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
    if touch:
        hint.text = "MOVE  < >   ·   JUMP   ·   ATK   ·   CLIMB  UP/DOWN"
    else:
        hint.text = "MOVE  A/D  ·  JUMP  W/Space  ·  ATTACK  J  ·  DASH  K"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 26)
    hint.add_theme_constant_override("outline_size", 5)
    hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    hint.modulate = Color(1, 1, 1, 0.9)
    var vw := get_viewport().get_visible_rect().size
    hint.position = Vector2(vw.x / 2 - 350, vw.y - 56)
    hint.custom_minimum_size.x = 700
    add_child(hint)
    var tween := create_tween()
    tween.tween_interval(6.0)
    tween.tween_property(hint, "modulate:a", 0.0, 1.0)
    tween.finished.connect(hint.queue_free)

## Lives counter — pulses red when a life is lost.
func _on_lives_changed(new_lives: int) -> void:
    if _lives_label == null:
        return
    _lives_label.text = "LIVES  %d" % new_lives
    _lives_label.modulate = Color(1.0, 0.4, 0.4)
    var tween := create_tween()
    tween.tween_property(_lives_label, "scale", Vector2(1.3, 1.3), 0.1)
    tween.tween_property(_lives_label, "scale", Vector2.ONE, 0.15)
    tween.parallel().tween_property(_lives_label, "modulate", Color.WHITE, 0.4)

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

func _on_titanx_changed(new_count: int) -> void:
    titanx_label.text = "TITANX %d" % new_count

func _on_smoke_changed(new_count: int) -> void:
    # Founder: "The 'PUFFS' text needs to be changed to 'BLAZE DIAMONDS'."
    # Same underlying counter (GameManager.smoke_collected) — this is the
    # blue flaming diamond token from Blaze Rush plus the secret realm's
    # smoke clouds. Distinct from `diamond_label` below, which is the
    # GoldMine DIAMONDS protocol allocation; the "BLAZE" qualifier keeps the
    # two readable as different things on the same HUD.
    smoke_label.text = "BLAZE DIAMONDS %d" % new_count

func _on_power_up_changed(type: String, _duration: float) -> void:
    if type == "":
        powerup_label.text = ""
        powerup_bar.visible = false
        return
    var names := {"blaze": "BLAZE MODE", "big": "BIG MODE", "diamond": "DIAMOND SHIELD", "purple": "PURPLE POWER", "pickaxe": "PICKAXE", "torch": "TORCH", "fly": "BONG LIFT-OFF"}
    powerup_label.text = names.get(type, type.to_upper())
    powerup_bar.visible = true
    powerup_bar.value = 100.0

func _on_player_died() -> void:
    var game_over := Label.new()
    game_over.text = "YOU DIED\nRespawning..."
    game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    # get_visible_rect(), NOT get_viewport().size: with canvas_items+expand they
    # disagree on every window that isn't exactly 1280x720 (i.e. every phone),
    # which parked this and the two toasts below off-centre (Kimi font-audit #3).
    var _vs := get_viewport().get_visible_rect().size
    game_over.position = Vector2(_vs.x / 2 - 100, _vs.y / 2 - 50)
    game_over.add_theme_font_size_override("font_size", 48)
    game_over.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    game_over.add_theme_constant_override("outline_size", 6)
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
    toast.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, 120)
    toast.add_theme_font_size_override("font_size", 30)
    toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    toast.add_theme_constant_override("outline_size", 5)
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
    toast.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, 180)
    toast.add_theme_font_size_override("font_size", 28)
    toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    toast.add_theme_constant_override("outline_size", 5)
    toast.modulate = Color(0.0, 1.0, 0.8, 1.0)
    add_child(toast)
    var tween := create_tween()
    tween.tween_interval(3.0)
    tween.tween_property(toast, "modulate:a", 0.0, 0.4)
    tween.finished.connect(toast.queue_free)


## Top-right EXPAND button — the discoverable half of FullscreenToggle.
##
## Founder, three separate passes: "I'm so sick of playing this game on such a
## small payview screen." The blank area around the game is the itch.io page's
## embed frame, which is a dashboard setting and not something this build can
## resize. A fullscreen control makes that irrelevant: one click and the game
## owns the whole monitor.
##
## It is a BUTTON, not just the F key, because browsers only grant fullscreen
## from a genuine user gesture and because a keybind he has never been told
## about does not exist as far as he is concerned. Anchored top-right so it
## cannot cover the score/lives column on the left.
func _build_fullscreen_button() -> void:
    var btn := Button.new()
    btn.name = "FullscreenButton"
    btn.text = "⛶"
    btn.tooltip_text = "Fullscreen (F)"
    btn.focus_mode = Control.FOCUS_NONE
    btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    btn.position = Vector2(-96, 8)
    btn.custom_minimum_size = Vector2(56, 44)
    btn.add_theme_font_size_override("font_size", 26)
    # mouse_filter STOP on the button itself only; the HUD root stays PASS so
    # this cannot swallow gameplay clicks anywhere else on screen.
    btn.mouse_filter = Control.MOUSE_FILTER_STOP
    btn.pressed.connect(func() -> void:
        FullscreenToggle.toggle()
        btn.text = "⛶"
    )
    add_child(btn)
