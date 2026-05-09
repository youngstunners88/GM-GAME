class_name TimedInteractable
extends Area2D

@export var timer_duration: float = 5.0
@export var one_shot: bool = true

signal timer_completed

var _timer_active: bool = false
var _time_remaining: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("timed_interactable")

func _physics_process(delta: float) -> void:
	if not _timer_active:
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_on_timer_completed()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _timer_active:
		start_timer()

func start_timer() -> void:
	_timer_active = true
	_time_remaining = timer_duration
	_on_timer_started()

func _on_timer_started() -> void:
	pass  # Override in subclasses to show progress UI

func _on_timer_completed() -> void:
	_timer_active = false
	timer_completed.emit()
	if one_shot:
		body_entered.disconnect(_on_body_entered)
