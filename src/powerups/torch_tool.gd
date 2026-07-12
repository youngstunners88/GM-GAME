extends PowerUpBase
## Flaming torch tool — carried in hand while active ("torch" type): its heat
## radius damages enemies that get close (reuses the player's damage aura)
## and bathes Lil Blunt in a warm glow. Great for the dark Crystal Caverns.

func _ready() -> void:
	super._ready()
	power_up_type = "torch"
	duration = 20.0
