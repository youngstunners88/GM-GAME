extends Node

func take_damage(amount: int) -> void:
	print("hit for %d" % amount)

func _ready() -> void:
	take_damage(5)
