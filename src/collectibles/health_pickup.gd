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

## A heart is never wasted any more.
##
## Founder rule (2026-08-04): "If the player finds more hearts they can collect
## them and the life count increases." Previously this early-returned when
## already at full health — the pickup stayed on the map, did nothing, and
## there was NO other way in the entire game to gain a life, which is why the
## life count was permanently pinned at its starting 3. Now a heart collected
## at full health converts into an EXTRA LIFE (no upper cap — see
## GameManager.add_life).
func collect() -> void:
    if GameManager.player_health >= GameManager.max_health:
        GameManager.add_life(1)
    else:
        GameManager.heal(1)
    AudioManager.play_sfx("powerup")
    set_deferred("monitoring", false)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.finished.connect(queue_free)
