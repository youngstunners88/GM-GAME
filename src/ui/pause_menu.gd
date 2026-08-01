extends CanvasLayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()
    StateMachine.state_changed.connect(_on_state_changed)

func _on_state_changed(_from: String, to: String) -> void:
    visible = (to == "PAUSED")

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_just_pressed("ui_cancel"):
        if StateMachine.is_playing():
            StateMachine.change_state(StateMachine.State.PAUSED)
        elif StateMachine.is_paused():
            StateMachine.change_state(StateMachine.State.PLAYING)

func _on_resume_pressed() -> void:
    if StateMachine.is_paused():
        StateMachine.change_state(StateMachine.State.PLAYING)

func _on_restart_pressed() -> void:
    if StateMachine.is_paused():
        StateMachine.change_state(StateMachine.State.PLAYING)
    GameManager.reset_session()
    SceneRouter.load_scene(get_tree().current_scene.scene_file_path, SceneRouter.Transition.FADE)

## Companion chat, reachable mid-run from the pause menu. Opened here rather
## than on a hotkey so it can never eat a gameplay input, and because the
## pause menu is already PROCESS_MODE_ALWAYS. The panel pauses/unpauses the
## tree itself, so hide this menu first to avoid two overlapping overlays.
func _on_talk_pressed() -> void:
    var panel := preload("res://src/ui/companion_panel.tscn").instantiate()
    get_tree().current_scene.add_child(panel)
    hide()
    panel.open()
    # Returning from the companion should land back in the pause menu, not
    # straight into gameplay — otherwise closing it silently unpauses.
    panel.tree_exited.connect(func() -> void:
        if StateMachine.is_paused():
            show())

func _on_quit_pressed() -> void:
    if StateMachine.is_paused():
        StateMachine.change_state(StateMachine.State.PLAYING)
    GameManager.save_session()
    GameManager.reset_session()
    SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.FADE)
