extends PowerUpBase
## Purple Weed — the flagship strain. The top-tier power-up (think Mario's
## super mushroom, but chill): stronger than Blaze Mode with faster smoke
## puffs and a royal purple glow. Type "purple" is handled by PowerUpHandler.

func _ready() -> void:
	super._ready()
	power_up_type = "purple"
	duration = 15.0
