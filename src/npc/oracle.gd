extends Area2D
## The Smoke Oracle NPC — a placeable hub character. Stand near it and press
## Interact (E) to open the Oracle dialog (Mistral-backed). A floating glowing
## sprite with a "press E" hint on approach. Video-Game Layer: see oracle_panel.gd.

const PANEL := preload("res://src/ui/oracle_panel.tscn")
var _in_range := false
var _panel: CanvasLayer

@onready var sprite: Sprite2D = $Sprite
@onready var hint: Label = $Hint

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if hint:
		hint.visible = false
	if sprite:
		var tw := create_tween().set_loops()
		tw.tween_property(sprite, "position:y", sprite.position.y - 8.0, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sprite, "position:y", sprite.position.y, 1.2).set_trans(Tween.TRANS_SINE)

func _on_body_entered(b: Node2D) -> void:
	if b.is_in_group("player"):
		_set_range(true)

func _on_body_exited(b: Node2D) -> void:
	if b.is_in_group("player"):
		_set_range(false)

func _set_range(v: bool) -> void:
	_in_range = v
	if hint:
		hint.visible = v

func _unhandled_input(event: InputEvent) -> void:
	if _in_range and event.is_action_pressed("interact"):
		if _panel == null or not is_instance_valid(_panel):
			_panel = PANEL.instantiate()
			get_tree().current_scene.add_child(_panel)
		_panel.open()
