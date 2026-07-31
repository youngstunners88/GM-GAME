extends CanvasLayer
## "How you roll" — the control-instruction surface (keyboard AND touch).
##
## NOTE: intentionally NO `class_name`. main_menu / pause_menu reach the static
## already_shown()/mark_shown() via load-by-path (same pattern as
## email_signup_panel), which is independent of Godot's global class cache —
## that cache is stale in the headless compile/export gates and a class_name
## reference from another script fails to resolve there.
##
## Shown once automatically on the first ever run (from the main menu, before
## play — no gameplay pause needed), and always re-openable from the menu's
## HOW TO PLAY button and the pause menu. Dismiss with GOT IT or by tapping
## the dimmed backdrop.
##
## Copy + layout: Grok 4.5 onboarding brief 2026-08-01
## (docs/model-responses/2026-08-01-grok-titles-onboarding.md), with the key
## labels corrected to the project's ACTUAL InputMap bindings (Grok's draft
## used placeholder keys; these are read from project.godot):
##   move A/D ←/→ · jump Space/W · attack J · dash K · sprint Shift ·
##   climb W/S ↑/↓ · interact E.
## One row per action, keyboard and touch as two short columns so the panel
## never doubles into a wall of text.

signal closed

const SHOWN_FLAG := "user://how_to_play_shown.txt"

## action name, keyboard hint, touch hint.
## ASCII ONLY in the hints — the pixel font renders arrow glyphs as tofu.
const ROWS: Array = [
	["Move", "A / D  or  Arrows", "tap  <  >"],
	["Jump", "Space / W", "tap JUMP  (again midair = double)"],
	["Attack", "J", "tap ATK  (hold w/ Purple = fire breath)"],
	["Dash", "K", "tap  DASH"],
	["Run", "Shift  (hold)", "hold  RUN"],
	["Climb", "W / S  or  Up / Down", "tap UP / DOWN  (on ladders)"],
	["Grab", "E", "tap  GRAB  (forges, doors, Oracle)"],
]

static func already_shown() -> bool:
	return FileAccess.file_exists(SHOWN_FLAG)

## Records the first-run flag. Call when auto-showing so it never auto-nags
## again; re-opens from a button do NOT need to call this.
static func mark_shown() -> void:
	var f := FileAccess.open(SHOWN_FLAG, FileAccess.WRITE)
	if f:
		f.store_string("1")

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	# Dimmed, tappable backdrop.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_backdrop_input)
	add_child(dim)

	# Full-rect margin frame so the card never exceeds the viewport — on a
	# short landscape phone (e.g. 844x390) a fixed-height centre card ran off
	# the bottom and hid the GOT IT button. A ScrollContainer inside guarantees
	# every row is reachable at any size.
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_top", 18)
	frame.add_theme_constant_override("margin_bottom", 18)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var panel := PanelContainer.new()
	# Centred fixed-width column; FILL vertically so it's bounded to the frame
	# height and the ScrollContainer inside actually scrolls instead of the
	# card growing past the screen.
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.14, 0.10, 0.98)
	sb.border_color = Color(0.45, 0.9, 0.55, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	frame.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "HOW YOU ROLL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 5)
	vbox.add_child(title)

	# Column header row.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	_add_cell(grid, "", 20, Color(0.7, 0.85, 0.75), true)
	_add_cell(grid, "KEYBOARD", 20, Color(0.6, 0.85, 1.0), true)
	_add_cell(grid, "TOUCH", 20, Color(0.6, 1.0, 0.7), true)

	for row in ROWS:
		_add_cell(grid, row[0], 24, Color(1, 0.95, 0.55), true)   # action
		_add_cell(grid, row[1], 22, Color(0.9, 0.95, 1.0), false) # keyboard
		_add_cell(grid, row[2], 22, Color(0.85, 1.0, 0.9), false) # touch

	var footer := Label.new()
	footer.text = "You're good. Go easy."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 22)
	footer.add_theme_color_override("font_color", Color(0.8, 0.95, 0.85))
	vbox.add_child(footer)

	var got := Button.new()
	got.text = "GOT IT"
	got.custom_minimum_size = Vector2(220, 56)
	got.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	got.add_theme_font_size_override("font_size", 30)
	got.pressed.connect(_dismiss)
	vbox.add_child(got)

func _add_cell(grid: GridContainer, text: String, size: int, color: Color, strong: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if strong:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("outline_size", 3)
	grid.add_child(l)

func _on_backdrop_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or \
			(event is InputEventScreenTouch and event.pressed):
		_dismiss()

## Escape / cancel also closes (keyboard parity).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()

func _dismiss() -> void:
	closed.emit()
	queue_free()
