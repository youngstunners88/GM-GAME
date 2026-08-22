extends StaticBody2D

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    add_to_group("breakable")
    collision.position = Vector2(16, 16)

## `award_score` is false when the BOSS smashes his way through — the block is
## destroyed and the effect plays, but the player did not earn it.
var _breaking: bool = false

func break_block(award_score: bool = true) -> void:
    if _breaking:
        return
    _breaking = true
    # Drop the collision on the FIRST frame of the break, not when the tween
    # finishes. Founder, 2026-08-22: the Auditor smashes blocks by walking into
    # them, and leaving the body solid for the tween's full 0.25s meant he was
    # still walled long enough to re-trigger his own wall-leap before the block
    # actually cleared — the block died but he had already launched.
    collision.set_deferred("disabled", true)
    AudioManager.play_sfx("damage")
    ScreenShake.shake(0.15, 3.0)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
    tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
    tween.parallel().tween_property(self, "rotation", randf() * PI, 0.2)
    tween.finished.connect(func() -> void:
        if award_score:
            GameManager.add_score(20)
        queue_free()
    )
