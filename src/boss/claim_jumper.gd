extends BossBase

enum State { PATROL, THROW, VULNERABLE }

@export var patrol_speed: float = 100.0
@export var throw_cooldown: float = 1.5

var current_state: State = State.PATROL
var throw_timer: float = 0.0
var direction: float = 1.0

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	max_health = 6
	phase_thresholds = [4, 2]
	add_to_group("enemy")
	sprite.color = Color(0.6, 0.4, 0.2, 1.0)
	sprite.size = Vector2(80, 80)
	collision.position = Vector2(40, 40)
	hitbox.position = Vector2(40, 40)
	hitbox_shape.shape = collision.shape
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_setup_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	throw_timer -= delta

	match current_state:
		State.PATROL:
			velocity.x = patrol_speed * direction
			velocity.y += 980.0 * delta
			move_and_slide()
			if is_on_wall():
				direction *= -1.0
				sprite.scale.x = 1.0 if direction > 0 else -1.0
			if throw_timer <= 0:
				_throw_dynamite()

		State.THROW:
			velocity.x = move_toward(velocity.x, 0.0, 100.0)
			velocity.y += 980.0 * delta
			move_and_slide()

		State.VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 150.0)
			velocity.y += 980.0 * delta
			move_and_slide()
			sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(throw_timer, 0.2) < 0.1 else Color(1.0, 0.1, 0.1, 1.0)

## Accelerate patrol on phase transition.
func _on_phase_changed() -> void:
	if current_phase >= 2:
		patrol_speed = 150.0

func _throw_dynamite() -> void:
	throw_timer = throw_cooldown
	var dyn := preload("res://src/boss/dynamite.tscn").instantiate()
	dyn.position = global_position + Vector2(0, -50)
	get_parent().add_child(dyn)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	_update_health_bar()
	if health <= 0:
		die()
	else:
		_check_phase_change()

func die() -> void:
	is_dead = true
	set_physics_process(false)
	GameManager.add_score(750)
	ScreenShake.shake(0.6, 10.0)
	hitbox.monitorable = false
	hitbox.monitoring = false
	StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)
	# Gold Rush Auction settlement — whitepaper specifies pro-rata XAUT payout
	# at week end. Player contributes their GOLD pool, settles vs. enemy reserve.
	var player_contribution := GoldMineSystem.gold_balance + GoldMineSystem.auction_gold_pool
	var enemy_reserve := 50  # Strategic Reserve baseline contribution
	var total_pool := player_contribution + enemy_reserve
	GoldMineSystem.forfeit_to_auction(GoldMineSystem.gold_balance)
	var xaut_won := GoldMineSystem.settle_auction(player_contribution, total_pool)
	# Treasury revenue distribution from boss "operations" — 50/20/20/10 split
	var treasury_payout := 100
	GoldMineSystem.distribute_treasury_revenue(treasury_payout)
	GameManager.save_session()
	if Web3Manager.is_connected:
		Web3Manager.submit_score(GameManager.total_score)
	if health_bar:
		health_bar.queue_free()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
	tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	var victory := Label.new()
	victory.text = "GOLD RUSH WON!\nXAUT payout: %d\nFort Knox shares: %d" % [xaut_won, GoldMineSystem.fort_knox_shares]
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.position = global_position - Vector2(150, 75)
	victory.add_theme_font_size_override("font_size", 28)
	get_tree().current_scene.add_child(victory)
	await get_tree().create_timer(3.5).timeout
	SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.FADE)
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		take_damage(1)
