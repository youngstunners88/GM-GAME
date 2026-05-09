extends Node

var _camera: Camera2D = null
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0

func _process(delta: float) -> void:
    if _shake_duration <= 0.0 or not is_instance_valid(_camera):
        return
    _shake_duration -= delta
    if _shake_duration <= 0.0:
        _camera.offset = Vector2.ZERO
        return
    _camera.offset = Vector2(
        randf_range(-_shake_intensity, _shake_intensity),
        randf_range(-_shake_intensity, _shake_intensity)
    )

func register_camera(cam: Camera2D) -> void:
    _camera = cam

func shake(duration: float, intensity: float) -> void:
    _shake_duration = maxf(_shake_duration, duration)
    _shake_intensity = maxf(_shake_intensity, intensity)
