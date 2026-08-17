class_name MineCart
extends AnimatableBody2D
## Two-pool mine cart system — represents Fort Knox short (day 88) vs long (day 288) pool choice.
## Fast cart: 150 speed, 5s departure, 10 wBTC reward (day 88 short pool — 60%).
## Slow cart: 80 speed, 12s departure, 50 wBTC reward (day 288 long pool — 40%).
## Player can only take one cart per fork; choice matters for Fort Knox strategy.
##
## FOUNDER, about this object (two separate complaints on the same bug):
##   "Whatever these 2 floating boxers are they need to better defined..."
##   "You still havent addressed this random box that loads something...
##    It's very unclear as it has no impact on Lil Blunt or the game points!!!"
## It was a bare untextured ColorRect (no boarding trigger ever called
## board_player/unboard_player — zero call sites anywhere in the codebase, so
## walking into it genuinely did nothing). Now a real wooden/gold-armor cart
## sprite with an Area2D boarding trigger that grants wBTC with visible
## floating-text + sparkle + HUD feedback the moment the player reaches it.

enum CartType { FAST, SLOW }

const FAST_TEXTURE := "res://src/assets/sprites/sprite_prop_minecart-fast.png"
const SLOW_TEXTURE := "res://src/assets/sprites/sprite_prop_minecart-slow.png"
const FAST_RENDER_WIDTH := 84.0
const SLOW_RENDER_WIDTH := 118.0

@export var cart_type: CartType = CartType.FAST
@export var move_distance: float = 200.0
@export var start_delay: float = 0.0

var speed: float = 150.0
var cycle_time: float = 5.0
var wbtc_reward: int = 10
var pool_name: String = "short"
var _time_elapsed: float = 0.0
var _visual: Sprite2D
var _visual_size: Vector2
var _is_flashing: bool = false
var player_aboard: bool = false
var _reward_on_cooldown: bool = false
## Real bug, found via a live Playwright playtest capture (founder directive
## PROMPT_VERIFY_PR41_HARD_REFRESH.md — "no FIXED without a capture frame").
## The old `_physics_process` wrote `position.x = cycle_position *
## move_distance` directly, which is LOCAL position relative to the level
## root — so on the very first physics tick every cart snapped from its
## authored track position (fast=150, slow=1070) to somewhere between 0 and
## move_distance, clustering both carts together right next to the level
## origin/HUD instead of shuttling along their own track segment. This is
## almost certainly why they read as "random" — they were LITERALLY in the
## wrong place, not just badly drawn. Captured before `_ready()` runs, so it
## reflects wherever EntitySpawner.spawn() actually placed this instance.
var _origin_x: float = 0.0

func _ready() -> void:
	_origin_x = position.x
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
	_setup_trigger()
	_time_elapsed = start_delay
	add_to_group("cart")
	add_to_group(pool_name + "_pool_cart")

func _setup_visual() -> void:
	# Cart visual: fast = small wooden ore cart, slow = armored gold cart.
	_visual = Sprite2D.new()
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var texture: Texture2D
	var render_width: float
	if cart_type == CartType.FAST:
		texture = load(FAST_TEXTURE)
		render_width = FAST_RENDER_WIDTH
	else:
		texture = load(SLOW_TEXTURE)
		render_width = SLOW_RENDER_WIDTH
	_visual.texture = texture
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = render_width / tex_size.x
	_visual.scale = Vector2(scale_factor, scale_factor)
	_visual_size = tex_size * scale_factor
	add_child(_visual)

	# Collision shape matches the rendered cart footprint.
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _visual_size
	col.shape = shape
	col.position = Vector2(0, 0)
	add_child(col)

	# Label: DAY 88 (Fast) or DAY 288 (Slow)
	var label_node := Node2D.new()
	label_node.name = "PoolLabel"
	var label_text := Label.new()
	if cart_type == CartType.FAST:
		label_text.text = "DAY 88\nFAST"
	else:
		label_text.text = "DAY 288\nSLOW"
	label_text.add_theme_font_size_override("font_size", 14)
	label_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label_text.add_theme_constant_override("outline_size", 4)
	label_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_text.position = Vector2(-label_text.get_combined_minimum_size().x / 2, -_visual_size.y / 2 - 34)
	label_node.add_child(label_text)
	add_child(label_node)

func _setup_trigger() -> void:
	# Boarding trigger: a real Area2D overlap, generous enough to catch a
	# walked-in player against a cart that is itself sliding back and forth.
	var trigger := Area2D.new()
	trigger.name = "BoardTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2  # Player layer only
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _visual_size + Vector2(20, 30)
	col.shape = shape
	trigger.add_child(col)
	add_child(trigger)
	trigger.body_entered.connect(_on_trigger_body_entered)
	trigger.body_exited.connect(_on_trigger_body_exited)

func _on_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		board_player(body)

func _on_trigger_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		unboard_player()

func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	var cycle_position := fmod(_time_elapsed, cycle_time) / cycle_time
	# Oscillate around the cart's OWN authored spawn point, not the level
	# origin — see _origin_x's doc comment for the bug this fixes.
	position.x = _origin_x + cycle_position * move_distance
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
	if _reward_on_cooldown:
		return
	_reward_on_cooldown = true
	# Award wBTC at cart destination based on pool — the HUD's wBTC stat is
	# already listening on GoldMineSystem.wbtc_changed, so this alone makes
	# the reward visible on-screen; float_text + sparkle sell the moment.
	GoldMineSystem.award_wbtc(wbtc_reward, pool_name)
	AudioManager.play_sfx("powerup")
	EffectSpawner.float_text(global_position + Vector2(0, -_visual_size.y / 2), "+%d wBTC" % wbtc_reward, Color(1.0, 0.72, 0.2, 1.0))
	EffectSpawner.burst("coin_sparkle", global_position)
	ScreenShake.light()
	var timer := get_tree().create_timer(cycle_time)
	timer.timeout.connect(func() -> void: _reward_on_cooldown = false)

func unboard_player() -> void:
	player_aboard = false
