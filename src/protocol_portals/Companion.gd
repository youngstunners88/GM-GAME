extends Node2D
## Tour guide: one figure per protocol. It walks after the player every physics
## frame, faces him, bobs while moving, and says stop lines in a talk balloon.

const NAMES: Dictionary = {
	"smoke": "Pauly The Smokest",
	"diamonds": "Kane The Blaze Mechanic",
	"gold": "Rich the Claim Recorder",
}
const TEXTURES: Dictionary = {
	"smoke": "res://src/assets/portals/companions/pauly_the_smokest.png",
	"diamonds": "res://src/assets/portals/companions/kane_the_blaze_mechanic.png",
	"gold": "res://src/assets/portals/companions/rich_the_claim_recorder.png",
}

const DISPLAY_H: float = 110.0
const FOLLOW_OFFSET: float = -90.0
const FOLLOW_RATE: float = 5.0
const PLAYER_HALF: float = 16.0
const BALLOON_W: float = 340.0
const BALLOON_H: float = 84.0
const TALK_SEC: float = 6.0

var target: Node2D = null
var display_name: String = ""
var texture_path: String = ""
## Kept for API compatibility; the guide is always a single figure.
var trio: bool = false
var protocol: String = "smoke"
var glow: Color = Color(0.35, 1.0, 0.45)
var min_x: float = 40.0
var max_x: float = 100000.0

var _visual: Node2D = null
var _name_label: Label = null
var _balloon: Panel = null
var _balloon_label: Label = null
var _voice: AudioStreamPlayer = null
var _balloon_left: float = 0.0
var _bob_t: float = 0.0
var _bob: float = 0.0
var _facing: float = 1.0
var _last_tx: float = 0.0
var _has_last: bool = false
var _trail: Array[Vector2] = []


static func name_for(protocol_id: String) -> String:
	return String(NAMES.get(protocol_id, NAMES["smoke"]))


static func texture_for(protocol_id: String) -> String:
	return String(TEXTURES.get(protocol_id, TEXTURES["smoke"]))


func setup(path: String, name_text: String, color: Color, _is_trio: bool) -> void:
	texture_path = path
	display_name = name_text
	glow = color
	trio = false


func setup_for(protocol_id: String, color: Color) -> void:
	protocol = protocol_id
	texture_path = texture_for(protocol_id)
	display_name = name_for(protocol_id)
	glow = color
	trio = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if display_name.is_empty():
		display_name = name_for(protocol)
	if texture_path.is_empty():
		texture_path = texture_for(protocol)
	_build()


func _build() -> void:
	_build_shadow()
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var tex: Texture2D = null
	if ResourceLoader.exists(texture_path):
		tex = load(texture_path) as Texture2D
	else:
		push_warning("Companion: texture missing: %s" % texture_path)
	if tex != null and tex.get_height() > 0:
		var s: float = DISPLAY_H / float(tex.get_height())
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2(s, s)
		sprite.position = Vector2(0.0, -DISPLAY_H * 0.5)
		_visual.add_child(sprite)
	else:
		_build_fallback_figure()

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = display_name
	_name_label.size = Vector2(260.0, 30.0)
	_name_label.position = Vector2(-130.0, -DISPLAY_H - 38.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", glow)
	_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_name_label.add_theme_constant_override("outline_size", 6)
	_name_label.add_theme_stylebox_override("normal", _dark_style(0.75, 8))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.visible = false
	add_child(_name_label)

	_balloon = Panel.new()
	_balloon.name = "TalkBalloon"
	_balloon.size = Vector2(640, 150)
	_balloon.position = Vector2(28, 540)
	_balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = _dark_style(0.9, 12)
	sb.border_color = Color(glow.r, glow.g, glow.b, 0.9)
	sb.set_border_width_all(2)
	_balloon.add_theme_stylebox_override("panel", sb)
	_balloon.z_index = 60
	_balloon.visible = false
	# Dialogue lives below the map view, not across the prop and its prompt.
	var dialogue := CanvasLayer.new()
	dialogue.name = "DialogueLayer"
	dialogue.layer = 10
	add_child(dialogue)
	dialogue.add_child(_balloon)

	_balloon_label = Label.new()
	_balloon_label.name = "BalloonText"
	_balloon_label.position = Vector2(10.0, 6.0)
	_balloon_label.size = Vector2(616, 138)
	_balloon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_balloon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_balloon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_balloon_label.add_theme_font_size_override("font_size", 15)
	_balloon_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.97))
	_balloon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balloon.add_child(_balloon_label)

	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	add_child(_voice)


## Simple code-drawn stand-in used only when the texture is missing.
func _build_fallback_figure() -> void:
	var body := Polygon2D.new()
	body.name = "FallbackBody"
	body.polygon = PackedVector2Array([
		Vector2(-20.0, 0.0), Vector2(20.0, 0.0), Vector2(16.0, -70.0), Vector2(-16.0, -70.0),
	])
	body.color = glow.darkened(0.45)
	_visual.add_child(body)
	var head := Polygon2D.new()
	head.name = "FallbackHead"
	var pts := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * 18.0, -90.0 + sin(a) * 18.0))
	head.polygon = pts
	head.color = Color(0.85, 0.72, 0.58)
	_visual.add_child(head)
	var eye := Polygon2D.new()
	eye.name = "FallbackEye"
	eye.polygon = PackedVector2Array([
		Vector2(6.0, -94.0), Vector2(11.0, -94.0), Vector2(11.0, -89.0), Vector2(6.0, -89.0),
	])
	eye.color = Color(0.05, 0.05, 0.05)
	_visual.add_child(eye)


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
	shadow.scale = Vector2(1.4, 0.3)
	shadow.z_index = -2
	add_child(shadow)


func _dark_style(alpha: float, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, alpha)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(6.0)
	return sb


## Show a line in the talk balloon for `seconds`.
func say(text: String, seconds: float = TALK_SEC) -> void:
	if _balloon == null or text.is_empty():
		return
	_balloon_label.text = display_name + "\n" + text
	_balloon.visible = true
	_balloon_left = seconds


## Plays an optional VO clip; silently does nothing if it does not exist.
func play_voice(path: String) -> void:
	if _voice == null or path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	_voice.stream = stream
	_voice.play()


func is_talking() -> bool:
	return _balloon != null and _balloon.visible


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Record only safe footsteps, using exactly the explorer's ground constraint.
	var room := get_parent()
	var footstep: Vector2 = target.position
	if room.has_method("constrain_to_ground"):
		footstep = room.constrain_to_ground(footstep)
	if _trail.is_empty() or _trail.back().distance_to(footstep) > 8.0:
		_trail.append(footstep)
	var length := position.distance_to(_trail[0])
	for i in range(1, _trail.size()):
		length += _trail[i - 1].distance_to(_trail[i])
	var before := position
	# Spend the whole movement budget across short trail segments. The previous
	# one-node-per-frame follower lost speed on turns and lagged behind forever.
	var budget := minf(maxf(length - 78.0, 0.0), (310.0 if length > 180.0 else 250.0) * delta)
	while budget > 0.01 and not _trail.is_empty():
		var next: Vector2 = _trail[0]
		var step := minf(budget, position.distance_to(next))
		position = position.move_toward(next, step)
		budget -= step
		if position.distance_to(next) < 0.5:
			_trail.pop_front()
		else:
			break
	if room.has_method("constrain_to_ground"):
		position = room.constrain_to_ground(position)
	z_index = int(position.y)
	if _visual != null:
		if absf(target.position.x - position.x) > 4.0:
			_visual.scale.x = -1.0 if target.position.x < position.x else 1.0
		if position.distance_to(before) > 0.3:
			_bob_t += delta * 10.0
			_bob = -absf(sin(_bob_t)) * 2.0
		else:
			_bob = lerpf(_bob, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_visual.position.y = _bob


func _process(delta: float) -> void:
	if _balloon != null and _balloon.visible:
		_balloon_left -= delta
		if _balloon_left <= 0.0:
			_balloon.visible = false
