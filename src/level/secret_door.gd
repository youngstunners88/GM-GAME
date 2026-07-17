extends Area2D
## A hidden doorway. Walk into it and Lil Blunt is whisked to the Chill Lounge
## secret realm — with announcer commentary so the transition reads clearly.
## Before leaving it records where to come back to (this scene + this door's
## position), so the return portal drops the player right back here.
## Subtly telegraphed with a soft glowing pulse so it's discoverable, not invisible.

const REALM := "res://src/level/secret_realm.tscn"
var _used := false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("secret_door")
	body_entered.connect(_on_body_entered)
	# Gentle pulse — a "there's something here" cue without spelling it out.
	if sprite:
		var tw := create_tween().set_loops()
		tw.tween_property(sprite, "modulate", Color(1.2, 1.1, 1.4, 1.0), 1.2)
		tw.tween_property(sprite, "modulate", Color(0.7, 0.7, 0.9, 1.0), 1.2)

func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	GameManager.secret_return = {
		"scene_path": get_tree().current_scene.scene_file_path,
		"position": global_position,
	}
	AudioManager.play_voice("secret_enter")
	AudioManager.play_sfx("powerup")
	ScreenShake.shake(0.2, 4.0)
	SceneRouter.load_scene(REALM, SceneRouter.Transition.SMOKE)
