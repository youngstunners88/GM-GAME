class_name Ep2CreatureHealth
extends Node
## One small hit-point component for Episode 2 animals (vultures, bison, town and yard horses) - and for the few shootable things that
## are not animals but break the same way: the day-88 river's rafts (river_cover.gd, RAFT_HP) use it as their timber's hit pool.
##
## The bear brain and the town's people keep their own story systems; this is the shared family for the creatures a bullet can
## simply wound and put down. A room attaches it under the creature's root as `CreatureHealth`, calls `take_hit()` from its shot
## ray, and answers the signals. Lil Blunt's own mount is the one horse outside it: its wounds travel with the save in
## `Ep2ArmoryState.horse_wounds`, and a second counter here could only drift from that.
##
## Nothing here knows about the model, the room or the save. The owner decides how a wound looks and when a body is cleaned up, so
## the same component can sit on a soaring bird and a hitch-rail horse without dragging either into the other's business.

signal wounded(hp_left: int, max_hp: int, at: Vector3)
signal died(at: Vector3)

const COMPONENT_NAME := "CreatureHealth"
const HORSE_GROUP := "ep2_creature_horse"

@export var max_hp: int = 3
var hp: int = 0
var dead: bool = false


## Hang a configured component on `body`. Call once per creature.
static func attach(body: Node3D, pool: int) -> Ep2CreatureHealth:
	var health := Ep2CreatureHealth.new()
	health.name = COMPONENT_NAME
	health.configure(pool)
	body.add_child(health)
	return health


## The component on `body`, or null when it has none.
static func of(body: Node) -> Ep2CreatureHealth:
	return body.get_node_or_null(COMPONENT_NAME) as Ep2CreatureHealth


## Lay a dead animal over: `rot` is the final rotation on the X and Z axes (yaw is kept), `lying_y` where its root settles.
static func topple(body: Node3D, rot_x: float, rot_z: float, lying_y: float, seconds: float = 0.55) -> void:
	if not body.is_inside_tree():
		body.rotation = Vector3(rot_x, body.rotation.y, rot_z)
		body.position.y = lying_y
		return
	var tw := body.create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "rotation:x", rot_x, seconds)
	tw.tween_property(body, "rotation:z", rot_z, seconds)
	tw.tween_property(body, "position:y", lying_y, seconds)


## Set the pool. Safe to re-use when a room restages animals.
func configure(pool: int) -> void:
	max_hp = maxi(1, pool)
	hp = max_hp
	dead = false


func is_alive() -> bool:
	return not dead


## A bullet hit. Returns true when this hit put the creature down. A dead creature ignores further hits, so a corpse never emits
## a second death.
func take_hit(amount: int = 1, at: Vector3 = Vector3.ZERO) -> bool:
	if dead:
		return false
	hp = maxi(0, hp - maxi(1, amount))
	if hp == 0:
		dead = true
		died.emit(at)
		return true
	wounded.emit(hp, max_hp, at)
	return false
