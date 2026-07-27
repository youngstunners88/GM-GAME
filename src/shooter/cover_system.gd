extends StaticBody2D
## Destructible cover (v1.2 prototype). THE core shooter verb: it eats bolts
## from either side, has HP, visibly degrades, and eventually dies — which is
## the encounter's pacing clock (GDD §2.1). Press DOWN inside its duck zone to
## crouch behind it; while ducked the crate takes the hits instead of you.

signal destroyed

@export var max_hp: int = 40
@export var crate_size: Vector2 = Vector2(56, 56)

var hp: int = 40
var _duck_zone: Area2D
var _body: ColorRect
var _cracks: Node2D

func _ready() -> void:
	add_to_group("cover")
	hp = max_hp
	collision_layer = 1          # world: bolts and bodies collide with it
	collision_mask = 0
	_build()

func _build() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = crate_size
	cs.shape = rect
	add_child(cs)

	_body = ColorRect.new()
	_body.size = crate_size
	_body.position = -crate_size / 2.0
	_body.color = Color(0.42, 0.31, 0.18, 1.0)   # crate timber
	add_child(_body)

	# Bright lip so it reads as standable/solid like v1.0 platforms do.
	var lip := ColorRect.new()
	lip.size = Vector2(crate_size.x, 4)
	lip.position = Vector2(-crate_size.x / 2.0, -crate_size.y / 2.0)
	lip.color = Color(0.75, 0.55, 0.3, 1.0)
	add_child(lip)

	_cracks = Node2D.new()
	add_child(_cracks)

	# Duck zone: slightly wider than the crate, sits behind/around it.
	_duck_zone = Area2D.new()
	_duck_zone.collision_layer = 0
	_duck_zone.collision_mask = 2   # player
	var zcs := CollisionShape2D.new()
	var zrect := RectangleShape2D.new()
	zrect.size = Vector2(crate_size.x + 46, crate_size.y + 12)
	zcs.shape = zrect
	_duck_zone.add_child(zcs)
	add_child(_duck_zone)
	_duck_zone.body_entered.connect(func(b: Node2D) -> void:
		if b.has_method("enter_cover_zone"):
			b.enter_cover_zone(self))
	_duck_zone.body_exited.connect(func(b: Node2D) -> void:
		if b.has_method("exit_cover_zone"):
			b.exit_cover_zone(self))

## Bolts call this. Damage states are visible so the player can read how much
## cover they have left WITHOUT a health bar (GDD: readable, no HUD clutter).
func take_cover_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	AudioManager.play_sfx("hit")
	# Impact shake on the crate itself, not the screen — local feedback.
	var tw := create_tween()
	tw.tween_property(_body, "position:x", -crate_size.x / 2.0 + 3.0, 0.04)
	tw.tween_property(_body, "position:x", -crate_size.x / 2.0, 0.06)
	_update_damage_state()
	if hp <= 0:
		_shatter()

func _update_damage_state() -> void:
	var ratio := float(hp) / float(max_hp)
	if ratio > 0.66:
		return
	# Cracked (<=66%) and critical (<=33%) add visible chunks + darkening.
	_body.color = Color(0.34, 0.24, 0.13, 1.0) if ratio > 0.33 else Color(0.26, 0.17, 0.09, 1.0)
	if _cracks.get_child_count() < 3:
		var chunk := ColorRect.new()
		chunk.size = Vector2(10, 10)
		chunk.position = Vector2(
			randf_range(-crate_size.x / 2.0, crate_size.x / 2.0 - 10.0),
			randf_range(-crate_size.y / 2.0, crate_size.y / 2.0 - 10.0))
		chunk.color = Color(0.12, 0.09, 0.06, 1.0)
		_cracks.add_child(chunk)
	if ratio <= 0.33:
		# Critical: it visibly trembles — "this is about to go".
		var shake := create_tween().set_loops()
		shake.tween_property(_body, "rotation", 0.03, 0.09)
		shake.tween_property(_body, "rotation", -0.03, 0.09)

func _shatter() -> void:
	destroyed.emit()
	AudioManager.play_sfx("damage")
	ScreenShake.shake(0.18, 5.0)
	var burst := CPUParticles2D.new()
	burst.amount = 22
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.emitting = true
	burst.spread = 180.0
	burst.gravity = Vector2(0, 700)
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 240.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 10.0
	burst.color = Color(0.5, 0.36, 0.2, 0.9)
	burst.global_position = global_position
	get_parent().add_child(burst)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free())
	queue_free()
