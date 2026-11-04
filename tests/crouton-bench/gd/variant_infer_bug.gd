extends Node

var config: Dictionary = {"speed": 2.0}

func get_speed() -> float:
	var speed := config.get("speed", 1.0)
	return speed * 2.0
