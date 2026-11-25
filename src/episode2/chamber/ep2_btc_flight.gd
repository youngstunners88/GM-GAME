class_name Ep2BtcFlight
extends Control
## A confirmed reward flies from the target to the HUD control that shows the BTC.

const COIN := preload("res://src/assets/sprites/sprite_item_coin-btc.png")
const FLY_TIME := 0.85
const SETTLE_TIME := 0.42
const GOLD := Color("ffd283")

var destination: Control
var destination_anchor := Vector2(0.5, 0.5)
var hidden_destination_label: String = ""
var _flights: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	set_process(false)


func launch(camera: Camera3D, world_position: Vector3, amount: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var start: Vector2 = viewport_size * Vector2(0.5, 0.44)
	if is_instance_valid(camera) and not camera.is_position_behind(world_position):
		start = camera.unproject_position(world_position)
	var margin := Vector2(60.0, 56.0)
	start = start.clamp(margin, (viewport_size - margin).max(margin))
	_flights.append({"origin": start / viewport_size, "amount": "+%s BTC" % str(amount), "age": 0.0})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for i in range(_flights.size() - 1, -1, -1):
		var flight: Dictionary = _flights[i]
		flight["age"] = float(flight["age"]) + delta
		if float(flight["age"]) >= FLY_TIME + SETTLE_TIME:
			_flights.remove_at(i)
	set_process(not _flights.is_empty())
	queue_redraw()


func _draw() -> void:
	if _flights.is_empty() or not is_instance_valid(destination):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_rect: Rect2 = destination.get_global_rect()
	var target: Vector2 = target_rect.position + target_rect.size * destination_anchor
	var scale_factor: float = clampf(minf(viewport_size.x, viewport_size.y) / 720.0, 0.75, 1.3)
	var font: Font = ThemeDB.fallback_font
	if not destination.is_visible_in_tree() and hidden_destination_label != "":
		var badge := Rect2(target - Vector2(36.0, 14.0) * scale_factor, Vector2(72.0, 28.0) * scale_factor)
		draw_rect(badge, Color(0.17, 0.1, 0.06, 0.9))
		draw_rect(badge, GOLD, false, 1.0)
		draw_string(font, badge.position + Vector2(0.0, 19.0) * scale_factor, hidden_destination_label,
			HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, roundi(14.0 * scale_factor), GOLD)
	for flight in _flights:
		var age: float = flight["age"]
		var origin: Vector2 = flight["origin"] * viewport_size
		var arc_height: float = minf(95.0 * scale_factor, origin.y - 24.0)
		var progress: float = clampf(age / FLY_TIME, 0.0, 1.0)
		var at: Vector2 = origin.lerp(target, smoothstep(0.0, 1.0, progress))
		at.y -= sin(progress * PI) * arc_height
		if progress < 1.0:
			var coin_size: float = lerpf(35.0, 18.0, progress) * scale_factor
			draw_circle(at, coin_size * 0.62, Color(1.0, 0.66, 0.23, 0.28), true, -1.0, true)
			draw_texture_rect(COIN, Rect2(at - Vector2.ONE * coin_size * 0.5, Vector2.ONE * coin_size), false)
		else:
			var settle: float = (age - FLY_TIME) / SETTLE_TIME
			draw_arc(target, lerpf(15.0, 39.0, settle) * scale_factor, 0.0, TAU, 36,
				Color(GOLD, 1.0 - settle), 2.5, true)
		var label: String = flight["amount"]
		var font_size: int = roundi(22.0 * scale_factor)
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var label_at := Vector2(clampf(at.x - width * 0.5, 8.0, viewport_size.x - width - 8.0),
			maxf(at.y - 24.0 * scale_factor, float(font_size) + 6.0))
		var ink := Color(GOLD, 1.0 - smoothstep(FLY_TIME + 0.15, FLY_TIME + SETTLE_TIME, age))
		draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.0, 0.0, 0.0, ink.a))
		draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
