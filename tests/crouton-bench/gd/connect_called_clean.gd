extends Node

@onready var button: Button = $Button

func _ready() -> void:
	button.pressed.connect(_on_pressed)

func _on_pressed() -> void:
	print("pressed")
