extends Area2D
## Interaction zone that fronts the video shrine in a study room.
##
## Press "interact" inside the zone and the room opens its video overlay (which
## shell-opens the official X post and gates the DONE button on a minimum watch
## time). Nothing is downloaded, embedded or proxied here.
## `room` may be null — the zone is inspectable in isolation by tests.

## The StudyRoom that owns this zone.
var room: Node = null

var _player_inside: bool = false
var _has_interact: bool = false


func _ready() -> void:
	_has_interact = InputMap.has_action("interact")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


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


func _room_busy() -> bool:
	if room == null:
		return false
	if room.has_method("is_overlay_open"):
		return bool(room.call("is_overlay_open"))
	return false


func _open() -> void:
	if _room_busy():
		return
	if room != null and room.has_method("open_video"):
		room.call("open_video")
