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

## FOUNDER, 2026-08-26 (P0): "When Lil Blunt jumps on the blue block it
## disappears then he freezes and the music continues but the game is frozen!!!"
##
## ROOT CAUSE: this used to tween `self` (the StaticBody2D) to Vector2.ZERO —
## which scales its CollisionShape2D to zero too. A zero-scale collider is
## DEGENERATE (its transform is non-invertible), so a player standing on the
## block at that moment is left in contact with a broken floor: he cannot
## depenetrate, `is_on_floor()` stops resolving, and a Big-Mode ground pound
## (which is exactly what breaks the block — see player._resolve_ground_pound)
## never clears `_ground_pounding`. Result: hard freeze with the music still
## playing. The player breaks the very block he is standing on, so this fires
## every single time.
##
## FIX, two parts, both required:
##  1. Kill the COLLIDER the instant the block breaks (deferred — we are inside
##     a physics callback here; a direct write throws "Can't change this state
##     while flushing queries", the same hazard timed_door/hostile_vine hit).
##     The block stops being a floor immediately and cleanly, so the player just
##     falls like the block was never there.
##  2. Animate the SPRITE, never the body. The physics transform is left at
##     scale 1 for its whole life, so a degenerate collider cannot exist at all.
func break_block() -> void:
    AudioManager.play_sfx("damage")
    ScreenShake.shake(0.15, 3.0)
    collision.set_deferred("disabled", true)
    var tween := create_tween()
    tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.05)
    tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
    tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
    tween.parallel().tween_property(sprite, "rotation", randf() * PI, 0.2)
    tween.finished.connect(func() -> void:
        GameManager.add_score(20)
        queue_free()
    )
