class_name MineCart
extends AnimatableBody2D
## Two-pool mine cart system — represents Fort Knox short (day 88) vs long (day 288) pool choice.
## Fast cart: 150 speed, 5s departure, 10 wBTC reward (day 88 short pool — 60%).
## Slow cart: 80 speed, 12s departure, 50 wBTC reward (day 288 long pool — 40%).
## Player can only take one cart per fork; choice matters for Fort Knox strategy.

enum CartType { FAST, SLOW }

@export var cart_type: CartType = CartType.FAST
@export var move_distance: float = 200.0
@export var start_delay: float = 0.0

var speed: float = 150.0
var cycle_time: float = 5.0
var wbtc_reward: int = 10
var pool_name: String = "short"
var _time_elapsed: float = 0.0
var _visual: ColorRect
var _label_3d: Label3D
var _is_flashing: bool = false
var player_aboard: bool = false

func _ready() -> void:
	if cart_type == CartType.FAST:
		speed = 150.0
		cycle_time = 5.0
		wbtc_reward = 10
		pool_name = "short"
	else:
		speed = 80.0
		cycle_time = 12.0
		wbtc_reward = 50
		pool_name = "long"

	_setup_visual()
	_time_elapsed = start_delay
	add_to_group("cart")
	add_to_group(pool_name + "_pool_cart")

func _setup_visual() -> void:
	# Cart visual: fast = small wooden, slow = armored gold
	_visual = ColorRect.new()
	if cart_type == CartType.FAST:
		_visual.color = Color(0.6, 0.4, 0.2, 1.0)  # Wood color
		_visual.size = Vector2(60, 35)
	else:
		_visual.color = Color(0.7, 0.6, 0.1, 1.0)  # Gold armor
		_visual.size = Vector2(90, 45)

	_visual.position = Vector2(-_visual.size.x / 2, -_visual.size.y / 2)
	add_child(_visual)

	# Collision shape
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _visual.size
	col.shape = shape
	col.position = Vector2(0, 0)
	add_child(col)

	# Label: DAY 88 (Fast) or DAY 288 (Slow)
	var label_node := Node2D.new()
	label_node.name = "PoolLabel"
	var label_text := Label.new()
	if cart_type == CartType.FAST:
		label_text.text = "DAY 88\nFAST"
		label_text.add_theme_font_size_override("font_size", 14)
	else:
		label_text.text = "DAY 288\nSLOW"
		label_text.add_theme_font_size_override("font_size", 14)
	label_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_text.position = Vector2(-label_text.get_combined_minimum_size().x / 2, -60)
	label_node.add_child(label_text)
	add_child(label_node)

func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	var cycle_position := fmod(_time_elapsed, cycle_time) / cycle_time
	position.x = cycle_position * move_distance
	_check_warning_flash(cycle_position)

	# If player is aboard, move them with the cart
	if player_aboard:
		# This would be handled by physics engine (player becomes child or attached)
		pass

func _check_warning_flash(cycle_position: float) -> void:
	var time_until_departure := (1.0 - cycle_position) * cycle_time
	if time_until_departure <= 2.0:
		if not _is_flashing:
			_is_flashing = true
			_start_flash()
	else:
		_is_flashing = false
		_visual.modulate = Color.WHITE

func _start_flash() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_visual, "modulate", Color.YELLOW, 0.2)
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.2)

func board_player(player: Node2D) -> void:
	if not player:
		return
	player_aboard = true
	# Award wBTC at cart destination based on pool
	GoldMineSystem.award_wbtc(wbtc_reward, pool_name)
	AudioManager.play_sfx("powerup")

func unboard_player() -> void:
	player_aboard = false
