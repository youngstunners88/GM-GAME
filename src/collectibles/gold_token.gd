extends Area2D
## GOLD token collectible — represents a fully-vested 100-day miner from the whitepaper.
## Mines 1 GOLD to GoldMineSystem when picked up; awards score via GameManager.

@export var gold_amount: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _setup_visual() -> void:
	var nugget := Sprite2D.new()
	nugget.texture = load("res://src/assets/sprites/sprite_item_gold-nugget.png")
	add_child(nugget)

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
		# Pickaxe tool doubles mining yield — the miner's edge.
		var mult: int = 2 if GameManager.has_power_up("pickaxe") else 1
		GoldMineSystem.mine_gold(gold_amount * mult)
		ComboSystem.add_score(25 * gold_amount * mult)
		AudioManager.play_sfx("coin")
		queue_free()
