extends Control

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var title: Label = $VBoxContainer/TitleLabel

func _ready() -> void:
    play_btn.pressed.connect(_on_play)
    quit_btn.pressed.connect(_on_quit)
    title.text = "🌿 LIL BLUNT 🌿\nTHE SMOKE REALM"
    # Animate title
    var tween := create_tween().set_loops()
    tween.tween_property(title, "scale", Vector2(1.05, 1.05), 0.8)
    tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.8)

func _on_play() -> void:
    AudioManager.play_sfx("powerup")
    SceneTransition.transition_to_scene("res://level/level_01_smoke_realm.tscn")

func _on_quit() -> void:
    get_tree().quit()
