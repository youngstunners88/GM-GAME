class_name AsteroidField
extends Node2D
## v1.3 — procedural asteroid hazard field.
##
## SCAFFOLD. Establishes the domain and the spawn/recycle contract; the real
## level design lands with the v1.3 GDD.
##
## Recycles asteroids around the ship rather than spawning an unbounded field:
## an endless spawner is an endless memory bill, and the v1.0 lesson about
## bounded collections (leaderboard TOP_N) applies just as much here.

@export var asteroid_count: int = 24
@export var field_radius: float = 1400.0
@export var min_speed: float = 20.0
@export var max_speed: float = 90.0

var _asteroids: Array[Node2D] = []
var _velocities: Array[Vector2] = []
var _tracked: Node2D

func _ready() -> void:
	_tracked = get_tree().get_first_node_in_group("space_ship")
	for i in range(asteroid_count):
		_spawn(i)

func _spawn(index: int) -> void:
	var rock := Node2D.new()
	var size := randf_range(18.0, 54.0)
	var body := ColorRect.new()
	body.size = Vector2(size, size)
	body.position = -body.size / 2.0
	body.color = Color(0.32, 0.30, 0.34, 1.0)
	rock.add_child(body)
	rock.rotation = randf() * TAU
	rock.position = _random_edge_position()
	add_child(rock)
	_asteroids.append(rock)
	_velocities.append(
		Vector2.RIGHT.rotated(randf() * TAU) * randf_range(min_speed, max_speed))
	# Index kept in the signature so a future pass can vary rock art per slot
	# without changing every caller.
	if index < 0:
		return

func _random_edge_position() -> Vector2:
	var centre := _tracked.global_position if is_instance_valid(_tracked) else global_position
	return centre + Vector2.RIGHT.rotated(randf() * TAU) * field_radius

func _process(delta: float) -> void:
	if not StateMachine.is_playing():
		return
	var centre := _tracked.global_position if is_instance_valid(_tracked) else global_position
	for i in range(_asteroids.size()):
		var rock := _asteroids[i]
		rock.position += _velocities[i] * delta
		rock.rotation += delta * 0.4
		# Wrap instead of destroy: constant count, no allocation churn.
		if rock.global_position.distance_to(centre) > field_radius * 1.4:
			rock.position = _random_edge_position()
