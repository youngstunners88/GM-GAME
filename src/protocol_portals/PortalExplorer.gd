class_name PortalExplorer
extends CharacterBody2D
## Dedicated four-direction explorer for the protocol maps. The campaign
## player remains a platformer; portal rooms deliberately play like a compact
## top-down RPG zone.

const SPEED: float = 235.0
const ART_PATH: String = "res://src/assets/sprites/sprite_lil-blunt_cowboy.png"

var _climbing: bool = false
var _in_ladder: bool = false
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("player")
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite != null and ResourceLoader.exists(ART_PATH):
		_sprite.texture = load(ART_PATH) as Texture2D
		if _sprite.texture != null and _sprite.texture.get_height() > 0:
			var bounds := _sprite.texture.get_image().get_used_rect()
			_sprite.region_enabled = true
			_sprite.region_rect = bounds
			var scale_to: float = 68.0 / float(bounds.size.y)
			_sprite.scale = Vector2(scale_to, scale_to)
			_sprite.position.y = -34.0
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		velocity = Vector2.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * SPEED
	_climbing = _in_ladder and input.y < -0.1
	if _sprite != null and absf(input.x) > 0.05:
		_sprite.flip_h = input.x < 0.0
	move_and_slide()
	if get_parent().has_method("constrain_to_ground"):
		position = get_parent().constrain_to_ground(position)
	z_index = int(position.y)


func enter_ladder_zone(_ladder: Node2D) -> void:
	_in_ladder = true


func exit_ladder_zone(_ladder: Node2D) -> void:
	_in_ladder = false
	_climbing = false


func _draw() -> void:
	if _sprite != null and _sprite.texture != null:
		return
	# Safe fallback for asset-light test checkouts.
	draw_circle(Vector2.ZERO, 18.0, Color(0.32, 0.95, 0.42))
	draw_rect(Rect2(-13.0, -5.0, 26.0, 32.0), Color(0.09, 0.16, 0.11))
	draw_circle(Vector2(0.0, -20.0), 13.0, Color(0.72, 0.48, 0.31))

