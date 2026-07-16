extends Area2D

func _ready() -> void:
    add_to_group("collectible")
    body_entered.connect(_on_body_entered)
    # Gentle pulse on the heart sprite.
    var tween := create_tween().set_loops()
    tween.tween_property($Sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.6)
    tween.tween_property($Sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        collect()

func collect() -> void:
    if GameManager.player_health >= GameManager.max_health:
        return
    GameManager.heal(1)
    AudioManager.play_sfx("powerup")
    set_deferred("monitoring", false)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.finished.connect(queue_free)
