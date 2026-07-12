extends Area2D
## wBTC collectible — represents Fort Knox staking reward from the whitepaper.
## 35% of BTC mining proceeds become wBTC in the Fort Knox pool;
## in-game pickups award wBTC to GoldMineSystem on the short-term (day 88, 60%) pool.

@export var wbtc_amount: int = 1
@export var pool: String = "short"  # "short" = day 88 pool, "long" = day 288 pool

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _setup_visual() -> void:
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.55, 0.0, 1.0)  # Bitcoin orange
	rect.size = Vector2(30, 15)
	rect.position = Vector2(-15, -7.5)
	add_child(rect)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15
	col.shape = shape
	add_child(col)

	# Bobbing animation
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 10, 0.8)
	tween.tween_property(self, "position:y", position.y, 0.8)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Stop monitoring first — queue_free only lands at end of frame, and a
		# physics hitch can fire body_entered twice (double-award exploit).
		set_deferred("monitoring", false)
		GoldMineSystem.award_wbtc(wbtc_amount, pool)
		AudioManager.play_sfx("powerup")
		queue_free()
