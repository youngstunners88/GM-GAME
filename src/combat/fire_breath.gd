extends Area2D
## ETH-flask fire breath — the purple-power channel. Lil Blunt swigs from the
## icy ETH flask and exhales a short cone of flame in front of him. Spawned as a
## child of the player so it tracks his position; it ticks damage to every enemy
## caught in the cone and flings a burst of fire particles for feel.
##
## Monitors Enemies (mask bit 3). Lives ~0.9s then despawns.

var direction: float = 1.0
var lifetime: float = 0.9
var tick_interval: float = 0.15
var _tick: float = 0.0

@onready var particles: CPUParticles2D = $Flame

func _ready() -> void:
	add_to_group("projectile")
	# Orient the whole cone (collision + particles) to the facing direction.
	scale.x = signf(direction)
	if particles:
		particles.emitting = true
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(_despawn)
	_burn()  # first tick immediately, so a quick tap-through still stings

func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		_burn()

func _burn() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(1)

func _despawn() -> void:
	if is_instance_valid(self):
		if particles:
			particles.emitting = false
		queue_free()
