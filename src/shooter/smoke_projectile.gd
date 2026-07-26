extends Area2D
## Bong Blaster smoke bolt (v1.2 prototype). Travels in a fixed direction,
## damages the first valid target, and is absorbed by cover. Player bolts and
## enemy bolts share this script — `hostile` decides who it can hurt, which
## keeps the projectile rules in ONE place instead of two near-copies.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 900.0
var damage: int = 10
var lifetime: float = 1.6
## Enemy-fired bolts hurt the player; player bolts hurt enemies.
var hostile: bool = false
var tint: Color = Color(0.75, 1.0, 0.8, 1.0)

var _life: float = 0.0

func _ready() -> void:
	add_to_group("smoke_projectile")
	# Bolts collide with world (1) + whatever they can damage; cover is world.
	collision_layer = 0
	collision_mask = 1 | 2   # world + player bodies
	_build_visual()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _build_visual() -> void:
	# A soft smoke slug: bright core + trailing puff. No art dependency.
	# Sized/brightened deliberately — in the first browser pass the bolts were
	# 14×6 and read as dark specks against the arena. In a shooter the thing
	# you are shooting has to be the most legible object on screen.
	var glow := ColorRect.new()
	glow.size = Vector2(30, 16)
	glow.position = Vector2(-15, -8)
	glow.color = Color(tint.r, tint.g, tint.b, 0.28)
	add_child(glow)
	var core := ColorRect.new()
	core.size = Vector2(22, 8)
	core.position = Vector2(-11, -4)
	core.color = Color(minf(tint.r + 0.25, 1.0), minf(tint.g + 0.25, 1.0),
		minf(tint.b + 0.25, 1.0), 1.0)
	add_child(core)
	var trail := CPUParticles2D.new()
	trail.amount = 12
	trail.lifetime = 0.35
	trail.preprocess = 0.1
	trail.direction = -direction
	trail.spread = 12.0
	trail.initial_velocity_min = 30.0
	trail.initial_velocity_max = 70.0
	trail.scale_amount_min = 3.0
	trail.scale_amount_max = 7.0
	trail.color = Color(tint.r, tint.g, tint.b, 0.35)
	add_child(trail)
	rotation = direction.angle()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 8)
	cs.shape = rect
	add_child(cs)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life += delta
	if _life >= lifetime:
		_pop()

func _on_body_entered(body: Node2D) -> void:
	# Cover eats bolts from either side — that's the whole point of cover.
	if body.is_in_group("cover"):
		if body.has_method("take_cover_damage"):
			body.take_cover_damage(damage)
		_pop()
		return
	if hostile and body.is_in_group("shooter_player") and body.has_method("take_damage"):
		body.take_damage(1)
		_pop()
		return
	# Solid world geometry stops bolts.
	if not hostile and body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
		_pop()
		return
	if body is StaticBody2D:
		_pop()

func _on_area_entered(area: Area2D) -> void:
	if not hostile and area.is_in_group("enemy_hitbox") and area.has_method("take_damage"):
		area.take_damage(damage)
		_pop()

## Puff out instead of vanishing — impact should always read.
func _pop() -> void:
	if not is_inside_tree():
		return
	var puff := CPUParticles2D.new()
	puff.amount = 10
	puff.lifetime = 0.4
	puff.one_shot = true
	puff.emitting = true
	puff.spread = 180.0
	puff.initial_velocity_min = 40.0
	puff.initial_velocity_max = 110.0
	puff.scale_amount_min = 4.0
	puff.scale_amount_max = 9.0
	puff.color = Color(tint.r, tint.g, tint.b, 0.5)
	puff.global_position = global_position
	get_parent().add_child(puff)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(puff):
			puff.queue_free())
	queue_free()
