extends CanvasLayer
## First-play optional email capture (Movie Layer — AgentMail marketing engine).
## Shown ONCE before the first run: an optional email field + explicit consent
## checkbox. Skipping is always one click and never asked again. Submitting
## calls the backend (/email/signup) which validates, stores, and fires the
## welcome sequence. See AGENTMAIL_SETUP.md for the full flow + compliance.

signal closed

const SHOWN_FLAG := "user://email_prompt_shown.txt"

@onready var _email: LineEdit = $Panel/VBox/Email
@onready var _name: LineEdit = $Panel/VBox/Name
@onready var _consent: CheckBox = $Panel/VBox/Consent
@onready var _status: Label = $Panel/VBox/Status
@onready var _join: Button = $Panel/VBox/Row/JoinBtn
@onready var _skip: Button = $Panel/VBox/Row/SkipBtn

## True if the prompt was already offered once (never re-nag).
static func already_shown() -> bool:
	return FileAccess.file_exists(SHOWN_FLAG)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_join.pressed.connect(_on_join)
	_skip.pressed.connect(_on_skip)
	_email.grab_focus()

## Keyboard path (UI rule: keyboard AND mouse): Escape skips the prompt.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_skip()

func _on_join() -> void:
	var email := _email.text.strip_edges()
	if email == "" or not "@" in email or not "." in email.get_slice("@", 1):
		_status.text = "That email doesn't look right, friend."
		return
	if not _consent.button_pressed:
		_status.text = "Tick the consent box first — we only send what you agree to."
		return
	if not Web3Bridge.has_backend():
		_status.text = "Server's asleep — you're in the Realm anyway. Let's play!"
		_finish()
		return
	_join.disabled = true
	_status.text = "Joining the SmokeRing list..."
	Web3Bridge.signup_email(email, true, _name.text.strip_edges(), _on_signup_done)

func _on_signup_done(res: Variant) -> void:
	if typeof(res) == TYPE_DICTIONARY and (res as Dictionary).get("ok", false):
		_status.text = "Welcome in. Check your inbox 🌿"
	else:
		_status.text = "Couldn't sign you up right now — let's just play."
	await get_tree().create_timer(1.1).timeout
	_finish()

func _on_skip() -> void:
	Web3Bridge.track("email_skip")
	_finish()

## One exit path: record that the prompt was offered, then hand control back.
func _finish() -> void:
	var f := FileAccess.open(SHOWN_FLAG, FileAccess.WRITE)
	if f:
		f.store_string("1")
	closed.emit()
	queue_free()
