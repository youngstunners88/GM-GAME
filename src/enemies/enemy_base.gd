class_name EnemyBase
extends CharacterBody2D

@export var health: int = 1
@export var score_value: int = 50
@export var contact_damage: int = 1
## Analytics id for the death heatmap ("tax", "fly", "vine"...) — subclasses
## set it; deal_damage stamps it so player deaths attribute correctly.
@export var analytics_id: String = "enemy"

var is_dead: bool = false
var is_flashing: bool = false

## The flashing visual. Typed CanvasItem, not Sprite2D, so subclasses whose art
## is a different node type (bosses use a BossSprite/Node2D) can point this at
## their own visual instead of shadowing the member — redeclaring `sprite` in a
## subclass is a HARD PARSE ERROR that silently leaves the whole script
## unattached, which is exactly how bosses 2 and 3 lost their AI.
## get_node_or_null because boss scenes have no "Sprite" child at all.
@onready var sprite: CanvasItem = get_node_or_null("Sprite")

func _ready() -> void:
    add_to_group("enemy")

func take_damage(amount: int) -> void:
    if is_dead:
        return
    health -= amount
    flash()
    EffectSpawner.float_text(global_position, "-%d" % amount, Color.WHITE)
    ScreenShake.medium()
    if health <= 0:
        die()

func flash() -> void:
    if is_flashing or sprite == null:
        return
    is_flashing = true
    var tween := create_tween()
    tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
    tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
    tween.finished.connect(func() -> void: is_flashing = false)

func die() -> void:
    is_dead = true
    set_physics_process(false)
    GameManager.add_score(score_value)
    EffectSpawner.burst("explosion", global_position)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    tween.finished.connect(queue_free)

func deal_damage(target: Node2D) -> void:
    if target.has_method("take_damage"):
        GameManager.last_damage_source = analytics_id
        target.take_damage(contact_damage)
