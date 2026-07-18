extends Control
## On-chain-identity leaderboard (Video-Game Layer). Reads the top 20 from the
## backend proxy (Web3Bridge.get_leaderboard) — scores tied to wallet addresses,
## shown truncated. NOT itch.io's system. If no backend is configured it says so
## and offers Back. Scores are stored off-chain (KV) with the wallet as identity;
## the on-chain artifact is the opt-in badge NFT (see backend/README.md tradeoff).

@onready var _list: VBoxContainer = $Panel/VBox/List
@onready var _status: Label = $Panel/VBox/Status
@onready var _back: Button = $Panel/VBox/BackBtn

func _ready() -> void:
	StateMachine.change_state(StateMachine.State.MENU)
	_back.pressed.connect(func(): SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.FADE))
	if not Web3Bridge.has_backend():
		_status.text = "Leaderboard server not yet configured.\n(See LAYER_SHIFT.md — set backend_base_url in config.json.)"
		return
	_status.text = "Loading top runs from the chain..."
	Web3Bridge.get_leaderboard(_on_list)

func _on_list(rows: Variant) -> void:
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty():
		_status.text = "No runs submitted yet. Be the first!"
		return
	_status.text = "TOP RUNS"
	var rank := 1
	for r in rows:
		var addr: String = str(r.get("addr", "0xguest"))
		var short := addr if addr.length() < 12 else addr.substr(0, 6) + "..." + addr.substr(addr.length() - 4, 4)
		var line := Label.new()
		line.text = "%2d.  %s   %d   (L%d)" % [rank, short, int(r.get("score", 0)), int(r.get("level", 1))]
		line.add_theme_font_size_override("font_size", 20)
		_list.add_child(line)
		rank += 1
