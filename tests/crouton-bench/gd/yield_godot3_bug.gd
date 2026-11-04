extends Node2D

func flash() -> void:
	modulate = Color.WHITE
	yield(get_tree().create_timer(0.2), "timeout")
	modulate = Color.TRANSPARENT
