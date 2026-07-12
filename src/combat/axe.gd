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
	# Some enemies (e.g. HostileVine) are a Node2D with an Area2D hitbox rather
	# than a physics body — those only surface through area_entered.
	area_entered.connect(_on_area_entered)
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
	if _hit(body):
		_impact()
	elif body.has_method("smash"):        # rolling boulder
		body.smash()
		_impact()

func _on_area_entered(area: Area2D) -> void:
	# The hitbox Area2D itself usually isn't the enemy — the enemy is its owner.
	if _hit(area) or _hit(area.get_parent()):
		_impact()

## Damages `node` if it's a takeable enemy; returns whether a hit landed.
func _hit(node: Node) -> bool:
	if node and node.is_in_group("enemy") and node.has_method("take_damage"):
		node.take_damage(damage)
		return true
	return false

func _impact() -> void:
	AudioManager.play_sfx("hit")
	_despawn()

func _despawn() -> void:
	if is_instance_valid(self):
		queue_free()
