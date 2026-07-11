extends Area2D
## GOLD token collectible — represents a fully-vested 100-day miner from the whitepaper.
## Mines 1 GOLD to GoldMineSystem when picked up; awards score via GameManager.

@export var gold_amount: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _setup_visual() -> void:
	# Bright gold nugget — round, slightly off-square to suggest natural mineral form.
	var nugget := ColorRect.new()
	nugget.color = Color(1.0, 0.84, 0.0, 1.0)
	nugget.size = Vector2(20, 18)
	nugget.position = Vector2(-10, -9)
	add_child(nugget)

	# Inner highlight to suggest polish/3D
	var highlight := ColorRect.new()
	highlight.color = Color(1.0, 0.95, 0.5, 0.8)
	highlight.size = Vector2(8, 4)
	highlight.position = Vector2(-6, -7)
	add_child(highlight)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12
	col.shape = shape
	add_child(col)

	# Subtle bob — evokes "drifting gold ore" feel
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 6, 0.8)
	tween.tween_property(self, "position:y", position.y, 0.8)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Stop monitoring first — queue_free only lands at end of frame, and a
		# physics hitch can fire body_entered twice (double-award exploit).
		set_deferred("monitoring", false)
		GoldMineSystem.mine_gold(gold_amount)
		ComboSystem.add_score(25 * gold_amount)
		AudioManager.play_sfx("coin")
		queue_free()
