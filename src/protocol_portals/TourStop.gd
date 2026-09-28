extends Node2D
## One ground-anchored prop, a nearby caption and a matching approach zone.
signal reached(stop_id: String)
signal activated(stop_id: String)
const INTERACT_RADIUS := 100.0
const APPROACH := Vector2(0, 28)
var stop_id := ""
var stop_name := ""
var line := ""
var glow := Color("d9c594")
var visited := false
var label_height := 142.0
var _inside := false
var _label: Label
var _player: Node2D

func _init() -> void:
	add_to_group("portal_stop")

func setup(id: String, display_name: String, stop_line: String, color: Color,
		_pedestal: bool = false, label_y: float = 142.0) -> void:
	stop_id = id
	stop_name = display_name
	line = stop_line
	glow = color
	label_height = label_y

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_label = Label.new()
	_label.name = "StopLabel"
	_label.position = Vector2(-125, -label_height)
	_label.size = Vector2(250, 45)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color("eee1c3"))
	_label.add_theme_color_override("font_outline_color", Color("171919"))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.z_index = 2000
	add_child(_label)
	var zone := Area2D.new()
	zone.name = "ArriveZone"
	zone.position = APPROACH
	zone.collision_layer = 0
	zone.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 76.0
	shape.shape = circle
	zone.add_child(shape)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var distance := 9999.0
	if is_instance_valid(_player):
		distance = _player.global_position.distance_to(global_position + APPROACH)
	_inside = distance <= INTERACT_RADIUS
	_label.visible = distance < 245.0
	_label.modulate.a = clampf((245.0 - distance) / 90.0, 0.0, 1.0)
	var action := "Inspect"
	match stop_id:
		"paper": action = "Read"
		"video": action = "Watch"
		"exam": action = "Take exam"
		"exit": action = "Return to adventure"
	_label.text = stop_name + ("  ·  ✓" if visited and stop_id not in ["paper", "video", "exam", "exit"] else "")
	if _inside:
		_label.text += "\n[E] " + action
	queue_redraw()

func _draw() -> void:
	# Small proximity cue at the approach point; no permanent neon pedestal.
	if _inside:
		draw_arc(APPROACH, 19, 0, TAU, 32, Color(0.94, 0.83, 0.58, 0.65), 1.5, true)

func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	visited = true
	reached.emit(stop_id)

func _on_body_exited(_body: Node2D) -> void:
	pass

func activate() -> void:
	activated.emit(stop_id)
