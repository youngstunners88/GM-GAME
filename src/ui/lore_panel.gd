extends CanvasLayer
## Community Lore submission dialog (Video-Game Layer). Players write a short
## SmokeRing-realm lore snippet (<=200 chars) that is stored in the backend
## (Web3Bridge.submit_lore). Top-voted entries become loading-screen tips —
## the community writes the game's flavor text, which is why this belongs to
## the Video-Game Layer (self-improving from player data). Degrades gracefully:
## with no backend it explains the entry is saved locally-only for now.

@onready var _input: TextEdit = $Panel/VBox/Input
@onready var _status: Label = $Panel/VBox/Status
@onready var _count: Label = $Panel/VBox/Count
@onready var _send: Button = $Panel/VBox/Row/SendBtn
@onready var _close: Button = $Panel/VBox/Row/CloseBtn

const MAX_LEN := 200

func _ready() -> void:
	_send.pressed.connect(_on_send)
	_close.pressed.connect(_on_close)
	_input.text_changed.connect(_on_text_changed)
	_on_text_changed()

func open() -> void:
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_input.grab_focus()

func _on_text_changed() -> void:
	# Hard-cap length client-side; the backend also validates.
	if _input.text.length() > MAX_LEN:
		_input.text = _input.text.substr(0, MAX_LEN)
		_input.set_caret_column(MAX_LEN)
	_count.text = "%d / %d" % [_input.text.length(), MAX_LEN]

func _on_send() -> void:
	var snippet := _input.text.strip_edges()
	if snippet.is_empty():
		_status.text = "Write a little something first, friend."
		return
	Web3Bridge.track("lore_submit")
	if not Web3Bridge.has_backend():
		_status.text = "The archive sleeps (no server yet).\nYour words drift into the smoke for now."
		_send.disabled = true
		return
	_status.text = "Sending your lore to the realm..."
	_send.disabled = true
	Web3Bridge.submit_lore(snippet, func(ok: Variant):
		if bool(ok):
			_status.text = "Lore received. If the realm loves it,\nit'll surface as a loading-screen tip."
		else:
			_status.text = "The smoke swallowed it. Try again later."
			_send.disabled = false)

func _on_close() -> void:
	get_tree().paused = false
	queue_free()
