class_name WeaponBongBlaster
extends WeaponBase
## Tier 1 — "Single Toke" (GDD v1.2 §1.3).
##
## One smoke bolt, fast recovery, cheap. Deliberately the most RELIABLE tier
## rather than the weakest: every later tier is a trade against it, not a
## strict upgrade. That rule exists because of the v1.0 Big Mode bug, where a
## "power-up" removed an ability and became a downgrade.

const BOLT := preload("res://src/shooter/smoke_projectile.tscn")

func _ready() -> void:
	display_name = "Single Toke"
	fire_cooldown = 0.17
	ammo_cost = 1
	damage = 10
	projectile_speed = 900.0
	super._ready()

func _spawn_projectiles(origin: Vector2, direction: Vector2) -> void:
	var bolt := BOLT.instantiate()
	bolt.direction = direction
	bolt.hostile = false
	bolt.damage = damage
	bolt.speed = projectile_speed
	bolt.global_position = origin
	# Parent to the level, not the weapon: a bolt must outlive the muzzle's
	# transform, and must not inherit the arm's rotation once it's in flight.
	_projectile_parent().add_child(bolt)

## Bolts belong to the room. Falling back to the tree root keeps the weapon
## usable in a bare test scene with no level wrapper.
func _projectile_parent() -> Node:
	var owner_node := get_parent()
	if owner_node != null and owner_node.get_parent() != null:
		return owner_node.get_parent()
	return get_tree().current_scene if get_tree().current_scene != null else self
