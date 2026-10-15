class_name StableHorses
extends Node2D
## Horse stable + paddock on the ride into town (Level 3, world x ~3050: past
## the Fort Knox door, before the Gold Rush Reserve — close enough to town to
## belong to it, far enough to be its own spread). World-space cluster on a
## back berm (z_index -8, hazed): Blender-rendered barn + corral sprite, three
## Blender-rigged horses on SpriteFrames loops — one grazing, one standing,
## one walking the paddock rail. Pure scenery: no collision, no pickups.

const STABLE_TEXTURE := "res://src/assets/sprites/sprite_prop_stable.png"
const FRAME_DIR := "res://src/assets/sprites/horse_%s_%02d.png"
const STAND_FRAME := "res://src/assets/sprites/horse_stand.png"

var _walker: AnimatedSprite2D
var _walker_from: float = -160.0
var _walker_to: float = 170.0
var _walker_dir: float = 1.0
var _walker_speed: float = 26.0


func _ready() -> void:
	z_index = -8
	_build_barn()
	_build_grass()
	_add_horse("Grazer", Vector2(-120, 0), "graze", 5.0, false, Color(1.0, 1.0, 1.0))
	_add_horse("Sentry", Vector2(90, -2), "stand", 1.0, true, Color(0.45, 0.38, 0.42))
	var roamer := _add_horse("Roamer", Vector2(0, 2), "walk", 10.0, false, Color(0.72, 0.62, 0.66))
	_walker = roamer
	_walker.position.x = _walker_from


func _process(delta: float) -> void:
	if not is_instance_valid(_walker):
		return
	_walker.position.x += _walker_dir * _walker_speed * delta
	if _walker.position.x > _walker_to:
		_walker_dir = -1.0
		_walker.flip_h = true
	elif _walker.position.x < _walker_from:
		_walker_dir = 1.0
		_walker.flip_h = false


func _build_barn() -> void:
	var barn := Sprite2D.new()
	barn.name = "Stable"
	barn.texture = load(STABLE_TEXTURE)
	barn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var size: Vector2 = barn.texture.get_size()
	barn.scale = Vector2.ONE * (760.0 / size.x)
	barn.position = Vector2(10, -160)
	barn.modulate = Color(0.86, 0.82, 0.88, 1.0)
	add_child(barn)


func _add_horse(horse_name: String, pos: Vector2, anim: String, fps: float, flip: bool, tint: Color) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 10.0)
	frames.set_animation_loop("walk", true)
	for i in range(8):
		frames.add_frame("walk", load(FRAME_DIR % ["walk", i]))
	frames.add_animation("graze")
	frames.set_animation_speed("graze", 5.0)
	frames.set_animation_loop("graze", true)
	for i in range(6):
		frames.add_frame("graze", load(FRAME_DIR % ["graze", i]))
	frames.add_animation("stand")
	frames.set_animation_speed("stand", 1.0)
	frames.set_animation_loop("stand", true)
	frames.add_frame("stand", load(STAND_FRAME))
	var h := AnimatedSprite2D.new()
	h.name = horse_name
	h.frames = frames
	h.animation = anim
	h.flip_h = flip
	# Frames are 340x320 feet-planted canvases; scale to ~185px tall and sit
	# the canvas bottom on the berm so hooves never float or sink.
	h.scale = Vector2.ONE * 0.58
	h.position = pos + Vector2(0, -93)
	h.modulate = tint
	h.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(h)
	h.play()
	return h


func _build_grass() -> void:
	# Desert bunch-grass at the berm line: grounds the hooves and sells the
	# grazer's cropping. Deterministic pseudo-random so the layout is stable.
	var grass := Color(0.35, 0.42, 0.18, 1.0)
	var dry := Color(0.55, 0.48, 0.25, 1.0)
	for i in range(26):
		var gx: float = -260.0 + fmod(float(i) * 173.3, 560.0)
		var gy: float = -6.0 + fmod(float(i) * 41.7, 14.0)
		var tuft := Polygon2D.new()
		var tall: float = 7.0 + fmod(float(i) * 13.1, 7.0)
		tuft.polygon = PackedVector2Array([
			Vector2(gx - 5, gy), Vector2(gx - 2, gy - tall),
			Vector2(gx, gy), Vector2(gx + 2, gy - tall - 2.0), Vector2(gx + 5, gy),
		])
		tuft.color = grass if i % 3 else dry
		add_child(tuft)
