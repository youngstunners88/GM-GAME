extends PowerUpBase
## The Bong — a rare bonus pickup tucked in hard-to-reach / secret spots.
## Lil Blunt takes a big hit and lifts off: ~10 seconds of free flight
## (hold jump/up to rise, drift down when you let go). Type "fly" is handled
## in player.gd's _update_fly(). Chill, not chaotic.

func _ready() -> void:
	super._ready()
	power_up_type = "fly"
	duration = 10.0
