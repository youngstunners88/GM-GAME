class_name BossHealthBar
extends CanvasLayer
## Screen-anchored boss health bar, shared by every boss.
##
## WHY SCREEN-ANCHORED, not parented to the boss: the previous implementation
## (BossBase._setup_health_bar) added a raw ProgressBar as a CHILD of the boss
## body at world position (-100,-50). That bar moved with the boss, so it
## jittered during patrol/charge, slid off-screen when the boss left frame,
## and scaled with the boss-arena camera zoom (ScreenShake.zoom_to(0.85)).
##
## WHY DISCRETE PIPS, not a continuous fill: bosses have 6-7 max HP. A smooth
## bar makes a single hit look like a rounding error; one pip winking out reads
## as unmistakable progress. The pip count IS the max HP, so the player can
## count exactly how many hits are left.
##
## Purely presentational — owns no game state, reads nothing on its own, and
## is driven entirely by set_boss()/set_health()/set_phase() from the boss.

const PIP_EMPTY := Color(0.16, 0.09, 0.28, 1.0)
## Phase colours escalate with the fight: lime -> amber -> hot pink.
const PHASE_COLORS := [
	Color(0.72, 1.0, 0.24, 1.0),   # phase 1
	Color(1.0, 0.69, 0.13, 1.0),   # phase 2
	Color(1.0, 0.24, 0.43, 1.0),   # phase 3+
]
const FRAME_BORDER := Color(0.77, 0.94, 0.26, 1.0)

var _root: Control
var _frame: Panel
var _name_label: Label
var _pip_row: HBoxContainer
var _pips: Array[ColorRect] = []
var _thresholds: Array[int] = []
var _max_hp: int = 1
var _phase: int = 1
## Tracked so rapid consecutive hits cancel the previous shake instead of
## stacking competing tweens on the same property.
var _shake_tween: Tween

func _ready() -> void:
	# Above the HUD (default layer 0) but below pause/victory overlays
	# (layer 10/12), so a boss bar never covers a menu.
	layer = 5
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 4)
	# Top-centre: the HUD owns the top-LEFT stack (score/coins/rings) and the
	# touch controls own the bottom, so the top-centre strip is genuinely free.
	column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	column.position = Vector2(-160, 14)
	column.custom_minimum_size = Vector2(320, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size = Vector2(320, 0)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color(0.91, 1.0, 0.63, 1.0))
	_name_label.add_theme_color_override("font_outline_color", Color(0.10, 0.04, 0.18, 1.0))
	_name_label.add_theme_constant_override("outline_size", 5)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_name_label)

	_frame = Panel.new()
	_frame.custom_minimum_size = Vector2(320, 28)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.10, 0.04, 0.18, 0.92)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = FRAME_BORDER
	frame_style.set_corner_radius_all(4)
	frame_style.content_margin_left = 5
	frame_style.content_margin_right = 5
	frame_style.content_margin_top = 4
	frame_style.content_margin_bottom = 4
	_frame.add_theme_stylebox_override("panel", frame_style)
	column.add_child(_frame)

	_pip_row = HBoxContainer.new()
	_pip_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pip_row.offset_left = 5
	_pip_row.offset_top = 4
	_pip_row.offset_right = -5
	_pip_row.offset_bottom = -4
	_pip_row.add_theme_constant_override("separation", 3)
	_pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_pip_row)

## Configure for a specific boss. `thresholds` are HP values at which the boss
## escalates — rendered as permanent divider ticks so the player can SEE the
## next enrage coming instead of being surprised by it.
func set_boss(display_name: String, max_hp: int, thresholds: Array = []) -> void:
	_name_label.text = display_name.to_upper()
	_max_hp = maxi(1, max_hp)
	_thresholds = []
	for t in thresholds:
		_thresholds.append(int(t))
	_rebuild_pips()

func _rebuild_pips() -> void:
	for child in _pip_row.get_children():
		child.queue_free()
	_pips.clear()
	# Pip i represents the i-th HP point, counting from the LEFT as the first
	# to be lost, so the bar drains left-to-right like a fuse burning down.
	for i in range(_max_hp):
		var pip := ColorRect.new()
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.custom_minimum_size = Vector2(0, 16)
		pip.color = PHASE_COLORS[0]
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pip_row.add_child(pip)
		_pips.append(pip)
		# A threshold tick sits immediately after the pip whose remaining-HP
		# count equals that threshold.
		var remaining_after := _max_hp - (i + 1)
		if remaining_after in _thresholds and remaining_after > 0:
			var tick := ColorRect.new()
			tick.custom_minimum_size = Vector2(2, 16)
			tick.color = Color(0.88, 0.63, 1.0, 1.0)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pip_row.add_child(tick)

## Repaint for the current HP. Pips beyond `current` go dark.
##
## Remaining health is anchored LEFT and drains right-to-left, matching the
## near-universal health-bar convention. (An earlier version drained the other
## way, leaving the surviving pips huddled on the right — technically
## consistent but it reads as broken.)
func set_health(current: int) -> void:
	var lit := clampi(current, 0, _max_hp)
	var color := _phase_color()
	for i in range(_pips.size()):
		_pips[i].color = color if i < lit else PIP_EMPTY

## Damage punch: white-flash the pip that just died, plus a short frame shake.
## Called after set_health(), so the flashed pip is already dark underneath.
## `lost_index` is the pip index that just went out — with left-anchored
## draining that is simply the new HP value (losing the 6th HP darkens pip 5).
func flash_damage(lost_index: int) -> void:
	if lost_index >= 0 and lost_index < _pips.size():
		var pip := _pips[lost_index]
		var t := create_tween()
		t.tween_property(pip, "color", Color.WHITE, 0.04)
		t.tween_property(pip, "color", PIP_EMPTY, 0.08)
	# Shake via pivot rotation on the whole root, NOT by tweening _frame's
	# position: _frame is a VBoxContainer child, so the container's layout sort
	# fights a position tween and can strand the frame a few px off-centre if
	# two hits land inside one shake (Kimi audit). A tiny rotation is not
	# layout-managed, so nothing can snap it back mid-tween.
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_frame.pivot_offset = _frame.size / 2.0
	_frame.rotation = 0.0
	_shake_tween = create_tween()
	_shake_tween.tween_property(_frame, "rotation", 0.02, 0.04)
	_shake_tween.tween_property(_frame, "rotation", -0.02, 0.04)
	_shake_tween.tween_property(_frame, "rotation", 0.0, 0.04)

func set_phase(phase: int) -> void:
	if phase == _phase:
		return
	_phase = phase
	var color := _phase_color()
	for pip in _pips:
		# Only recolour pips that are still lit; dark ones stay dark.
		if pip.color != PIP_EMPTY:
			var t := create_tween()
			t.tween_property(pip, "color", color, 0.2)
	var style: StyleBoxFlat = _frame.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flash := create_tween()
		flash.tween_property(style, "border_color", Color.WHITE, 0.08)
		flash.tween_property(style, "border_color", FRAME_BORDER, 0.12)

func _phase_color() -> Color:
	return PHASE_COLORS[clampi(_phase - 1, 0, PHASE_COLORS.size() - 1)]
