extends Node

var entity_scenes: Dictionary = {
	"tax_collector": preload("res://src/enemies/tax_collector.tscn"),
	"fly_swarm": preload("res://src/enemies/fly_swarm.tscn"),
	"hostile_vine": preload("res://src/enemies/hostile_vine.tscn"),
	"rolling_boulder": preload("res://src/enemies/rolling_boulder.tscn"),
	"coin": preload("res://src/collectibles/coin.tscn"),
	"ethereum_ring": preload("res://src/collectibles/ethereum_ring.tscn"),
	"health_pickup": preload("res://src/collectibles/health_pickup.tscn"),
	"weed_leaf": preload("res://src/powerups/weed_leaf.tscn"),
	"magic_mushroom": preload("res://src/powerups/magic_mushroom.tscn"),
	"diamond_shard": preload("res://src/powerups/diamond_shard.tscn"),
	"breakable_block": preload("res://src/level/breakable_block.tscn"),
	"checkpoint": preload("res://src/level/checkpoint.tscn"),
	"smoke_cloud_platform": preload("res://src/level/smoke_cloud_platform.tscn"),
	"mine_cart": preload("res://src/level/mine_cart.tscn"),
	"timed_door": preload("res://src/level/timed_door.tscn"),
	"pressure_plate": preload("res://src/level/pressure_plate.tscn"),
	"wbtc": preload("res://src/collectibles/wbtc.tscn"),
	"gold_token": preload("res://src/collectibles/gold_token.tscn"),
	"melt_forge": preload("res://src/level/melt_forge.tscn"),
	"mine_cart": preload("res://src/level/mine_cart.tscn"),
}

func spawn(type: String, pos: Vector2, parent: Node) -> Node:
	if type in entity_scenes:
		var inst = entity_scenes[type].instantiate()
		inst.global_position = pos
		parent.add_child(inst)
		return inst
	push_error("EntitySpawner: Unknown entity type: " + type)
	return null
