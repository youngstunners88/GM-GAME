extends Area2D
## Thrown axe — Lil Blunt's base attack. Flies flat in the facing direction,
## spinning as it travels; kills a minion on contact and shatters boulders.
## A vertical component lets the purple-power fan spread axes up and down.
##
## Collision: layer 7 (Projectiles), masks Enemies (bit 3) + Hazards (bit 6, the
## rolling-boulder layer). It deliberately does NOT mask World, so a low throw
## skims the ground instead of despawning on the first floor tile.

var direction: float = 1.0        ## -1 = left, +1 = right
var speed: float = 620.0
var vertical: float = 0.0         ## px/s vertical drift (fan spread)
var damage: int = 1
var lifetime: float = 1.2
var _spin: float = 0.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(_despawn)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	position.y += vertical * delta
	# Spin in the direction of travel so the blade reads as thrown, not sliding.
	_spin += delta * 20.0 * signf(direction)
	if sprite:
		sprite.rotation = _spin

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
		_impact()
	elif body.has_method("smash"):        # rolling boulder
		body.smash()
		_impact()

func _impact() -> void:
	AudioManager.play_sfx("hit")
	_despawn()

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
