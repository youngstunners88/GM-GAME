extends Node2D
## A named place on a protocol tour strip: a pedestal prop, a dark rounded
## label and an arrival Area2D. Emits reached(stop_id) every time the player
## walks in. StudyRoom listens and has the companion speak the stop line.
## Pure scenery plus one trigger: no session state, no input handling.

signal reached(stop_id: String)

const ZONE_SIZE: Vector2 = Vector2(180.0, 220.0)
const PEDESTAL_H: float = 90.0

var stop_id: String = ""
var stop_name: String = ""
var line: String = ""
var glow: Color = Color(0.35, 1.0, 0.45)
var show_pedestal: bool = true
var label_height: float = 210.0
var visited: bool = false

var _orb: Sprite2D = null
var _label: Label = null
var _t: float = 0.0


func _init() -> void:
	add_to_group("portal_stop")


## Call before add_child so _ready builds with the right values.
func setup(id: String, display_name: String, stop_line: String, color: Color,
		pedestal: bool = true, label_y: float = 210.0) -> void:
	stop_id = id
	stop_name = display_name
	line = stop_line
	glow = color
	show_pedestal = pedestal
	label_height = label_y


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not is_in_group("portal_stop"):
		add_to_group("portal_stop")
	if show_pedestal:
		_build_pedestal()
	_build_label()
	_build_zone()


func _process(delta: float) -> void:
	if _orb == null:
		return
	_t += delta
	var k: float = 0.5 + 0.5 * sin(_t * TAU * 0.8)
	var base: float = 0.85 if visited else 0.5
	_orb.modulate = Color(glow.r, glow.g, glow.b, clampf(base + 0.25 * k, 0.0, 1.0))
	_orb.position.y = -PEDESTAL_H - 34.0 + 3.0 * sin(_t * TAU * 0.4)


func _build_pedestal() -> void:
	var shadow := ColorRect.new()
	shadow.name = "PedestalShadow"
	shadow.position = Vector2(-70.0, -4.0)
	shadow.size = Vector2(140.0, 6.0)
	shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	add_child(shadow)

	var pts := PackedVector2Array([
		Vector2(-60.0, 0.0),
		Vector2(60.0, 0.0),
		Vector2(42.0, -PEDESTAL_H),
		Vector2(-42.0, -PEDESTAL_H),
	])
	var body := Polygon2D.new()
	body.name = "Pedestal"
	body.polygon = pts
	body.color = Color(0.04, 0.05, 0.08, 0.96)
	add_child(body)

	var outline := Line2D.new()
	outline.name = "PedestalOutline"
	outline.points = pts
	outline.closed = true
	outline.width = 3.0
	outline.default_color = Color(glow.r, glow.g, glow.b, 0.85)
	add_child(outline)

	var cap := ColorRect.new()
	cap.name = "PedestalCap"
	cap.position = Vector2(-50.0, -PEDESTAL_H - 8.0)
	cap.size = Vector2(100.0, 8.0)
	cap.color = Color(glow.r, glow.g, glow.b, 0.7)
	add_child(cap)

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_orb = Sprite2D.new()
	_orb.name = "StopOrb"
	_orb.texture = tex
	_orb.material = mat
	_orb.position = Vector2(0.0, -PEDESTAL_H - 34.0)
	_orb.modulate = glow
	add_child(_orb)


func _build_label() -> void:
	_label = Label.new()
	_label.name = "StopLabel"
	_label.text = stop_name
	_label.size = Vector2(300.0, 38.0)
	_label.position = Vector2(-150.0, -label_height)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", glow)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_label.add_theme_constant_override("outline_size", 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.82)
	sb.border_color = Color(glow.r, glow.g, glow.b, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6.0)
	_label.add_theme_stylebox_override("normal", sb)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _build_zone() -> void:
	var zone := Area2D.new()
	zone.name = "ArriveZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = Vector2(0.0, -ZONE_SIZE.y * 0.5)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = ZONE_SIZE
	shape.shape = rect
	zone.add_child(shape)
	zone.body_entered.connect(_on_body_entered)
	add_child(zone)


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	visited = true
	reached.emit(stop_id)
