extends PowerUpBase
## Diamond Shard powerup — invincibility shield in-game.
## On pickup, also applies the whitepaper's permanent 20% Diamond burn mechanic
## via GoldMineSystem.collect_diamonds().

@export var diamond_value: int = 5  # Raw Diamonds before 20% burn

func _ready() -> void:
	super._ready()
	power_up_type = "diamond"
	duration = 8.0

func collect() -> void:
	# Apply whitepaper 20% burn before granting shield powerup
	GoldMineSystem.collect_diamonds(diamond_value)
	super.collect()
