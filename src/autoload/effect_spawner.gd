extends Node
## Central juice dispatcher: one-shot particle bursts and floating combat text,
## spawnable from anywhere without the call site managing scenes or lifetime.

var _scenes: Dictionary = {
	"coin_sparkle": preload("res://src/effects/coin_sparkle.tscn"),
	"explosion": preload("res://src/effects/explosion.tscn"),
	"dash_trail": preload("res://src/effects/dash_trail.tscn"),
	"confetti": preload("res://src/effects/level_complete_confetti.tscn"),
}

## Spawn a one-shot particle burst at a world position. Unknown names no-op
## (with a warning) so a typo can never crash a collect/death path.
func burst(effect: String, pos: Vector2) -> void:
	var scene: PackedScene = _scenes.get(effect)
	if scene == null:
		push_warning("EffectSpawner: unknown effect '%s'" % effect)
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var fx := scene.instantiate()
	fx.global_position = pos
	root.add_child(fx)

## Floating combat text (damage numbers / pickups): rises ~34px and fades out
## over 0.8s. White = normal, gold = bonus/critical, red = player damage.
func float_text(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 90
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.position = pos + Vector2(-12, -28)
	root.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)
