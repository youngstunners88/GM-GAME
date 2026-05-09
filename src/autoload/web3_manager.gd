extends Node

signal wallet_connected(address: String)
signal score_submitted(tx_hash: String)

var wallet_address: String = ""
var is_connected: bool = false

func connect_wallet() -> void:
	wallet_address = "0x1234567890abcdef1234567890abcdef12345678"
	is_connected = true
	wallet_connected.emit(wallet_address)
	_show_toast("Wallet connected: " + wallet_address.substr(0, 10) + "...")

func disconnect_wallet() -> void:
	wallet_address = ""
	is_connected = false

func submit_score(score: int) -> void:
	if not is_connected:
		push_warning("Web3Manager: Wallet not connected")
		return
	var tx_hash = "0x" + str(randi()).substr(0, 16)
	score_submitted.emit(tx_hash)
	_show_toast("Score submitted! TX: " + tx_hash.substr(0, 10) + "...")

func _show_toast(message: String) -> void:
	AudioManager.play_sfx("powerup")
	var toast := Label.new()
	toast.text = message
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 24)
	toast.position = Vector2(640, 50)
	get_tree().root.add_child(toast)
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: await get_tree().create_timer(2.0).timeout)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	await tween.finished
	toast.queue_free()
