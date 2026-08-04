class_name BossSprite
extends Node2D
## Textured stand-in for the old ColorRect boss visuals. Renders client key-art
## sprites while honoring the ColorRect-ish API the boss scripts already use:
##   sprite.color    — red-flash writes tint the art; base-color writes restore white
##   sprite.size     — desired on-screen box; texture is fitted to its height
##   sprite.modulate — native Node2D property (damage flicker uses it directly)
##   set_facing(bool) — mirror the art in place (NEVER write scale.x;
##                    see the long comment on set_facing for why that breaks)

@export var texture_path: String = ""

var _spr: Sprite2D

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

## Face the boss left or right WITHOUT displacing the artwork.
##
## THE BUG THIS EXISTS TO KILL (founder-reported as "the boss falls off his
## Diamond surfboard", and a contributor to "the Auditor has his back to Lil
## Blunt"): every boss script used to write `sprite.scale.x = -1` directly to
## face left. `_fit()` above anchors the inner Sprite2D at `size / 2` — i.e.
## local (48, 48) for a 96px body box — so negating the PARENT Node2D's
## x-scale mirrors that OFFSET as well as the pixels. The art jumps a full
## 96 local px sideways: 163 world px at the Distributor's BOSS_SCALE of 1.7,
## 125 px at the Auditor's 1.3.
##
## The Distributor's levitating diamond is a SIBLING Polygon2D that is not
## inside this node and therefore does not move — so the moment he turned to
## face left his body slid clean off the disc. Exactly the screenshot.
##
## Worse, each previous "facing fix" added MORE scale.x writes (PATROL, ALERT,
## PURSUE, then VULNERABLE), so every attempt to fix the facing made the
## displacement fire more often rather than less.
##
## Mirroring `flip_h` on the inner Sprite2D flips the pixels around the
## sprite's own centre and leaves its position — and therefore the body's
## alignment with the disc, the hitbox and the collision box — untouched.
func set_facing(face_right: bool) -> void:
	if _spr:
		_spr.flip_h = not face_right
