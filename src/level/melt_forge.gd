extends Area2D
## Melt Forge — whitepaper Fort Knox "Melt" mechanic (Pillar 2).
## Player enters forge → press E → burn 3 GOLD for 10-second boost
## (walk 3×, jump 2×, invincible, red aura particles).

signal melt_activated
signal melt_expired

@export var gold_cost: int = 3
@export var boost_duration: float = 10.0
@export var walk_speed_multiplier: float = 3.0
@export var jump_force_multiplier: float = 2.0

var player_in_forge: bool = false
var player_ref: Node2D = null
var melt_active: bool = false
var melt_timer: float = 0.0

@onready var shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("interact")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_visual()

func _process(delta: float) -> void:
	if melt_active:
		melt_timer -= delta
		if melt_timer <= 0:
			_end_melt()

func _physics_process(_delta: float) -> void:
	if player_in_forge and Input.is_action_just_pressed("interact"):
		_activate_melt()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_forge = true
		player_ref = body
		AudioManager.play_sfx("powerup")

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_in_forge = false
		player_ref = null

func _activate_melt() -> void:
	if melt_active or not player_ref:
		return
	if GoldMineSystem.gold_balance < gold_cost:
		AudioManager.play_sfx("error")
		return

	GoldMineSystem.gold_balance -= gold_cost
	GoldMineSystem.gold_changed.emit(GoldMineSystem.gold_balance)
	melt_active = true
	melt_timer = boost_duration

	# Apply boost to player if it has the required methods
	if player_ref.has_method("apply_melt_boost"):
		player_ref.apply_melt_boost(walk_speed_multiplier, jump_force_multiplier, boost_duration)

	# Particle effect: red aura
	var particles := CPUParticles2D.new()
	particles.amount = 16
	particles.lifetime = boost_duration
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_CIRCLE
	particles.emission_radius = 30
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.color = Color(1.0, 0.2, 0.2, 0.8)
	particles.gravity = Vector2(0, -100)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	add_child(particles)
	particles.emitting = true

	melt_activated.emit()
	AudioManager.play_sfx("powerup")
	await get_tree().create_timer(boost_duration).timeout
	particles.queue_free()

func _end_melt() -> void:
	melt_active = false
	if player_ref and player_ref.has_method("end_melt_boost"):
		player_ref.end_melt_boost()
	melt_expired.emit()

func _setup_visual() -> void:
	# Furnace: dark red-brown square with gold trim
	var furnace := ColorRect.new()
	furnace.color = Color(0.4, 0.15, 0.1, 1.0)
	furnace.size = Vector2(60, 80)
	furnace.position = Vector2(-30, -40)
	add_child(furnace)

	# Gold trim
	var trim := ColorRect.new()
	trim.color = Color(1.0, 0.84, 0.0, 1.0)
	trim.size = Vector2(60, 4)
	trim.position = Vector2(-30, -44)
	add_child(trim)

	# Glow effect (bobbing intensity)
	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.3, 0.1, 0.3)
	glow.size = Vector2(80, 100)
	glow.position = Vector2(-40, -50)
	add_child(glow)

	var tween := create_tween().set_loops()
	tween.tween_property(glow, "self_modulate:a", 0.6, 0.6)
	tween.tween_property(glow, "self_modulate:a", 0.3, 0.6)

	# Collision shape
	if not shape:
		shape = CollisionShape2D.new()
		add_child(shape)
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(60, 80)
	shape.shape = rect_shape
	shape.position = Vector2(0, 0)
