class_name Ep2CreatureHealth
extends Node
## One small hit-point component for Episode 2 animals (vultures, bison, horses).
##
## The bear brain and the town's people keep their own story systems; this is the shared family for the creatures a bullet can
## simply wound and put down. A room attaches it under the creature's root as `CreatureHealth`, calls `take_hit()` from its shot
## ray, and answers the signals ("hit but still moving", "down").
##
## Nothing here knows about the model, the room or the save. The owner decides how a wound looks, how a body falls, and when it
## is cleaned up, so the same component can sit on a soaring bird and a hitch-rail horse without dragging either into the other's
## business.

signal damaged(hp_left: int, max_hp: int, at: Vector3)
signal wounded(hp_left: int, max_hp: int, at: Vector3)
signal died(at: Vector3)

@export var max_hp: int = 3
var hp: int = 0
var dead: bool = false


func _ready() -> void:
	if hp <= 0:
		hp = maxi(1, max_hp)


## Set the pool before (or just after) the node enters the tree. Safe to re-use when a room restages animals.
func configure(pool: int) -> void:
	max_hp = maxi(1, pool)
	hp = max_hp
	dead = false


func is_alive() -> bool:
	return not dead and hp > 0


func health_ratio() -> float:
	return clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)


## A bullet hit. Returns true when this hit put the creature down. A dead creature ignores further hits (so a corpse never
## emits a second death, and a retry can reconfigure the same component).
func take_hit(amount: int = 1, at: Vector3 = Vector3.ZERO) -> bool:
	if dead or hp <= 0:
		return false
	hp = maxi(0, hp - maxi(1, amount))
	if hp == 0:
		dead = true
		died.emit(at)
	else:
		wounded.emit(hp, max_hp, at)
	damaged.emit(hp, max_hp, at)
	return dead
