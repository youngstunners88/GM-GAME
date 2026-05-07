extends CanvasLayer

@onready var left_btn: Button = $Control/LeftBtn
@onready var right_btn: Button = $Control/RightBtn
@onready var jump_btn: Button = $Control/JumpBtn
@onready var control_root: Control = $Control

func _ready() -> void:
    # Show on mobile or if explicitly enabled
    if not (OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")):
        # Hidden by default on PC, but user can uncomment below to test
        visible = false

    left_btn.button_down.connect(func(): Input.action_press("move_left"))
    left_btn.button_up.connect(func(): Input.action_release("move_left"))

    right_btn.button_down.connect(func(): Input.action_press("move_right"))
    right_btn.button_up.connect(func(): Input.action_release("move_right"))

    jump_btn.button_down.connect(func(): Input.action_press("jump"))
    jump_btn.button_up.connect(func(): Input.action_release("jump"))
