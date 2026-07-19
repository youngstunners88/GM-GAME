extends Area2D
## Climbable ladder (task #23, Movie Layer). Area2D detection per Godot 4.3
## best practice: overlapping the zone lets the player enter the CLIMB state
## (up/down movement, no gravity), jump off mid-climb, or slide off the ends.
## Placement intent (LEVEL_DEPTH.md): escape routes out of high-death pockets,
## sourced from the player_analytics heatmap.

@export var height: float = 128.0

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var rungs: Node2D = $Rungs

func _ready() -> void:
	add_to_group("ladder")
	collision_layer = 0
	collision_mask = 2  # player layer
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, height)
	shape.shape = rect
	shape.position = Vector2(0, height / 2.0)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_draw_rungs()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_ladder_zone"):
		body.enter_ladder_zone()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("exit_ladder_zone"):
		body.exit_ladder_zone()

## Procedural rungs (vine-wrapped pole look, Smoke Realm palette) — keeps the
## ladder readable without a dedicated sprite sheet yet.
func _draw_rungs() -> void:
	var rail_l := ColorRect.new()
	rail_l.size = Vector2(4, height)
	rail_l.position = Vector2(-12, 0)
	rail_l.color = Color(0.35, 0.5, 0.32, 0.95)
	rungs.add_child(rail_l)
	var rail_r := rail_l.duplicate()
	rail_r.position = Vector2(8, 0)
	rungs.add_child(rail_r)
	var count: int = int(height / 20.0)
	for i in range(count):
		var rung := ColorRect.new()
		rung.size = Vector2(24, 3)
		rung.position = Vector2(-12, 8 + i * 20.0)
		rung.color = Color(0.55, 0.68, 0.45, 0.95)
		rungs.add_child(rung)
