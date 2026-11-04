extends Node

func start_cooldown() -> void:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.start(1.0)
