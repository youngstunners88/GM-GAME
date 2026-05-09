class_name BossBase
extends EnemyBase

@export var max_health: int = 5
@export var phase_thresholds: Array[int] = []

var current_phase: int = 1
var health_bar: ProgressBar

func _ready() -> void:
	add_to_group("boss")
	health = max_health
	_setup_health_bar()
	super()

func _setup_health_bar() -> void:
	health_bar = ProgressBar.new()
	health_bar.size = Vector2(200, 20)
	health_bar.position = Vector2(-100, -50)
	health_bar.max_value = max_health
	health_bar.value = max_health
	health_bar.modulate = Color(1.0, 0.2, 0.2, 1.0)
	add_child(health_bar)

func take_damage(amount: int) -> void:
	super(amount)
	_update_health_bar()
	_check_phase_change()

func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = health

func _check_phase_change() -> void:
	if phase_thresholds.is_empty():
		return
	var new_phase = 1
	for threshold in phase_thresholds:
		if health <= threshold:
			new_phase += 1
	if new_phase != current_phase:
		current_phase = new_phase
		_on_phase_changed()

func _on_phase_changed() -> void:
	pass  # Override in subclasses for phase-specific behavior

func die() -> void:
	if health_bar:
		health_bar.queue_free()
	super()

func lock_camera_to_arena(start_x: float, end_x: float) -> void:
	# Camera lock to arena bounds - override if custom camera needed
	pass
