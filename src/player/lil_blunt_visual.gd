class_name LilBluntVisual
extends Node2D
## Lil Blunt rendered from the client's real pixel-art sprites
## (src/assets/sprites/sprite_lil-blunt_*.png), replacing the old
## procedurally-drawn placeholder. Keeps the same API the rest of the
## code already uses:
##   color        — power-up tint (WHITE = normal art colors)
##   facing_right — mirrors the sprite toward travel direction
##   visible      — damage flicker (inherited)
##   set_outfit() — swaps cowboy / miner / crystal art per level theme

const OUTFIT_TEXTURES := {
	Player.Outfit.DEFAULT: "res://src/assets/sprites/sprite_lil-blunt_cowboy.png",
	Player.Outfit.MINER: "res://src/assets/sprites/sprite_lil-blunt_miner.png",
	Player.Outfit.CRYSTAL: "res://src/assets/sprites/sprite_lil-blunt_crystal.png",
}
## Collision box is 32×32 centred on this node; its floor line is +16 below.
const FEET_LOCAL_Y: float = 16.0

var _spr: Sprite2D

## Power-up tint applied over the art (cyan/green/red glows). WHITE = normal.
var color: Color = Color.WHITE:
	set(value):
		color = value
		if _spr:
			_spr.self_modulate = value

var facing_right: bool = true:
	set(value):
		facing_right = value
		if _spr:
			_spr.flip_h = not value
		if _tool:
			_tool.flip_h = not value
			_tool.position.x = TOOL_HAND_X if value else -TOOL_HAND_X

## Ground-movement flag driven by the player each physics frame; while true
## the sprite gets a light run-bob (rotation + hop) so walking reads as
## animation even with single-pose art.
var moving: bool = false

## Held tool (pickaxe/torch power-ups). Offset from node centre to the hand.
const TOOL_HAND_X: float = 14.0
var _tool: Sprite2D
var _tool_path: String = ""
var _bob_time: float = 0.0

func _ready() -> void:
	_spr = Sprite2D.new()
	add_child(_spr)
	set_outfit(Player.Outfit.DEFAULT)

func _process(delta: float) -> void:
	if moving:
		_bob_time += delta
		_spr.rotation = sin(_bob_time * 14.0) * 0.07
		_spr.position.y = FEET_LOCAL_Y - _spr.texture.get_height() / 2.0 - absf(sin(_bob_time * 14.0)) * 3.0
	elif _bob_time != 0.0:
		_bob_time = 0.0
		_spr.rotation = 0.0
		_spr.position.y = FEET_LOCAL_Y - _spr.texture.get_height() / 2.0

## Show/hide the held tool. Pass "" to clear. Path is cached so calling
## every frame is free.
func set_tool(path: String) -> void:
	if path == _tool_path:
		return
	_tool_path = path
	if path == "":
		if _tool:
			_tool.queue_free()
			_tool = null
		return
	if _tool == null:
		_tool = Sprite2D.new()
		_tool.position = Vector2(TOOL_HAND_X if facing_right else -TOOL_HAND_X, 2.0)
		_tool.rotation = 0.35
		add_child(_tool)
	_tool.texture = load(path)
	_tool.flip_h = not facing_right

## Swap outfit art (cowboy for Forest/Gold Rush, miner/crystal for Caves).
func set_outfit(outfit: int) -> void:
	if _spr == null:
		return
	var path: String = OUTFIT_TEXTURES.get(outfit, OUTFIT_TEXTURES[Player.Outfit.DEFAULT])
	_spr.texture = load(path)
	# Anchor feet to the collision floor so he stands ON platforms.
	_spr.position = Vector2(0.0, FEET_LOCAL_Y - _spr.texture.get_height() / 2.0)
	_spr.flip_h = not facing_right
	_spr.self_modulate = color
