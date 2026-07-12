extends CanvasLayer

@onready var fade_rect: ColorRect = $ColorRect

# Shader-driven wipe overlay (smoke dissolve / diamond shatter patterns).
var _wipe_rect: ColorRect
var _wipe_mat: ShaderMaterial

func _ready() -> void:
    fade_rect.color = Color(0, 0, 0, 0)
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _wipe_mat = ShaderMaterial.new()
    _wipe_mat.shader = load("res://src/effects/transition_wipe.gdshader")
    _wipe_mat.set_shader_parameter("progress", 0.0)
    _wipe_rect = ColorRect.new()
    _wipe_rect.material = _wipe_mat
    _wipe_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_wipe_rect)

## Cover the screen with a patterned dissolve ("smoke" or "diamond").
func wipe_out(pattern: String = "smoke", duration: float = 0.45) -> void:
    _wipe_mat.set_shader_parameter("pattern", 1 if pattern == "diamond" else 0)
    var tween := create_tween()
    tween.tween_method(_set_wipe, _get_wipe(), 1.0, duration)
    await tween.finished

## Reveal the new scene by reversing the dissolve.
func wipe_in(duration: float = 0.45) -> void:
    var tween := create_tween()
    tween.tween_method(_set_wipe, _get_wipe(), 0.0, duration)
    await tween.finished

func _set_wipe(v: float) -> void:
    _wipe_mat.set_shader_parameter("progress", v)

func _get_wipe() -> float:
    return _wipe_mat.get_shader_parameter("progress")

func transition_to_scene(path: String) -> void:
    var tween := create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
    await tween.finished
    var err := get_tree().change_scene_to_file(path)
    if err != OK:
        push_error("Failed to load scene: " + path)
    tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 0.0, 0.4)

func fade_out(duration: float = 0.3) -> void:
    var tween := create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, duration)
    await tween.finished

func fade_in(duration: float = 0.3) -> void:
    var tween := create_tween()
    tween.tween_property(fade_rect, "color:a", 0.0, duration)
    await tween.finished
