extends PowerUpBase
## Big Axe — the heavy-throw upgrade ("bigaxe" type).
##
## Founder request (2026-08-04): "The bigger axe that Lil Blunt collects in
## this stage should make it that when he throws his axe it is much larger and
## more powerful so that it immediately kills any enemy with one strike but
## that it also damages the ladder and anything that comes in its way. Of
## course it shouldnt kill the boss with one strike but must be able to do
## more damage than Lil Blunt's normal strikes."
##
## All of the behaviour lives in src/combat/axe.gd behind its `big` flag —
## this pickup only flips the power-up state. See axe.gd for the damage
## values and the explicit not-a-boss-one-shot constraint.
##
## 25s: a touch longer than the pickaxe's 20s because this one is the
## power fantasy the founder asked for and a short window would make the
## upgrade feel like it barely happened.

func _ready() -> void:
	super._ready()
	power_up_type = "bigaxe"
	duration = 25.0
