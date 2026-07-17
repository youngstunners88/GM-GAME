extends Area2D
## The way home from a secret realm. Walk in → announcer sign-off → load the
## scene the player entered from (GameManager.secret_return.scene_path). That
## level's _spawn_player() reads secret_return and places the player back at the
## door, so the detour loops cleanly back to where it began. Falls back to the
## main menu if there's no return record (shouldn't happen in normal play).
var _used := false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if sprite:
		var tw := create_tween().set_loops()
		tw.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.7)
		tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.7)

func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	AudioManager.play_voice("secret_exit")
	AudioManager.play_sfx("powerup")
	var dest: String = GameManager.secret_return.get("scene_path", "")
	if dest == "":
		dest = "res://src/ui/main_menu.tscn"
		GameManager.secret_return = {}
	SceneRouter.load_scene(dest, SceneRouter.Transition.SMOKE)
