extends StaticBody2D

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    add_to_group("breakable")
    sprite.color = Color(0.55, 0.35, 0.2, 1.0)
    sprite.size = Vector2(32, 32)
    collision.position = Vector2(16, 16)

func break_block() -> void:
    AudioManager.play_sfx("damage")
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
    tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
    tween.parallel().tween_property(self, "rotation", randf() * PI, 0.2)
    await tween.finished
    GameManager.add_score(20)
    queue_free()
