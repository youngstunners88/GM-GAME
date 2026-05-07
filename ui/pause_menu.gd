extends CanvasLayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_just_pressed("ui_cancel"):
        toggle_pause()

func toggle_pause() -> void:
    if visible:
        resume()
    else:
        pause()

func pause() -> void:
    get_tree().paused = true
    show()

func resume() -> void:
    get_tree().paused = false
    hide()

func _on_resume_pressed() -> void:
    resume()

func _on_restart_pressed() -> void:
    get_tree().paused = false
    GameManager.reset_session()
    get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
    get_tree().paused = false
    GameManager.reset_session()
    get_tree().change_scene_to_file("res://ui/main_menu.tscn")
