class_name PortalExplorer
extends CharacterBody2D
## Dedicated four-direction explorer for the protocol maps. The campaign
## player remains a platformer; portal rooms deliberately play like a compact
## top-down RPG zone.

const Layout := preload("res://src/protocol_portals/RoomLayout.gd")
const SPEED: float = 235.0
const ART_PATH: String = "res://src/assets/sprites/sprite_lil-blunt_cowboy.png"

var _climbing: bool = false
var _in_ladder: bool = false
var _sprite: Sprite2D = null
var _off_ground: float = 0.0
var _falling: bool = false
var _safe_pos: Vector2 = Vector2.ZERO


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
	var room := get_parent()
	if room.has_method("constrain_player"):
		position = room.constrain_player(position)
		_check_fall(room, _delta)
	elif room.has_method("constrain_to_ground"):
		position = room.constrain_to_ground(position)
	z_index = int(position.y)


## Off the ground (bridge / cliff lip) for more than a moment = a fall: lose a life and
## come back at the shaft. The advisor is kept on the ground and never falls.
func _check_fall(room: Node, delta: float) -> void:
	if _falling:
		return
	var proto: String = String(room.get("protocol"))
	if float(Layout.FALL_MARGIN.get(proto, 0.0)) <= 0.0:
		return
	if Layout.overhang(proto, position) > 4.0:
		_off_ground += delta
		if _off_ground > 0.28:
			_fall(room, proto)
	else:
		_off_ground = 0.0
		_safe_pos = position


func _fall(room: Node, proto: String) -> void:
	_falling = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", position.y + 160.0, 0.5).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	await t.finished
	# Mercy on the last life: a classroom never ends the run.
	if GameManager.lives > 1:
		GameManager.lose_life()
	position = Layout.constrain(proto, _safe_pos if _safe_pos != Vector2.ZERO else Layout.ENTRANCES[proto])
	modulate.a = 1.0
	_off_ground = 0.0
	_falling = false
	set_physics_process(true)


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

