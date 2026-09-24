extends Area2D
## Interaction zone that fronts the whitepaper plate in a study room.
##
## Two ways in, both of which simply ask the room to open its whitepaper
## overlay:
##   * the player presses "interact" while standing inside the zone;
##   * the player lands on the zone from above (above the zone centre and moving
##     down), which is what happens if they ever come down onto the lectern.
## The script owns no session state: the room owns the session, the pause and
## the UI. `room` may be null (the zone is inspectable in isolation by tests).

## The StudyRoom that owns this zone. Set by StudyRoom right after the node is
## built.
var room: Node = null

var _player_inside: bool = false
var _has_interact: bool = false


func _ready() -> void:
	_has_interact = InputMap.has_action("interact")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	var falling: bool = true
	if body is CharacterBody2D:
		falling = (body as CharacterBody2D).velocity.y >= 0.0
	if body.global_position.y <= global_position.y and falling:
		_open()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not _has_interact:
		return
	if _room_busy():
		return
	if event.is_action_pressed("interact"):
		_open()


## True while the room has an overlay open (paused) — never stack a second one.
func _room_busy() -> bool:
	if room == null:
		return false
	if room.has_method("is_overlay_open"):
		return bool(room.call("is_overlay_open"))
	return false


func _open() -> void:
	if _room_busy():
		return
	if room != null and room.has_method("open_whitepaper"):
		room.call("open_whitepaper")
