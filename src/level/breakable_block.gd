extends StaticBody2D

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    add_to_group("breakable")
    # A breakable block sits at the Auditor's torso height on his ground lane, so
    # it is one of the walls that blocks his chase (leverage). Tag it into the
    # boss "soft platform" set so he winds up and vaults it like a floating
    # platform — phasing it only during the brief vault arc — instead of pinning
    # against it forever (measured: the all-solid revert stranded him here at
    # x=1882 for 42s). See auditor.gd's wall-vault.
    add_to_group("boss_soft_platform")
    collision.position = Vector2(16, 16)

func break_block() -> void:
    AudioManager.play_sfx("damage")
    ScreenShake.shake(0.15, 3.0)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
    tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
    tween.parallel().tween_property(self, "rotation", randf() * PI, 0.2)
    tween.finished.connect(func() -> void:
        GameManager.add_score(20)
        queue_free()
    )
