class_name ShipHullGreenLeaf
extends SpaceShipHull
## v1.3 starter hull — "Green Leaf".
##
## The reliable baseline, same design role Tier 1 plays for the Bong Blaster:
## every other hull is a TRADE against this one, never a strict upgrade. Keep
## that rule when adding Diamond Cruiser and Smoke Runner — the v1.0 Big Mode
## bug (a "power-up" that removed double jump) is the cautionary tale.

func _init() -> void:
	display_name = "Green Leaf"
	max_hull = 100
	thrust = 620.0
	rotation_speed = 3.4
	max_speed = 720.0
	tint = Color(0.45, 0.95, 0.5, 1.0)
