extends Control

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var connect_wallet_btn: Button = $VBoxContainer/ConnectWalletButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var title: Label = $VBoxContainer/TitleLabel

func _ready() -> void:
    StateMachine.change_state(StateMachine.State.MENU)
    play_btn.pressed.connect(_on_play)
    continue_btn.pressed.connect(_on_continue)
    connect_wallet_btn.pressed.connect(_on_connect_wallet)
    quit_btn.pressed.connect(_on_quit)
    Web3Manager.wallet_connected.connect(_on_wallet_connected)
    title.text = "🌿 LIL BLUNT 🌿\nTHE SMOKE REALM"
    # Show continue button only if save file exists
    if FileAccess.file_exists(GameManager.SAVE_PATH):
        continue_btn.show()
    else:
        continue_btn.hide()
    # Update wallet button text
    _update_wallet_button()
    # Animate title
    var tween := create_tween().set_loops()
    tween.tween_property(title, "scale", Vector2(1.05, 1.05), 0.8)
    tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.8)

func _on_play() -> void:
    AudioManager.play_sfx("powerup")
    GameManager.reset_session()
    SceneRouter.load_scene("res://src/level/level_01_smoke_realm.tscn", SceneRouter.Transition.FADE)

func _on_continue() -> void:
    AudioManager.play_sfx("powerup")
    GameManager.load_session()
    SceneRouter.load_scene("res://src/level/level_01_smoke_realm.tscn", SceneRouter.Transition.FADE)

func _on_connect_wallet() -> void:
    AudioManager.play_sfx("powerup")
    if Web3Manager.is_connected:
        Web3Manager.disconnect_wallet()
    else:
        Web3Manager.connect_wallet()
    _update_wallet_button()

func _on_wallet_connected(address: String) -> void:
    _update_wallet_button()

func _update_wallet_button() -> void:
    if Web3Manager.is_connected:
        connect_wallet_btn.text = "DISCONNECT WALLET"
    else:
        connect_wallet_btn.text = "CONNECT WALLET"

func _on_quit() -> void:
    get_tree().quit()
