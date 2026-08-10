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
	# THE "RANDOM ORANGE RECTANGLES" WERE THESE.
	#
	# Founder, about the same object in two different screenshots:
	#   "Ive told you many times to remove these random orange rectangles that
	#    have no function!!!"
	#   "This bitcoin symbol is still not clear!"
	#
	# This pickup drew itself as a bare 30x15 ColorRect in Bitcoin orange with
	# no symbol on it whatsoever. At game scale that is an orange smear with no
	# meaning attached, which is exactly why he read the same object as both
	# functionless clutter AND an unreadable Bitcoin — it was both. It is now a
	# struck gold-rimmed coin carrying a bold B, at the same 40px footprint the
	# other protocol tokens use.
	var coin := Sprite2D.new()
	coin.texture = preload("res://src/assets/sprites/sprite_item_wbtc.png")
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(coin)

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
