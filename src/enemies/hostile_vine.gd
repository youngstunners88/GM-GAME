extends Node2D

@export var extend_time: float = 2.0
@export var retract_time: float = 2.0
@export var damage: int = 1

## VENOM SPIT. Founder: "I also want all of the snakes to spit venom in all the
## stages... to increase the difficulty."
##
## These striking vines are the snakes. They were a purely PASSIVE hazard —
## extend, retract, hurt only what walked into them — so anything that kept its
## distance was never threatened by one. The spit gives them reach without
## turning them into a second Tax Collector: it only fires while the vine is
## EXTENDED (so the tell still telegraphs the danger), only when the player is
## in range, and on its own cooldown.
##
## Reuses boss_projectile.tscn rather than inventing a projectile: it already
## flies in a set direction, damages the player on contact, despawns on world
## geometry, and takes a tint.
const VENOM := preload("res://src/boss/boss_projectile.tscn")
@export var venom_range: float = 420.0
@export var venom_cooldown: float = 1.9
@export var venom_speed: float = 240.0
var _venom_cd: float = 0.0

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
    _venom_cd -= delta
    if is_extended and _venom_cd <= 0.0:
        _spit_venom()
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


## Fire one glob of venom at the player's CURRENT position. Aimed, not
## axis-locked, so a vine below a ledge still threatens someone above it.
func _spit_venom() -> void:
    var p := get_tree().get_first_node_in_group("player")
    if p == null or not is_instance_valid(p):
        return
    var to: Vector2 = p.global_position - global_position
    if to.length() > venom_range:
        return
    _venom_cd = venom_cooldown
    var glob := VENOM.instantiate()
    glob.direction = to.normalized()
    glob.speed = venom_speed
    glob.tint = Color(0.45, 1.0, 0.35, 1.0)   # acid green
    glob.lifetime = 2.6
    # add_child BEFORE setting global_position: on a node outside the tree
    # global_position is just local position.
    get_parent().add_child(glob)
    glob.global_position = global_position
    AudioManager.play_sfx_at("hit", global_position)
