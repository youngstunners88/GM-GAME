extends PowerUpBase

func _ready() -> void:
    super._ready()
    power_up_type = "big"
    duration = 10.0
    sprite.color = Color(1.0, 0.0, 0.0, 1.0)
    sprite.size = Vector2(28, 28)
    collision.position = Vector2(14, 14)
