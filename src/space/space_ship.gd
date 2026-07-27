class_name SpaceShip
extends CharacterBody2D
## v1.3 "Cosmic Blunt" — player ship chassis.
##
## SCAFFOLD, NOT SHIPPED CONTENT. v1.3 has no GDD yet, so this establishes the
## domain boundary and the hull contract only. It is deliberately not wired to
## any scene: per the roadmap stop conditions, v1.3 does not start until the
## v1.2 shooter prototype is proven fun.
##
## Boundary rule (systems architecture §2.3): `space/` never references
## `shooter/` or `level/`. Cross-mode state goes through GameManager.
##
## Newtonian-ish handling on purpose — the contrast with the platformer's
## grounded, snappy feel is the point of a space mode. Hulls tune the numbers;
## this file owns the integration.

signal hull_changed(current: int, maximum: int)
signal destroyed

@export var thrust: float = 620.0
@export var rotation_speed: float = 3.4
## Space has no friction; a small damping keeps the ship controllable without
## making it feel like it's flying through soup.
@export var linear_damping: float = 0.4
@export var max_speed: float = 720.0

var hull: SpaceShipHull
var hull_points: int = 0

func _ready() -> void:
	add_to_group("player")
	add_to_group("space_ship")
	if hull == null:
		equip_hull(ShipHullGreenLeaf.new())

## Hulls are stat packs, not subclasses of the ship — so a hull can be swapped
## at runtime (hangar screen) without rebuilding the player node.
func equip_hull(new_hull: SpaceShipHull) -> void:
	hull = new_hull
	thrust = hull.thrust
	rotation_speed = hull.rotation_speed
	max_speed = hull.max_speed
	hull_points = hull.max_hull
	hull_changed.emit(hull_points, hull.max_hull)

func _physics_process(delta: float) -> void:
	if not StateMachine.is_playing():
		return
	var turn := Input.get_axis("move_left", "move_right")
	rotation += turn * rotation_speed * delta
	if Input.is_action_pressed("move_up"):
		velocity += Vector2.RIGHT.rotated(rotation) * thrust * delta
	velocity = velocity.limit_length(max_speed)
	velocity = velocity.lerp(Vector2.ZERO, linear_damping * delta)
	move_and_slide()

func take_damage(amount: int) -> void:
	hull_points -= amount
	hull_changed.emit(hull_points, hull.max_hull if hull else 0)
	ScreenShake.shake(0.2, 6.0)
	AudioManager.play_sfx("damage")
	if hull_points <= 0:
		destroyed.emit()
