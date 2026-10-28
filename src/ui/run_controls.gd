class_name RunControls
extends CanvasLayer
## Manual checkpoint save shared by both episodes. Pause uses P / the existing touch control.
## Real Buttons support keyboard/mouse; raw finger taps also work with a thumb held.
var save_action: Callable
var available: Callable
var checkpoint_name: Callable
var save_button: Button
var key_hint: Label
var status: Label
var _last_frame: int = -1
var _fingers: Dictionary = {}
var _last_touch: bool = false
var _waiting: bool = false
var _point: String = ""
var _save_started: int = 0

class IconButton extends Button:
    var saved: bool = false
    var failed: bool = false
    func _draw() -> void:
        var c := Color(.95, .82, .46) if not disabled else Color(.5, .5, .5)
        if saved: c = Color(.4, .95, .55)
        if failed: c = Color(1, .3, .3)
        draw_set_transform(size * .5, 0.0, Vector2.ONE * (size.x / 56.0))
        var p := Vector2.ZERO
        draw_rect(Rect2(p - Vector2(12, 12), Vector2(24, 24)), c, false, 2)
        draw_rect(Rect2(p - Vector2(7, 11), Vector2(14, 8)), c, false, 2)
        draw_rect(Rect2(p + Vector2(-7, 3), Vector2(14, 8)), c, false, 2)
        if saved: draw_polyline(PackedVector2Array([p+Vector2(-7,0), p+Vector2(-2,5), p+Vector2(9,-6)]), c, 3)

func _ready() -> void:
    layer = 75
    process_mode = Node.PROCESS_MODE_ALWAYS
    save_button = _button("SaveButton", _save)
    key_hint = Label.new()
    key_hint.text = 'Press “G”'
    key_hint.add_theme_font_size_override("font_size", 14)
    key_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(key_hint)
    status = Label.new()
    status.name = "SaveStatus"
    status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status.add_theme_font_size_override("font_size", 15)
    add_child(status)
    get_viewport().size_changed.connect(_layout)
    _layout()

func _button(label: String, action: Callable) -> Button:
    var b := IconButton.new()
    b.name = label
    b.focus_mode = Control.FOCUS_NONE # Never let Space/jump activate a HUD button.
    b.custom_minimum_size = Vector2(56, 48)
    b.size = Vector2(56, 48)
    add_child(b)
    b.pressed.connect(_activate.bind(action))
    b.gui_input.connect(func(event: InputEvent) -> void:
        if event is InputEventScreenTouch:
            if event.pressed: _fingers[event.index] = b
            else:
                var same: bool = _fingers.get(event.index) == b
                _fingers.erase(event.index)
                if same and not event.canceled and Rect2(Vector2.ZERO,b.size).has_point(event.position) and not b.disabled:
                    _activate(action))
    return b

func _activate(action: Callable) -> void:
    var frame: int = Engine.get_process_frames()
    if _last_frame == frame: return
    _last_frame = frame
    action.call()

func _layout() -> void:
    if save_button == null: return
    var area: Rect2 = TouchUi.metrics().safe_rect if TouchUi.is_touch() else get_viewport().get_visible_rect()
    var scale_dp: float = TouchUi.metrics().dp if TouchUi.is_touch() else 1.0
    var edge: Vector2 = area.position + Vector2(area.size.x, 0)
    save_button.position = edge + (Vector2(-114,40) if TouchUi.is_touch() else Vector2(-82,108)) * scale_dp
    save_button.size = Vector2(56,48) * scale_dp
    key_hint.position = save_button.position + Vector2(-76,15) * scale_dp
    status.position = edge + Vector2(-430, 163) * scale_dp
    status.size = Vector2(405, 48) * scale_dp

func _process(_delta: float) -> void:
    var ok: bool = available.is_valid() and available.call()
    visible = ok
    save_button.disabled = not ok or _waiting or GameManager.manual_save_status() == 0
    if _waiting:
        var result: int = GameManager.manual_save_status()
        if result != 0 or Time.get_ticks_msec() - _save_started > 15000:
            _waiting = false
            _show_result(result == 1, true)
    var touch: bool = TouchUi.is_touch()
    if touch != _last_touch:
        _last_touch = touch
        _layout()
    save_button.tooltip_text = "" if touch else "Save checkpoint: " + str(checkpoint_name.call())
    status.visible = not touch
    key_hint.visible = not touch

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
        if visible and not save_button.disabled:
            _activate(_save)
            get_viewport().set_input_as_handled()

func _save() -> void:
    if not available.call(): return
    _point = str(checkpoint_name.call())
    var ok: bool = save_action.call()
    if ok and GameManager.manual_save_status() == 0:
        _waiting = true
        _save_started = Time.get_ticks_msec()
        (save_button as IconButton).saved = false
        (save_button as IconButton).failed = false
        status.text = "Saving checkpoint…"
    else:
        _show_result(ok and GameManager.manual_save_status() == 1, false)

func _show_result(ok: bool, browser_confirmation: bool) -> void:
    var b := save_button as IconButton
    b.saved = ok
    b.failed = not ok
    b.queue_redraw()
    if ok:
        status.text = "Saved: " + _point + ("\nContinue in this browser from the main menu." if OS.has_feature("web") else "\nContinue from the main menu.")
    else:
        status.text = "Save not confirmed. Try again." if browser_confirmation else "Save failed. Your previous save is unchanged."
