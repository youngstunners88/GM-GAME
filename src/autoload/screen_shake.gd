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

## Tiered presets — one vocabulary for the whole game so shakes stay consistent:
## light = pickups, medium = enemy hits, heavy = boss attacks / player damage.
func light() -> void:
    shake(0.1, 2.0)

func medium() -> void:
    shake(0.2, 5.0)

func heavy() -> void:
    shake(0.4, 10.0)

## Tween the registered camera's zoom — boss encounters pull to 0.85 on entry
## and back to 1.0 on victory.
func zoom_to(target: float, duration: float = 0.5) -> void:
    if not is_instance_valid(_camera):
        return
    var tween := _camera.create_tween()
    tween.tween_property(_camera, "zoom", Vector2(target, target), duration)
