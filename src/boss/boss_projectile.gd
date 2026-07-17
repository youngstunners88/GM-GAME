extends Area2D
## Aimed boss projectile — flies in a set direction, damages the player on
## contact, despawns after its lifetime or on hitting the player/world. Used
## by all three bosses for their ranged attacks (clipboard / ETH orb / diamond
## shard); the look is set by `tint`. Spawn it, set `direction`, add to the
## scene. Optional slight homing for the crystal boss's orbs.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var lifetime: float = 4.0
var homing: float = 0.0      ## 0 = straight; >0 curves toward player per sec
var tint: Color = Color(1, 0.9, 0.4, 1)
var _t := 0.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("boss_projectile")
	body_entered.connect(_on_body_entered)
	if sprite:
		sprite.modulate = tint
	get_tree().create_timer(lifetime).timeout.connect(_despawn)

func _physics_process(delta: float) -> void:
	if homing > 0.0:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			var want := global_position.direction_to(p.global_position)
			direction = direction.lerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
	position += direction * speed * delta
	if sprite:
		sprite.rotation += delta * 6.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		_despawn()
	elif body.is_in_group("world"):
		_despawn()

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
