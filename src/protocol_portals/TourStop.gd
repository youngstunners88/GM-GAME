extends Node2D
## A named place on a tour strip: a glowing floor plate you walk onto, an
## optional sign post with the stop name, and an arrival Area2D. Emits
## reached(stop_id) each time the player walks in.

signal reached(stop_id: String)

const ZONE_SIZE: Vector2 = Vector2(180.0, 220.0)
const PLATE_RX: float = 80.0
const PLATE_RY: float = 11.0

var stop_id: String = ""
var stop_name: String = ""
var line: String = ""
var glow: Color = Color(0.35, 1.0, 0.45)
## True = sign post under the label (name kept for API compatibility).
var show_pedestal: bool = true
var label_height: float = 170.0
var visited: bool = false

var _plate_glow: Sprite2D = null
var _plate_lit: Polygon2D = null
var _label: Label = null
var _inside: bool = false
var _t: float = 0.0


func _init() -> void:
	add_to_group("portal_stop")


## Call before add_child so _ready builds with the right values.
func setup(id: String, display_name: String, stop_line: String, color: Color,
		pedestal: bool = true, label_y: float = 170.0) -> void:
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
	_build_plate()
	if show_pedestal:
		_build_post()
	_build_label()
	_build_zone()


func _process(delta: float) -> void:
	_t += delta
	var k: float = 0.5 + 0.5 * sin(_t * TAU * 0.8)
	var base: float = 0.4
	if _inside:
		base = 0.85
	elif visited:
		base = 0.6
	var a: float = clampf(base + 0.2 * k, 0.0, 1.0)
	if _plate_glow != null:
		_plate_glow.modulate = Color(glow.r, glow.g, glow.b, a)
	if _plate_lit != null:
		_plate_lit.color = Color(glow.r, glow.g, glow.b, a * 0.7)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(28):
		var ang: float = TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


func _build_plate() -> void:
	var rim := Polygon2D.new()
	rim.name = "PlateRim"
	rim.polygon = _ellipse(Vector2(0.0, -1.0), PLATE_RX + 6.0, PLATE_RY + 3.0)
	rim.color = Color(0.03, 0.03, 0.05, 0.95)
	add_child(rim)

	_plate_lit = Polygon2D.new()
	_plate_lit.name = "PlateLit"
	_plate_lit.polygon = _ellipse(Vector2(0.0, -1.0), PLATE_RX, PLATE_RY)
	_plate_lit.color = Color(glow.r, glow.g, glow.b, 0.4)
	add_child(_plate_lit)

	var ring := Line2D.new()
	ring.name = "PlateRing"
	ring.points = _ellipse(Vector2(0.0, -1.0), PLATE_RX * 0.6, PLATE_RY * 0.6)
	ring.closed = true
	ring.width = 2.0
	ring.default_color = Color(1.0, 1.0, 1.0, 0.5)
	add_child(ring)

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
	_plate_glow = Sprite2D.new()
	_plate_glow.name = "PlateGlow"
	_plate_glow.texture = tex
	_plate_glow.material = mat
	_plate_glow.scale = Vector2(3.4, 1.1)
	_plate_glow.position = Vector2(0.0, -10.0)
	_plate_glow.modulate = glow
	add_child(_plate_glow)


func _build_post() -> void:
	var top: float = -label_height + 38.0
	var post := ColorRect.new()
	post.name = "SignPost"
	post.position = Vector2(PLATE_RX + 14.0, top)
	post.size = Vector2(6.0, -top)
	post.color = Color(0.08, 0.08, 0.1, 0.95)
	add_child(post)
	var edge := ColorRect.new()
	edge.name = "SignPostEdge"
	edge.position = Vector2(PLATE_RX + 14.0, top)
	edge.size = Vector2(2.0, -top)
	edge.color = Color(glow.r, glow.g, glow.b, 0.5)
	add_child(edge)


func _build_label() -> void:
	_label = Label.new()
	_label.name = "StopLabel"
	_label.text = stop_name
	_label.size = Vector2(300.0, 38.0)
	var lx: float = -150.0
	if show_pedestal:
		lx = PLATE_RX + 17.0 - 150.0
	_label.position = Vector2(lx, -label_height)
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
	sb.set_corner_radius_all(6)
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
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	visited = true
	_inside = true
	reached.emit(stop_id)


func _on_body_exited(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	_inside = false
