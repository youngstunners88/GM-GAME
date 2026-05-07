extends Area2D

func _ready() -> void:
    add_to_group("collectible")
    body_entered.connect(_on_body_entered)
    $ColorRect.color = Color(1.0, 0.7, 0.0, 1.0)
    $ColorRect.size = Vector2(24, 24)
    $CollisionShape2D.position = Vector2(12, 12)
    # Pulse animation
    var tween := create_tween().set_loops()
    tween.tween_property($ColorRect, "scale", Vector2(1.2, 1.2), 0.5)
    tween.tween_property($ColorRect, "scale", Vector2(1.0, 1.0), 0.5)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        collect()

func collect() -> void:
    GameManager.add_ethereum_ring()
    AudioManager.play_sfx("ring")
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.15)
    tween.parallel().tween_property(self, "position:y", position.y - 30, 0.3)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
    await tween.finished
    queue_free()
