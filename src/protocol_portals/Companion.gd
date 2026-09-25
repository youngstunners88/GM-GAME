extends Node2D
## Tour companion: the founder leader still as a Sprite2D standing on the
## floor, trailing the player's x, facing him, bobbing while walking, with a
## name label and a talk balloon. Stage 2 adds two small tinted escorts of the
## same still so it reads as the Assay Trio. No Polygon2D figure.

const DISPLAY_H: float = 110.0
const FOLLOW_OFFSET: float = 90.0
const FOLLOW_RATE: float = 4.0
const ESCORT_SCALE: float = 0.7
const PLAYER_HALF: float = 16.0
const BALLOON_W: float = 320.0
const BALLOON_H: float = 64.0

var target: Node2D = null
var display_name: String = ""
var texture_path: String = ""
var trio: bool = false
var glow: Color = Color(0.35, 1.0, 0.45)
var min_x: float = 40.0
var max_x: float = 100000.0

var _sprite: Sprite2D = null
var _sprite_base_y: float = 0.0
var _escorts: Array[Sprite2D] = []
var _escort_base_y: float = 0.0
var _name_label: Label = null
var _balloon: Panel = null
var _balloon_label: Label = null
var _balloon_left: float = 0.0
var _bob_t: float = 0.0
var _bob: float = 0.0
var _side: float = 1.0
var _last_tx: float = 0.0
var _has_last: bool = false


func setup(path: String, name_text: String, color: Color, is_trio: bool) -> void:
	texture_path = path
	display_name = name_text
	glow = color
	trio = is_trio


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()


func _build() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(texture_path):
		tex = load(texture_path) as Texture2D
	else:
		push_warning("Companion: leader still missing: %s" % texture_path)
	var s: float = 0.2
	if tex != null and tex.get_height() > 0:
		s = DISPLAY_H / float(tex.get_height())

	_build_shadow()

	if trio and tex != null:
		var tints: Array[Color] = [Color(0.55, 0.95, 1.0), Color(0.8, 0.62, 1.0)]
		var xs: Array[float] = [-40.0, 40.0]
		_escort_base_y = -DISPLAY_H * ESCORT_SCALE * 0.5
		for i in range(2):
			var e := Sprite2D.new()
			e.name = "Escort%d" % (i + 1)
			e.texture = tex
			e.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			e.scale = Vector2(s * ESCORT_SCALE, s * ESCORT_SCALE)
			e.position = Vector2(xs[i], _escort_base_y)
			e.modulate = tints[i]
			e.z_index = -1
			add_child(e)
			_escorts.append(e)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2(s, s)
	_sprite_base_y = -DISPLAY_H * 0.5
	_sprite.position = Vector2(0.0, _sprite_base_y)
	add_child(_sprite)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = display_name
	_name_label.size = Vector2(240.0, 30.0)
	_name_label.position = Vector2(-120.0, -DISPLAY_H - 38.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", glow)
	_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_name_label.add_theme_constant_override("outline_size", 6)
	_name_label.add_theme_stylebox_override("normal", _dark_style(0.75, 8))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_balloon = Panel.new()
	_balloon.name = "TalkBalloon"
	_balloon.size = Vector2(BALLOON_W, BALLOON_H)
	_balloon.position = Vector2(-BALLOON_W * 0.5, -DISPLAY_H - 48.0 - BALLOON_H)
	_balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = _dark_style(0.9, 12)
	sb.border_color = Color(glow.r, glow.g, glow.b, 0.9)
	sb.set_border_width_all(2)
	_balloon.add_theme_stylebox_override("panel", sb)
	_balloon.z_index = 60
	_balloon.visible = false
	add_child(_balloon)

	_balloon_label = Label.new()
	_balloon_label.name = "BalloonText"
	_balloon_label.position = Vector2(10.0, 6.0)
	_balloon_label.size = Vector2(BALLOON_W - 20.0, BALLOON_H - 12.0)
	_balloon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_balloon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balloon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balloon_label.add_theme_font_size_override("font_size", 16)
	_balloon_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.97))
	_balloon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balloon.add_child(_balloon_label)


func _build_shadow() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.5))
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = tex
	shadow.scale = Vector2(2.2 if trio else 1.4, 0.3)
	shadow.z_index = -2
	add_child(shadow)


func _dark_style(alpha: float, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, alpha)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(6.0)
	return sb


## Show a line in the talk balloon for `seconds`.
func say(text: String, seconds: float = 5.5) -> void:
	if _balloon == null or text.is_empty():
		return
	_balloon_label.text = text
	_balloon.visible = true
	_balloon_left = seconds


func is_talking() -> bool:
	return _balloon != null and _balloon.visible


func _process(delta: float) -> void:
	var moving: bool = false
	if target != null and is_instance_valid(target):
		var tx: float = target.global_position.x + PLAYER_HALF
		if _has_last:
			var dx: float = tx - _last_tx
			if dx > 1.5:
				_side = -1.0
			elif dx < -1.5:
				_side = 1.0
		_last_tx = tx
		_has_last = true
		var desired: float = clampf(tx + _side * FOLLOW_OFFSET, min_x, max_x)
		var before: float = position.x
		position.x = lerpf(position.x, desired, 1.0 - exp(-FOLLOW_RATE * delta))
		var speed: float = absf(position.x - before) / maxf(delta, 0.0001)
		moving = speed > 12.0
		if absf(tx - position.x) > 4.0 and _sprite != null:
			var face_left: bool = tx < position.x
			_sprite.flip_h = face_left
			for e in _escorts:
				e.flip_h = face_left

	if moving:
		_bob_t += delta * 10.0
		_bob = -absf(sin(_bob_t)) * 3.0
	else:
		_bob = lerpf(_bob, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	if _sprite != null:
		_sprite.position.y = _sprite_base_y + _bob
	for i in range(_escorts.size()):
		var phase: float = -absf(sin(_bob_t + 1.3 * float(i + 1))) * 2.0 if moving else 0.0
		_escorts[i].position.y = _escort_base_y + phase

	if _balloon != null and _balloon.visible:
		_balloon_left -= delta
		if _balloon_left <= 0.0:
			_balloon.visible = false
