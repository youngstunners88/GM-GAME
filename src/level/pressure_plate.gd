class_name PressurePlate
extends TimedInteractable

@export var linked_doors: Array[NodePath] = []

var _progress_bar: ProgressBar

func _ready() -> void:
	super()
	_setup_visual()

## Restyled 2026-08-04 — one of the flat orange rectangles the founder
## red-circled in Level 3 as "trashy and cheap". Was a bare #cc6619 ColorRect.
## Now a dark plate with a gold pressure pad, matching the Gold Rush palette
## used by the level's real platforms.
func _setup_visual() -> void:
	var base := ColorRect.new()
	base.color = Color(0.18, 0.09, 0.04, 1.0)      # L3 platform_body_color
	base.size = Vector2(60, 20)
	base.position = Vector2(-30, 0)
	add_child(base)
	# Inset gold pad — the part that reads as "step here".
	var pad := ColorRect.new()
	pad.color = Color(0.95, 0.75, 0.2, 1.0)        # L3 platform_lip_color
	pad.size = Vector2(48, 6)
	pad.position = Vector2(-24, 2)
	add_child(pad)
	# Rivet heads at the corners for a machined read.
	for rx in [-27.0, 23.0]:
		var rivet := ColorRect.new()
		rivet.color = Color(0.62, 0.47, 0.14, 1.0)
		rivet.size = Vector2(4, 4)
		rivet.position = Vector2(rx, 13)
		add_child(rivet)

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
