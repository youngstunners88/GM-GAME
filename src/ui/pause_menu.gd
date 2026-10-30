extends CanvasLayer
## In-run pause menu (Stages 1-3 and the Smoke Lounge).
##
## P / Escape / gamepad B (`ui_cancel`) or the touch pause button / gamepad Start
## (`pause`) toggles PLAYING <-> PAUSED on the StateMachine, which owns
## `get_tree().paused`. This node listens, shows itself, and wires its own four
## buttons, so whichever scene instances it gets a working menu (the Smoke Lounge
## used to forget Talk and shipped a dead button).
##
## Rules that keep it from fighting the other overlays in the game:
##  * It never opens while something else already holds the tree paused (the
##    oracle, lore and onboarding panels pause the tree but leave the
##    StateMachine in PLAYING). Resuming from here would otherwise unpause the
##    game underneath a panel that is still open.
##  * While the Talk panel is up the menu is hidden but the state is still
##    PAUSED. Escape belongs to the Talk panel then, so it must not resume the
##    game from under it.
##  * It sits ABOVE the touch layer (18) so a thumb on the dimmed joystick region
##    can never swallow a tap on Resume, and below the how-to-play card (80),
##    which owns Escape itself.
##  * Touch: Godot turns only the FIRST finger down into a mouse click. A thumb
##    still resting on the joystick owns that slot, so a second finger tapping
##    Resume would do nothing. The buttons therefore also act on the raw finger
##    events; the same-frame dedupe below stops the emulated click from firing twice.

## P / touch pause button / gamepad Start. Escape stays on the built-in `ui_cancel`.
const PAUSE_ACTION := &"pause"

## Wall-clock moment this pause began (msec), or -1 when not paused.
var _paused_at_ms: int = -1
var _run_controls: RunControls
## finger index -> the menu Button that finger went down on.
var _finger_on: Dictionary = {}
## Engine frame of the last button activation (see _activate).
var _last_activation_frame: int = -1

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()
    if not TouchUi.keys_shown(): get_node("VBox/SaveBtn").hide()
    var controls := RunControls.new()
    _run_controls = controls
    controls.save_action = GameManager.save_manual_checkpoint
    controls.available = func() -> bool: return (StateMachine.is_playing() and not get_tree().paused) or (StateMachine.is_paused() and visible)
    controls.checkpoint_name = GameManager.checkpoint_label
    get_parent().add_child.call_deferred(controls)
    _wire_button("VBox/SaveBtn", _on_save_pressed)
    StateMachine.state_changed.connect(_on_state_changed)
    _wire_button("VBox/ResumeBtn", _on_resume_pressed)
    _wire_button("VBox/RestartBtn", _on_restart_pressed)
    _wire_button("VBox/TalkBtn", _on_talk_pressed)
    _wire_button("VBox/QuitBtn", _on_quit_pressed)
    preload("res://src/ui/panel_close.gd").install(self, _on_resume_pressed)

func _wire_button(path: NodePath, handler: Callable) -> void:
    var button := get_node_or_null(path) as Button
    if button == null:
        return
    button.pressed.connect(_activate.bind(handler))
    button.gui_input.connect(_on_button_gui_input.bind(button, handler))

## One activation per engine frame. A first-finger tap reaches a button twice in
## the same frame (the raw finger event and the mouse click Godot emulates from it);
## a second finger only the raw one. Whichever comes first wins.
func _activate(handler: Callable) -> void:
    var frame := Engine.get_process_frames()
    if frame == _last_activation_frame:
        return
    _last_activation_frame = frame
    handler.call()

func _on_button_gui_input(event: InputEvent, button: Button, handler: Callable) -> void:
    if not (event is InputEventScreenTouch) or button.disabled:
        return
    var touch := event as InputEventScreenTouch
    if touch.pressed:
        _finger_on[touch.index] = button
        return
    # A tap = down and up on the same button, finger not cancelled, still inside it.
    var down_on: Variant = _finger_on.get(touch.index)
    _finger_on.erase(touch.index)
    if down_on == button and not touch.canceled \
            and Rect2(Vector2.ZERO, button.size).has_point(touch.position):
        _activate(handler)

func _on_state_changed(from: String, to: String) -> void:
    visible = (to == "PAUSED")
    if to == "PAUSED":
        get_node("VBox/SaveBtn").visible = TouchUi.keys_shown()
        get_node("VBox/CheckpointLabel").visible = TouchUi.keys_shown()
        get_node("VBox/CheckpointLabel").text = "Save point: " + GameManager.checkpoint_label()
        _paused_at_ms = Time.get_ticks_msec()
        _finger_on.clear()
        # Keyboard / gamepad parity: arrows + Enter / A work straight away.
        _focus_resume()
    elif from == "PAUSED":
        # (Hiding the layer already drops keyboard focus: a hidden Resume button
        # must not stay focused or Space - jump AND ui_accept - would press it.)
        _credit_paused_time()

func _unhandled_input(event: InputEvent) -> void:
    # `is_action_pressed` is the InputEvent API; `is_action_just_pressed` exists
    # only on the Input singleton and threw on every event that reached here.
    # Key-repeat (echo) must not flap the menu while Escape is held.
    var wants_toggle: bool = (event.is_action_pressed(&"ui_cancel") \
            or (InputMap.has_action(PAUSE_ACTION) and event.is_action_pressed(PAUSE_ACTION))) \
            and not event.is_echo()
    if wants_toggle and toggle():
        get_viewport().set_input_as_handled()

## Pause if playing, resume if this menu is the one on screen. Returns true when
## the state changed (so the caller can swallow the key).
func toggle() -> bool:
    if StateMachine.is_playing():
        # Another panel already froze the tree: it owns the pause and its own
        # Escape, so do not stack a second pause on top of it.
        if get_tree().paused:
            return false
        return StateMachine.change_state(StateMachine.State.PAUSED)
    if StateMachine.is_paused() and visible:
        return StateMachine.change_state(StateMachine.State.PLAYING)
    return false

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
            show()
            _focus_resume())

func _on_quit_pressed() -> void:
    if StateMachine.is_paused():
        StateMachine.change_state(StateMachine.State.PLAYING)
    GameManager.save_session()
    GameManager.reset_session()
    SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.FADE)

func _focus_resume() -> void:
    var resume := get_node_or_null("VBox/ResumeBtn") as Button
    if resume != null:
        resume.grab_focus()

## The level's completion time is a pacing signal for adaptive difficulty
## (Web3Bridge "level_complete"). Time spent in the menu is not play time, so
## push the level's start forward by however long the pause lasted.
func _credit_paused_time() -> void:
    if _paused_at_ms < 0:
        return
    var spent: int = Time.get_ticks_msec() - _paused_at_ms
    _paused_at_ms = -1
    var level := get_parent()
    if level != null and "level_start_ms" in level:
        level.level_start_ms += spent

func _on_save_pressed() -> void:
    var ok: bool = GameManager.save_manual_checkpoint()
    var button := get_node("VBox/SaveBtn") as Button
    if ok and GameManager.manual_save_status() == 0:
        button.disabled = true
        button.text = "Saving…"
        var started: int = Time.get_ticks_msec()
        while GameManager.manual_save_status() == 0 and Time.get_ticks_msec() - started < 15000:
            await get_tree().process_frame
        ok = GameManager.manual_save_status() == 1
        button.disabled = false
    ok = ok and GameManager.manual_save_status() == 1
    button.text = ("Saved checkpoint" if ok else "Save not confirmed — retry") if TouchUi.keys_shown() else ("✓" if ok else "×")

func _exit_tree() -> void:
    if is_instance_valid(_run_controls): _run_controls.queue_free()

func _process(_delta: float) -> void:
    if visible:
        get_node("VBox/SaveBtn").disabled = GameManager.manual_save_status() == 0
