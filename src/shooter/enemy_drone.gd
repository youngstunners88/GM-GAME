extends CharacterBody2D
## Tax Drone (v1.2 prototype) — the roster's baseline FSM:
##   PATROL → (line of sight) → ALERT → TELEGRAPH → FIRE → REPOSITION → PATROL
## Architecture referenced from shooter-AI patterns (state machine + LOS
## raycast); no third-party code copied (roadmap rule).
##
## Fairness rules baked in (from the v1.0 corrections brief):
##  - it never shoots what it cannot SEE (raycast, cover blocks LOS),
##  - every shot has a ≥0.8s readable telegraph (flash + audio),
##  - it hovers to a firing altitude instead of rushing, so the player always
##    has time to reach cover.

const BOLT := preload("res://src/shooter/smoke_projectile.tscn")

enum State { PATROL, ALERT, TELEGRAPH, FIRE, REPOSITION }

@export var max_hp: int = 20
@export var patrol_distance: float = 190.0
@export var patrol_speed: float = 70.0
@export var sight_range: float = 620.0
@export var telegraph_time: float = 0.85

var hp: int = 20
var state: State = State.PATROL
var _origin: Vector2
var _dir: float = 1.0
var _timer: float = 0.0
var _player: Node2D = null

var _body: ColorRect
var _eye: ColorRect
var _ray: RayCast2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("tax_drone")
	hp = max_hp
	collision_layer = 4          # enemy layer (distinct from world/player)
	collision_mask = 1           # collide with world only
	_origin = global_position
	_build()

func _build() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 36)
	cs.shape = rect
	add_child(cs)

	_body = ColorRect.new()
	_body.size = Vector2(56, 36)
	_body.position = Vector2(-28, -18)
	_body.color = Color(0.32, 0.34, 0.42, 1.0)   # bureaucratic gunmetal
	add_child(_body)

	# The "eye" is the telegraph surface — it flares before every shot.
	_eye = ColorRect.new()
	_eye.size = Vector2(20, 10)
	_eye.position = Vector2(-10, -5)
	_eye.color = Color(0.5, 0.9, 1.0, 1.0)
	add_child(_eye)

	# Rotor hint so it reads as a flyer, not a floating box.
	var rotor := ColorRect.new()
	rotor.size = Vector2(70, 4)
	rotor.position = Vector2(-35, -24)
	rotor.color = Color(0.6, 0.62, 0.7, 0.8)
	add_child(rotor)
	var tw := create_tween().set_loops()
	tw.tween_property(rotor, "scale:x", 0.6, 0.12)
	tw.tween_property(rotor, "scale:x", 1.0, 0.12)

	_ray = RayCast2D.new()
	_ray.collision_mask = 1 | 2   # world (incl. cover) + player
	_ray.collide_with_areas = false
	add_child(_ray)

func _physics_process(delta: float) -> void:
	if not StateMachine.is_playing():
		return
	_timer -= delta
	_player = get_tree().get_first_node_in_group("shooter_player")

	match state:
		State.PATROL:
			velocity.x = patrol_speed * _dir
			velocity.y = sin(Time.get_ticks_msec() / 400.0) * 18.0   # idle bob
			if absf(global_position.x - _origin.x) > patrol_distance:
				_dir *= -1.0
			if _can_see_player():
				_enter_alert()

		State.ALERT:
			# Climb to firing altitude above the player instead of charging.
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			var want_y := (_player.global_position.y - 120.0) if _player else global_position.y
			velocity.y = clampf(want_y - global_position.y, -110.0, 110.0)
			if _timer <= 0.0:
				if _can_see_player():
					_enter_telegraph()
				else:
					state = State.PATROL

		State.TELEGRAPH:
			velocity = velocity.lerp(Vector2.ZERO, 0.15)
			if _timer <= 0.0:
				_fire()

		State.FIRE:
			if _timer <= 0.0:
				_enter_reposition()

		State.REPOSITION:
			velocity.x = patrol_speed * 1.6 * _dir
			velocity.y = sin(Time.get_ticks_msec() / 300.0) * 30.0
			if _timer <= 0.0:
				state = State.PATROL if not _can_see_player() else State.ALERT
				_timer = 0.4

	move_and_slide()
	if is_on_wall():
		_dir *= -1.0

## LOS: cover and world geometry genuinely block sight (that's why ducking
## behind a crate makes the drone lose you).
func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if global_position.distance_to(_player.global_position) > sight_range:
		return false
	_ray.target_position = to_local(_player.global_position)
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return true
	var hit := _ray.get_collider()
	return hit != null and hit.is_in_group("shooter_player")

func _enter_alert() -> void:
	state = State.ALERT
	_timer = 0.45
	_eye.color = Color(1.0, 0.75, 0.2, 1.0)   # amber = "I see you"

func _enter_telegraph() -> void:
	state = State.TELEGRAPH
	_timer = telegraph_time
	AudioManager.play_sfx("error")
	# Unmistakable red pulse for the full wind-up — the fairness contract.
	var tw := create_tween().set_loops(3)
	tw.tween_property(_eye, "color", Color(1.0, 0.2, 0.2, 1.0), telegraph_time / 6.0)
	tw.tween_property(_eye, "color", Color(1.0, 0.9, 0.9, 1.0), telegraph_time / 6.0)

func _fire() -> void:
	state = State.FIRE
	_timer = 0.35
	_eye.color = Color(0.5, 0.9, 1.0, 1.0)
	if _player == null or not is_instance_valid(_player):
		return
	var bolt := BOLT.instantiate()
	bolt.direction = global_position.direction_to(_player.global_position)
	bolt.hostile = true
	bolt.speed = 430.0            # slow enough to dodge/cover — readable
	bolt.tint = Color(1.0, 0.85, 0.45, 1.0)   # audit-paper amber
	bolt.global_position = global_position + bolt.direction * 26.0
	get_parent().add_child(bolt)
	AudioManager.play_sfx("throw")

func _enter_reposition() -> void:
	state = State.REPOSITION
	_timer = 0.9
	_dir = -_dir

func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	AudioManager.play_sfx("damage")
	# Hit flash + knockback: the player must FEEL the hit land.
	var tw := create_tween()
	tw.tween_property(_body, "color", Color(3, 3, 3, 1), 0.04)
	tw.tween_property(_body, "color", Color(0.32, 0.34, 0.42, 1.0), 0.10)
	if _player:
		velocity += _player.global_position.direction_to(global_position) * 90.0
	# Being shot instantly makes it hostile even if it hadn't seen you.
	if state == State.PATROL:
		_enter_alert()
	if hp <= 0:
		_die()

func _die() -> void:
	set_physics_process(false)
	ComboSystem.add_score(75)   # routes through GameManager w/ combo multiplier
	EffectSpawner.burst("explosion", global_position)
	ScreenShake.shake(0.22, 6.0)
	AudioManager.play_sfx("explosion")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 0.6), 0.08)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.18)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tw.finished.connect(queue_free)
