extends Node2D

@export var extend_time: float = 2.0
@export var retract_time: float = 2.0
@export var damage: int = 1

var is_extended: bool = false
var timer: float = 0.0

@onready var vine_body: Sprite2D = $VineBody
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
    add_to_group("enemy")
    add_to_group("hazard")
    hitbox.body_entered.connect(_on_hitbox_body_entered)
    retract()

func _process(delta: float) -> void:
    timer += delta
    if is_extended and timer >= extend_time:
        retract()
    elif not is_extended and timer >= retract_time:
        extend()

## Physics state is written with set_deferred throughout. retract() is called
## from _ready() (during level build) and both are called from _process(),
## either of which can coincide with a physics flush — a direct write then
## throws "Can't change this state while flushing queries" from
## area_set_shape_disabled. Caught in the 2026-07-30 browser playtest; it was
## spamming the console on every level containing a vine.
func extend() -> void:
    is_extended = true
    timer = 0.0
    # Sprite grows to full size and rises so its base stays planted at the origin.
    var tween := create_tween().set_parallel()
    tween.tween_property(vine_body, "scale", Vector2(1.0, 1.0), 0.3)
    tween.tween_property(vine_body, "position:y", -23.0, 0.3)
    hitbox_shape.set_deferred("disabled", false)
    hitbox.set_deferred("monitorable", true)
    hitbox.set_deferred("monitoring", true)

func retract() -> void:
    is_extended = false
    timer = 0.0
    var tween := create_tween().set_parallel()
    tween.tween_property(vine_body, "scale", Vector2(0.35, 0.35), 0.3)
    tween.tween_property(vine_body, "position:y", -8.0, 0.3)
    hitbox_shape.set_deferred("disabled", true)
    hitbox.set_deferred("monitorable", false)
    hitbox.set_deferred("monitoring", false)

func _on_hitbox_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and body.has_method("take_damage"):
        body.take_damage(damage)

func take_damage(amount: int) -> void:
    # Vines die in 1 hit when extended
    if is_extended:
        var tween := create_tween()
        tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
        tween.tween_property(self, "modulate:a", 0.0, 0.3)
        await tween.finished
        GameManager.add_score(50)
        queue_free()
