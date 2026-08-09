extends PowerUpBase
## Weed Leaf / Blunt Bud — triggers Blaze Mode.

func _ready() -> void:
    super._ready()
    power_up_type = "blaze"
    duration = 12.0
    # See magic_mushroom.gd: the old sprite.color / sprite.size assignments
    # targeted a ColorRect that this scene no longer uses, threw a runtime
    # error on a Sprite2D, and aborted the rest of _ready(). Removed.
