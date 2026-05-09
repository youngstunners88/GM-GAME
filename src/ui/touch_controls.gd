extends CanvasLayer

@onready var left_btn: Button = $Control/LeftBtn
@onready var right_btn: Button = $Control/RightBtn
@onready var jump_btn: Button = $Control/JumpBtn
@onready var control_root: Control = $Control

# Analog drag tracking
var _left_touch_index: int = -1
var _right_touch_index: int = -1
var _left_origin: Vector2 = Vector2.ZERO
var _right_origin: Vector2 = Vector2.ZERO
const ANALOG_MAX_DIST: float = 60.0

func _ready() -> void:
    if not (OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")):
        visible = false

    # Digital fallback — kept for non-touch
    left_btn.button_down.connect(func(): Input.action_press("move_left"))
    left_btn.button_up.connect(func(): Input.action_release("move_left"))
    right_btn.button_down.connect(func(): Input.action_press("move_right"))
    right_btn.button_up.connect(func(): Input.action_release("move_right"))
    jump_btn.button_down.connect(func(): Input.action_press("jump"))
    jump_btn.button_up.connect(func(): Input.action_release("jump"))

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
    var left_rect := left_btn.get_global_rect()
    var right_rect := right_btn.get_global_rect()

    if event.pressed:
        if left_rect.has_point(event.position):
            _left_touch_index = event.index
            _left_origin = event.position
        elif right_rect.has_point(event.position):
            _right_touch_index = event.index
            _right_origin = event.position
    else:
        if event.index == _left_touch_index:
            _left_touch_index = -1
            Input.action_release("move_left")
        elif event.index == _right_touch_index:
            _right_touch_index = -1
            Input.action_release("move_right")

func _handle_drag(event: InputEventScreenDrag) -> void:
    if event.index == _left_touch_index:
        var delta_x := event.position.x - _left_origin.x
        var strength := clampf(absf(delta_x) / ANALOG_MAX_DIST, 0.0, 1.0)
        if delta_x < -10.0:
            Input.action_press("move_left", strength)
            Input.action_release("move_right")
        elif delta_x > 10.0:
            Input.action_press("move_right", strength)
            Input.action_release("move_left")
    elif event.index == _right_touch_index:
        var delta_x := event.position.x - _right_origin.x
        var strength := clampf(absf(delta_x) / ANALOG_MAX_DIST, 0.0, 1.0)
        if delta_x < -10.0:
            Input.action_press("move_left", strength)
        elif delta_x > 10.0:
            Input.action_press("move_right", strength)
