extends CanvasLayer

@onready var fade_rect: ColorRect = $ColorRect

func _ready() -> void:
    fade_rect.color = Color(0, 0, 0, 0)
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func transition_to_scene(path: String) -> void:
    var tween := create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
    await tween.finished
    var err := get_tree().change_scene_to_file(path)
    if err != OK:
        push_error("Failed to load scene: " + path)
    tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 0.0, 0.4)
