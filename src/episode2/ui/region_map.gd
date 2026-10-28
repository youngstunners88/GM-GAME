extends CanvasLayer
## Looted chart survives room handoffs; this overlay owns only its own pause.
const ART = preload("res://src/episode2/ui/region_map.png")
var context: Callable
var allowed: Callable
var expanded := false
var corner: TextureButton
var key_hint: Label
var panel: Control
var paper: TextureRect
var marker: Label
var destination: Label
var _mouse_before: int

func _ready() -> void:
 layer = 76
 process_mode = Node.PROCESS_MODE_ALWAYS
 corner = TextureButton.new()
 corner.texture_normal = ART
 corner.ignore_texture_size = true
 corner.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
 corner.focus_mode = Control.FOCUS_NONE
 corner.pressed.connect(toggle)
 add_child(corner)
 corner.hide()
 key_hint = Label.new()
 key_hint.text = 'Press “M”'
 key_hint.add_theme_font_size_override("font_size", 14)
 key_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(key_hint)
 panel = Control.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(panel)
 var shade := ColorRect.new()
 shade.color = Color(0.06,0.035,0.02,0.9)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.add_child(shade)
 paper = TextureRect.new()
 paper.texture = ART
 paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 paper.stretch_mode = TextureRect.STRETCH_SCALE
 paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.add_child(paper)
 marker = Label.new()
 marker.text = "◆"
 marker.add_theme_color_override("font_color",Color(0.16,0.26,0.22))
 marker.add_theme_font_size_override("font_size",28)
 marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
 paper.add_child(marker)
 destination = Label.new()
 destination.text = "✕  LOGAN’S LAKE"
 destination.add_theme_color_override("font_color",Color(0.5,0.12,0.07))
 destination.add_theme_font_size_override("font_size",24)
 destination.mouse_filter = Control.MOUSE_FILTER_IGNORE
 paper.add_child(destination)
 var close := Button.new()
 close.text = "×"
 close.focus_mode = Control.FOCUS_NONE
 close.position = Vector2(6,6)
 close.size = Vector2(48,48)
 close.pressed.connect(toggle)
 panel.add_child(close)
 panel.hide()

func _process(_dt: float) -> void:
 corner.visible = GameManager.has_region_map and not expanded
 var safe: Rect2 = TouchUi.metrics().safe_rect if TouchUi.is_touch() else get_viewport().get_visible_rect()
 var dp: float = TouchUi.metrics().dp if TouchUi.is_touch() else 1.0
 corner.position = safe.position + Vector2(10,40)*dp
 corner.size = Vector2(116,73)*dp
 key_hint.visible = corner.visible and TouchUi.keys_shown()
 key_hint.position = corner.position + Vector2(120,26)*dp
 corner.tooltip_text = "" if TouchUi.is_touch() else "Region map (M) • " + GameManager.map_active_destination.replace("_"," ")
 panel.size = get_viewport().get_visible_rect().size
 panel.visible = expanded
 if not expanded: return
 var extent := Vector2(minf(safe.size.x-32,safe.size.y*1.6-40),0)
 extent.y = extent.x/1.6
 paper.size = extent
 paper.position = safe.get_center()-extent*.5
 var uv := Vector2(.23,.68)
 if context.is_valid(): uv = context.call()
 marker.position = uv*extent-Vector2(12,18)
 destination.visible = GameManager.map_active_destination == "logans_lake"
 destination.position = Vector2(.64,.23)*extent

func _input(event: InputEvent) -> void:
 if event.is_echo(): return
 if expanded and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
  toggle();get_viewport().set_input_as_handled()
 elif event.is_action_pressed("toggle_map") and GameManager.has_region_map:
  toggle();get_viewport().set_input_as_handled()

func toggle() -> void:
 if expanded:
  expanded = false
  if StateMachine.is_paused(): StateMachine.change_state(StateMachine.State.PLAYING)
  Input.mouse_mode = _mouse_before
 elif GameManager.has_region_map and allowed.is_valid() and allowed.call():
  _mouse_before = Input.mouse_mode
  expanded = true
  StateMachine.change_state(StateMachine.State.PAUSED)
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
 if expanded and StateMachine.is_paused():
  StateMachine.change_state(StateMachine.State.PLAYING)
