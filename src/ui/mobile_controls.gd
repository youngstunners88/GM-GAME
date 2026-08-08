extends CanvasLayer
## On-screen touch controls for the HTML5 / mobile build.
##
## DESIGN (Grok 4.5 mobile-scheme brief + Kimi K3 input audit, 2026-08-01 —
## docs/model-responses/2026-08-01-*.md):
##   Left thumb  = big digital LEFT / RIGHT zones (no fake analog stick), plus a
##                 compact UP / DOWN pair for ladders (touch had NO climb input
##                 before — a hard progression blocker on phones).
##   Right thumb = ATK as the big primary (it drives attacks AND the Boss-2 orb
##                 redirect), JUMP above it, DASH to its left, small SPRINT and
##                 a centre-bottom INTERACT.
##
## ARCHITECTURE: every control is a `TouchScreenButton` bound to an existing
## InputMap `action`. Pressing it calls `Input.action_press(action)`; releasing
## calls `Input.action_release(action)`. That means touch flows through the
## EXACT same code paths the keyboard already uses (movement, jump, double
## jump, climb up/down, dash, sprint, interact, attack tap + fire-breath hold) —
## so desktop parity is preserved by construction, and the three overlapping
## input systems that caused double-fire / dead-signal bugs (Kimi F2/F4/F5/F6)
## collapse into one. TouchScreenButton is also genuinely multitouch (each
## tracks its own finger), which plain Control Buttons under
## emulate_mouse_from_touch are NOT — you can hold LEFT + JUMP + ATK at once.
##
## `visibility_mode = TOUCHSCREEN_ONLY` makes the hit areas inert on
## non-touch desktop automatically; we also hide the cosmetic panels there.

class_name MobileControls

# Native mobile OR any touchscreen device. The Web export reports
# OS.get_name() as "Web" (never Android/iOS), so a mobile browser only reveals
# itself through is_touchscreen_available() — matches MobileInputHandler.
var is_touch: bool = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()

## Each control: id, InputMap action, label, rect (as viewport fractions
## x,y,w,h), tint, font size, and whether it's a primary (bigger label).
## Labels are ASCII ONLY: the pixel font has no arrow glyphs (◄►▲▼ render as
## tofu boxes — the same trap flagged in main_menu.gd). "<" ">" and the words
## UP/DOWN are basic-Latin and always present.
const CONTROLS: Array[Dictionary] = [
	{"id": "left",     "action": "move_left",  "label": "<",    "rect": [0.02, 0.62, 0.13, 0.31], "tint": Color(0.45, 0.85, 0.55), "font": 48, "primary": true},
	{"id": "right",    "action": "move_right", "label": ">",    "rect": [0.16, 0.62, 0.13, 0.31], "tint": Color(0.45, 0.85, 0.55), "font": 48, "primary": true},
	{"id": "up",       "action": "move_up",    "label": "UP",   "rect": [0.04, 0.34, 0.10, 0.15], "tint": Color(0.55, 0.8, 1.0),   "font": 24, "primary": false},
	{"id": "down",     "action": "move_down",  "label": "DOWN", "rect": [0.04, 0.50, 0.10, 0.12], "tint": Color(0.55, 0.8, 1.0),   "font": 22, "primary": false},
	{"id": "interact", "action": "interact",   "label": "GRAB", "rect": [0.44, 0.85, 0.12, 0.12], "tint": Color(0.85, 0.8, 0.35),  "font": 22, "primary": false},
	{"id": "sprint",   "action": "sprint",     "label": "RUN",  "rect": [0.58, 0.36, 0.11, 0.20], "tint": Color(1.0, 0.65, 0.35),  "font": 24, "primary": false},
	{"id": "dash",     "action": "dash",       "label": "DASH", "rect": [0.58, 0.60, 0.12, 0.22], "tint": Color(0.8, 0.45, 1.0),   "font": 26, "primary": false},
	{"id": "jump",     "action": "jump",       "label": "JUMP", "rect": [0.79, 0.30, 0.19, 0.26], "tint": Color(0.35, 0.8, 1.0),   "font": 32, "primary": true},
	{"id": "atk",      "action": "attack",     "label": "ATK",  "rect": [0.71, 0.58, 0.22, 0.32], "tint": Color(1.0, 0.4, 0.4),    "font": 40, "primary": true},
]

# Panels keyed by control id, so a size_changed rebuild can reposition without
# tearing the whole tree down.
var _panels: Dictionary = {}
var _buttons: Dictionary = {}

func _ready() -> void:
	# Sit above HUD; process even when the tree is paused so controls never
	# freeze mid-press.
	layer = 50
	if not is_touch:
		visible = false
		return
	_build()
	get_viewport().size_changed.connect(_relayout)

func _build() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	for def in CONTROLS:
		_add_control(def, vp)

func _add_control(def: Dictionary, vp: Vector2) -> void:
	var rect := _rect_for(def["rect"], vp)

	# Cosmetic panel (purely visual; never eats input).
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	var sb := StyleBoxFlat.new()
	var tint: Color = def["tint"]
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.28)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18 if def["primary"] else 12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = def["label"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", def["font"])
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	# Dark outline so the glyph reads over busy level art.
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	panel.add_child(label)
	_panels[def["id"]] = panel

	# Hit area: a real TouchScreenButton bound to the InputMap action.
	var btn := TouchScreenButton.new()
	btn.action = def["action"]
	btn.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	btn.shape_centered = false
	btn.position = rect.position
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	btn.shape = shape
	add_child(btn)
	# Press feedback: brighten the panel while held.
	btn.pressed.connect(_on_btn_pressed.bind(def["id"], tint))
	btn.released.connect(_on_btn_released.bind(def["id"], tint))
	_buttons[def["id"]] = btn

func _rect_for(frac: Array, vp: Vector2) -> Rect2:
	return Rect2(
		frac[0] * vp.x, frac[1] * vp.y,
		frac[2] * vp.x, frac[3] * vp.y
	)

## Reposition on viewport resize / orientation change (Kimi F8: everything used
## to be computed once in _ready and went stale on rotate).
func _relayout() -> void:
	if not is_touch:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	for def in CONTROLS:
		var id: String = def["id"]
		var rect := _rect_for(def["rect"], vp)
		if _panels.has(id) and is_instance_valid(_panels[id]):
			_panels[id].position = rect.position
			_panels[id].size = rect.size
		if _buttons.has(id) and is_instance_valid(_buttons[id]):
			_buttons[id].position = rect.position
			(_buttons[id].shape as RectangleShape2D).size = rect.size

func _on_btn_pressed(id: String, tint: Color) -> void:
	if _panels.has(id) and is_instance_valid(_panels[id]):
		var sb: StyleBoxFlat = _panels[id].get_theme_stylebox("panel")
		sb.bg_color = Color(tint.r, tint.g, tint.b, 0.6)

func _on_btn_released(id: String, tint: Color) -> void:
	if _panels.has(id) and is_instance_valid(_panels[id]):
		var sb: StyleBoxFlat = _panels[id].get_theme_stylebox("panel")
		sb.bg_color = Color(tint.r, tint.g, tint.b, 0.28)
