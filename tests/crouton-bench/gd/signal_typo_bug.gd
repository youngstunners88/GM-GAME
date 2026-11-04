extends Node

signal health_changed(hp: int)

var hp: int = 10

func hurt(n: int) -> void:
	hp -= n
	emit_signal("helth_changed", hp)
