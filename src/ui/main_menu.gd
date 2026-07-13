extends Control

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var title: Label = $VBoxContainer/TitleLabel

const VERSION_TAG := "v1.0.0 — BLOCK 420"

func _ready() -> void:
    StateMachine.change_state(StateMachine.State.MENU)
    play_btn.pressed.connect(_on_play)
    continue_btn.pressed.connect(_on_continue)
    quit_btn.pressed.connect(_on_quit)
    title.text = "LIL BLUNT\nTHE SMOKE REALM"
    AudioManager.play_voice("menu_title")
    _setup_backdrop()
    _setup_ambience()
    for btn: Button in [play_btn, continue_btn, quit_btn]:
        _add_hover_glow(btn)
    # Show continue button only if save file exists
    if FileAccess.file_exists(GameManager.SAVE_PATH):
        continue_btn.show()
    else:
        continue_btn.hide()
    # Animate title
    var tween := create_tween().set_loops()
    tween.tween_property(title, "scale", Vector2(1.05, 1.05), 0.8)
    tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.8)

## GM Forest key art behind the menu; the existing flat ColorRect becomes a
## translucent darkener so buttons and title stay readable over the painting.
func _setup_backdrop() -> void:
    var bg := TextureRect.new()
    bg.texture = load("res://src/assets/backgrounds/bg_l1_forest.jpg")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    move_child(bg, 0)
    var overlay := get_node_or_null("ColorRect") as ColorRect
    if overlay:
        overlay.color = Color(0, 0, 0, 0.6)
        move_child(overlay, 1)

## Drifting smoke + floating ETH rings — the menu breathes instead of sitting.
func _setup_ambience() -> void:
    var smoke := CPUParticles2D.new()
    smoke.amount = 14
    smoke.lifetime = 6.0
    smoke.preprocess = 6.0
    smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    smoke.emission_rect_extents = Vector2(700, 40)
    smoke.position = Vector2(640, 760)
    smoke.direction = Vector2(0, -1)
    smoke.spread = 20.0
    smoke.gravity = Vector2(6, -14)
    smoke.initial_velocity_min = 18.0
    smoke.initial_velocity_max = 42.0
    smoke.scale_amount_min = 24.0
    smoke.scale_amount_max = 60.0
    smoke.color = Color(0.75, 0.9, 0.78, 0.06)
    add_child(smoke)

    var ring_tex: Texture2D = load("res://src/assets/sprites/sprite_item_eth-ring.png")
    for i in range(3):
        var ring := Sprite2D.new()
        ring.texture = ring_tex
        ring.modulate = Color(1, 1, 1, 0.55)
        ring.position = Vector2(200 + i * 420, 160 + (i % 2) * 320)
        add_child(ring)
        var tw := ring.create_tween().set_loops()
        tw.tween_property(ring, "position:y", ring.position.y - 26.0, 2.2 + i * 0.4) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tw.tween_property(ring, "position:y", ring.position.y, 2.2 + i * 0.4) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    var version := Label.new()
    version.text = VERSION_TAG
    version.modulate = Color(1, 1, 1, 0.5)
    version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    version.position = Vector2(get_viewport().get_visible_rect().size.x - 210,
            get_viewport().get_visible_rect().size.y - 34)
    add_child(version)

## Buttons brighten on hover/focus (keyboard AND mouse per UI rules).
func _add_hover_glow(btn: Button) -> void:
    var glow := func() -> void:
        var tw := btn.create_tween()
        tw.tween_property(btn, "modulate", Color(1.25, 1.2, 0.9), 0.12)
    var unglow := func() -> void:
        var tw := btn.create_tween()
        tw.tween_property(btn, "modulate", Color.WHITE, 0.15)
    btn.mouse_entered.connect(glow)
    btn.mouse_exited.connect(unglow)
    btn.focus_entered.connect(glow)
    btn.focus_exited.connect(unglow)

func _on_play() -> void:
    AudioManager.play_sfx("powerup")
    GameManager.reset_session()
    SceneRouter.load_scene("res://src/level/level_01_smoke_realm.tscn", SceneRouter.Transition.FADE)

func _on_continue() -> void:
    AudioManager.play_sfx("powerup")
    GameManager.load_session()
    SceneRouter.load_scene("res://src/level/level_01_smoke_realm.tscn", SceneRouter.Transition.FADE)

func _on_quit() -> void:
    get_tree().quit()
