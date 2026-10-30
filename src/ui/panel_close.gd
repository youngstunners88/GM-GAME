extends RefCounted
## Dismiss a panel directly, keeping browser fullscreen and the panel's pause owner.
## Raw finger handling supports a second thumb; emulated clicks are deduplicated.
static func install(parent: Node, dismiss: Callable) -> Button:
	var button := Button.new()
	button.name = "PanelClose"
	button.text = "×"
	button.tooltip_text = "Close"
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(12, 12)
	button.size = Vector2(48, 48)
	button.add_theme_font_size_override("font_size", 28)
	var activated := [-1]
	var fingers := {}
	var activate: Callable = func() -> void:
		var frame: int = Engine.get_process_frames()
		if activated[0] == frame: return
		activated[0] = frame
		dismiss.call()
	button.pressed.connect(activate)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if not event is InputEventScreenTouch: return
		if event.pressed:
			fingers[event.index] = true
		elif fingers.erase(event.index) and not event.canceled and Rect2(Vector2.ZERO, button.size).has_point(event.position):
			activate.call()
		button.accept_event())
	parent.add_child(button)
	return button
