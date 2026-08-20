extends Node

var entity_scenes: Dictionary = {
	"tax_collector": preload("res://src/enemies/tax_collector.tscn"),
	"fly_swarm": preload("res://src/enemies/fly_swarm.tscn"),
	"hostile_vine": preload("res://src/enemies/hostile_vine.tscn"),
	"rolling_boulder": preload("res://src/enemies/rolling_boulder.tscn"),
	"coin": preload("res://src/collectibles/coin.tscn"),
	"coin_eth": preload("res://src/collectibles/coin_eth.tscn"),
	"coin_btc": preload("res://src/collectibles/coin_btc.tscn"),
	"coin_sol": preload("res://src/collectibles/coin_sol.tscn"),
	# PER-STAGE PROTOCOL TOKENS (founder: "the game must include Tokens in the
	# scoring system"). Both reuse crypto_coin.gd, so they count toward the coin
	# tally AND add score exactly like the Solana coins already do — they ADD to
	# the existing pickups rather than replacing them ("that doesnt replace the
	# current Solana coins in stage 2"), and each also credits its protocol's
	# HUD row via crypto_coin.gd's protocol_credit.
	#
	# Stage 1 needs no entry here: coin.gd already swaps the plain "coin" face
	# to the TitanX token whenever GameManager.current_level == 1, so L1's coin
	# trails are already TitanX without a second near-identical pickup type.
	"coin_diamonds": preload("res://src/collectibles/coin_diamonds.tscn"),
	"coin_goldmine": preload("res://src/collectibles/coin_goldmine.tscn"),
	"ethereum_ring": preload("res://src/collectibles/ethereum_ring.tscn"),
	"health_pickup": preload("res://src/collectibles/health_pickup.tscn"),
	"weed_leaf": preload("res://src/powerups/weed_leaf.tscn"),
	"magic_mushroom": preload("res://src/powerups/magic_mushroom.tscn"),
	"diamond_shard": preload("res://src/powerups/diamond_shard.tscn"),
	"purple_weed": preload("res://src/powerups/purple_weed.tscn"),
	"pickaxe_tool": preload("res://src/powerups/pickaxe_tool.tscn"),
	"torch_tool": preload("res://src/powerups/torch_tool.tscn"),
	"big_axe": preload("res://src/powerups/big_axe.tscn"),
	"bong": preload("res://src/powerups/bong.tscn"),
	"breakable_block": preload("res://src/level/breakable_block.tscn"),
	"checkpoint": preload("res://src/level/checkpoint.tscn"),
	"smoke_cloud_platform": preload("res://src/level/smoke_cloud_platform.tscn"),
	"mine_cart": preload("res://src/level/mine_cart.tscn"),
	"timed_door": preload("res://src/level/timed_door.tscn"),
	"pressure_plate": preload("res://src/level/pressure_plate.tscn"),
	"wbtc": preload("res://src/collectibles/wbtc.tscn"),
	"gold_token": preload("res://src/collectibles/gold_token.tscn"),
	"melt_forge": preload("res://src/level/melt_forge.tscn"),
	# Decorative damage traps (founder, Block_Fixes_1, 2026-08-20): "beautiful"
	# but harmful set-dressing, one alluring pair per level, using the
	# founder's own reference art.
	"trap_deadly_beauty": preload("res://src/hazards/trap_deadly_beauty.tscn"),
	"trap_widows_thorn": preload("res://src/hazards/trap_widows_thorn.tscn"),
	"trap_diamond_fang": preload("res://src/hazards/trap_diamond_fang.tscn"),
	"trap_siren_crystal": preload("res://src/hazards/trap_siren_crystal.tscn"),
	"trap_gold_rush": preload("res://src/hazards/trap_gold_rush.tscn"),
	"trap_golden_widow": preload("res://src/hazards/trap_golden_widow.tscn"),
}

## Spawn an entity by type name. `props` are set on the instance BEFORE it
## enters the tree — required for exports that _ready() consumes (e.g.
## MineCart.cart_type); setting them after add_child would be too late.
func spawn(type: String, pos: Vector2, parent: Node, props: Dictionary = {}) -> Node:
	if type in entity_scenes:
		var inst = entity_scenes[type].instantiate()
		inst.global_position = pos
		for key in props:
			inst.set(key, props[key])
		parent.add_child(inst)
		return inst
	push_error("EntitySpawner: Unknown entity type: " + type)
	return null
