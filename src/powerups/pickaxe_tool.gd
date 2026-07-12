extends PowerUpBase
## Pickaxe tool — Lil Blunt carries it in hand while active ("pickaxe" type):
## smashes rolling boulders on contact, breaks breakable blocks by walking
## into them, and doubles GOLD token yield (see gold_token.gd).

func _ready() -> void:
	super._ready()
	power_up_type = "pickaxe"
	duration = 20.0
