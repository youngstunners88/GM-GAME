class_name BossSprite
extends Node2D
## Textured stand-in for the old ColorRect boss visuals. Renders client key-art
## sprites while honoring the ColorRect-ish API the boss scripts already use:
##   sprite.color    — red-flash writes tint the art; base-color writes restore white
##   sprite.size     — desired on-screen box; texture is fitted to its height
##   sprite.modulate — native Node2D property (damage flicker uses it directly)
##   sprite.set_facing(bool) — flip without displacement (use this, not scale.x)

@export var texture_path: String = ""

var _spr: Sprite2D

## Flip the inner sprite without displacing the art. Using scale.x = -1 on the
## parent mirrors the child's size/2 offset, teleporting the art sideways.
## This method flips flip_h in place — position stays pinned.
func set_facing(face_right: bool) -> void:
	if _spr:
		_spr.flip_h = not face_right

## Emulates ColorRect.size: fits the texture display height to size.y.
var size: Vector2 = Vector2(96, 96):
	set(value):
		size = value
		_fit()

## Emulates ColorRect.color. Bosses write saturated red for hit flashes and
## their own base color to restore — art keeps its painted colors, so any
## non-red write maps back to plain white.
var color: Color = Color.WHITE:
	set(value):
		color = value
		if _spr:
			var is_flash := value.r > 0.85 and value.g < 0.45 and value.b < 0.45
			_spr.self_modulate = Color(1.0, 0.25, 0.25, 1.0) if is_flash else Color.WHITE

func _ready() -> void:
	_spr = Sprite2D.new()
	if texture_path != "":
		_spr.texture = load(texture_path)
	add_child(_spr)
	_fit()

func _fit() -> void:
	if _spr == null or _spr.texture == null:
		return
	var th := float(_spr.texture.get_height())
	var s := size.y / th
	_spr.scale = Vector2(s, s)
	# ColorRect anchored its box at top-left; centre the art in that box.
	_spr.position = size / 2.0
