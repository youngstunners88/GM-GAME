extends Node
## Demo-mode wallet UX. There is NO real wallet, blockchain, or reward backend
## in this game — this exists purely so the menu can showcase where a future
## integration would live. Every user-facing string MUST say "demo" so players
## can never mistake it for a real on-chain action (see security audit).
## Do not add a real provider here without a server-authoritative backend.

signal wallet_connected(address: String)
signal score_submitted(tx_hash: String)

## Obviously-fake placeholder shown in demo mode (not a real account).
const DEMO_ADDRESS := "0xDEMO...0000"

var wallet_address: String = ""
var is_connected: bool = false

func connect_wallet() -> void:
	wallet_address = DEMO_ADDRESS
	is_connected = true
	wallet_connected.emit(wallet_address)
	_show_toast("Demo Mode — no real wallet is connected")

func disconnect_wallet() -> void:
	wallet_address = ""
	is_connected = false

func submit_score(score: int) -> void:
	if not is_connected:
		push_warning("Web3Manager: Wallet not connected")
		return
	# No fake tx hashes: nothing is submitted anywhere in demo mode.
	score_submitted.emit("demo")
	_show_toast("Demo Mode — score saved locally only (%d)" % score)

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
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.finished.connect(toast.queue_free)
