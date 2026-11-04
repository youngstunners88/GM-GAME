extends Node

func start_cooldown() -> void:
	var t := Timer.new()
	t.one_shot = true
	t.start(1.0)
	add_child(t)
