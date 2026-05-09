extends PowerUpBase

func _ready() -> void:
    super._ready()
    power_up_type = "diamond"
    duration = 8.0
    sprite.color = Color(0.0, 1.0, 1.0, 1.0)
    sprite.size = Vector2(22, 22)
    collision.position = Vector2(11, 11)
