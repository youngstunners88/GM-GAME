extends Area2D

func _ready() -> void:
    add_to_group("collectible")
    body_entered.connect(_on_body_entered)
    # Spin animation
    var tween := create_tween().set_loops()
    tween.tween_property($Sprite, "scale:x", 0.1, 0.3)
    tween.tween_property($Sprite, "scale:x", 1.0, 0.3)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        collect()

func collect() -> void:
    GameManager.add_coin()
    ComboSystem.add_score(10)
    AudioManager.play_sfx("coin")
    set_deferred("monitoring", false)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(self, "position:y", position.y - 20, 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
    tween.finished.connect(queue_free)
