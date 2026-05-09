extends Area2D

@export var points: int = 100

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _setup_visual() -> void:
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.85, 0.0, 1.0)
	rect.size = Vector2(30, 15)
	rect.position = Vector2(-15, -7.5)
	add_child(rect)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15
	col.shape = shape
	add_child(col)

	# Bobbing animation
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 10, 0.8)
	tween.tween_property(self, "position:y", position.y, 0.8)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.add_score(points)
		queue_free()
