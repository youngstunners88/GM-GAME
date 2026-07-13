extends CPUParticles2D
## Fire-and-forget particle burst: starts emitting on entry and frees itself
## after one emission cycle, so spawn sites never need to manage lifetime.

func _ready() -> void:
	emitting = true
	get_tree().create_timer(lifetime + 0.6).timeout.connect(queue_free)
