class_name PressurePlate
extends TimedInteractable

@export var linked_doors: Array[NodePath] = []

var _progress_bar: ProgressBar

func _ready() -> void:
	super()
	_setup_visual()

func _setup_visual() -> void:
	var col_rect := ColorRect.new()
	col_rect.color = Color(0.8, 0.4, 0.1, 0.8)
	col_rect.size = Vector2(60, 20)
	col_rect.position = Vector2(-30, 0)
	add_child(col_rect)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 20)
	col.shape = shape
	add_child(col)

	_progress_bar = ProgressBar.new()
	_progress_bar.size = Vector2(60, 10)
	_progress_bar.position = Vector2(-30, -15)
	_progress_bar.max_value = timer_duration
	_progress_bar.value = 0
	_progress_bar.hide()
	add_child(_progress_bar)

func _physics_process(delta: float) -> void:
	super(delta)
	if _timer_active:
		_progress_bar.value = timer_duration - _time_remaining

func _on_timer_started() -> void:
	_progress_bar.show()
	_progress_bar.value = 0

func _on_timer_completed() -> void:
	_progress_bar.hide()
	for door_path in linked_doors:
		var door = get_node_or_null(door_path)
		if door and door.has_method("open"):
			door.open()
	super()
