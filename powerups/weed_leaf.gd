extends PowerUpBase

func _ready() -> void:
    super._ready()
    power_up_type = "blaze"
    duration = 12.0
    sprite.color = Color(0.0, 1.0, 0.0, 1.0)
    sprite.size = Vector2(24, 24)
    collision.position = Vector2(12, 12)
