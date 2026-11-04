extends Node

var enemies: Array = []

func prune_dead() -> void:
	for e in enemies:
		if e.health <= 0:
			enemies.erase(e)
