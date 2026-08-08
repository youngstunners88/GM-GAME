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
	if MobileInputHandler:
		MobileInputHandler.touch_interact.connect(_on_mobile_interact)
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

func _on_mobile_interact() -> void:
	if player_in_forge:
		_activate_melt()

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
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 30.0
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

## Founder (2026-08-04): "These blocks keep appearing in level 3 and they look
## shit!!! It's trashy and cheap". He red-circled several flat orange/brown
## rectangles — this forge was one of them (five of them are placed in Level
## 3), along with timed_door and pressure_plate.
##
## They were bare untextured ColorRects while every real platform in the game
## goes through LevelBase._create_platform, which layers a dark body, the
## tile_block-chain texture, and a bright lip. Matching that construction is
## what makes these read as built objects in the Gold Rush instead of
## programmer-art placeholder boxes. Palette taken from level_03_data.tres
## (platform_body_color / platform_lip_color).
const BLOCK_TEX := preload("res://src/assets/sprites/tile_block-chain.png")
const L3_BODY := Color(0.18, 0.09, 0.04, 1.0)
const L3_LIP := Color(0.95, 0.75, 0.2, 1.0)

func _setup_visual() -> void:
	# Furnace body — dark stone base, tiled block texture, gold lip + feet.
	var furnace := ColorRect.new()
	furnace.color = L3_BODY
	furnace.size = Vector2(60, 80)
	furnace.position = Vector2(-30, -40)
	add_child(furnace)

	var blocks := Sprite2D.new()
	blocks.texture = BLOCK_TEX
	blocks.centered = false
	blocks.region_enabled = true
	blocks.region_rect = Rect2(0, 0, 60, 80)
	blocks.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	blocks.position = Vector2(-30, -40)
	blocks.modulate = Color(1.0, 0.82, 0.6, 0.85)  # warm the tiles to gold-rush tone
	add_child(blocks)

	# Molten mouth — the bit that should actually read as a forge.
	var mouth := ColorRect.new()
	mouth.color = Color(1.0, 0.45, 0.12, 0.95)
	mouth.size = Vector2(34, 22)
	mouth.position = Vector2(-17, -6)
	add_child(mouth)

	# Gold trim: top lip plus a matching base plate so it sits, not floats.
	var trim := ColorRect.new()
	trim.color = L3_LIP
	trim.size = Vector2(60, 4)
	trim.position = Vector2(-30, -44)
	add_child(trim)
	var base := ColorRect.new()
	base.color = L3_LIP
	base.size = Vector2(68, 5)
	base.position = Vector2(-34, 40)
	add_child(base)

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
