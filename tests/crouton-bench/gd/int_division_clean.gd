extends Node

var hp: int = 30
var max_hp: int = 100

func health_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)
