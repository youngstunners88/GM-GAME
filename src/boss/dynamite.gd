extends Area2D

@export var explosion_delay: float = 2.0
@export var explosion_radius: float = 100.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(explosion_delay).timeout
	_explode()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_explode()

var _exploded: bool = false

func _explode() -> void:
	if _exploded or not is_inside_tree():
		return
	_exploded = true
	var explosion := Area2D.new()
	explosion.position = global_position
	get_parent().add_child(explosion)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	col.shape = shape
	explosion.add_child(col)

	var overlapping := explosion.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(1)

	AudioManager.play_sfx("explosion")
	ScreenShake.shake(0.3, 6.0)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()
	explosion.queue_free()
