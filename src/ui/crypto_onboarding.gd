extends CanvasLayer
## "New to Crypto?" onboarding (Movie Layer, crypto-onboarding skill).
## Plain-language, zero-jargon explainer for players who've never touched a
## wallet. Lil Blunt gives a thumbs-up; nothing here is required to play.
## The privacy paragraph is the client-mandated exact copy and is kept TRUE
## by architecture: balance checks go through the stateless /balances read
## (no address stored); the one opt-in exception (leaderboard submit) is
## disclosed in the Learn More modal. Tracks onboarding_viewed (from the menu
## button), onboarding_wallet_clicked, onboarding_dismissed.

@onready var _close: Button = $Panel/VBox/Row/CloseBtn
@onready var _rabby: Button = $Panel/VBox/Row/RabbyBtn
@onready var _learn: Button = $Panel/VBox/Row/LearnBtn

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_close.pressed.connect(_dismiss)
	_rabby.pressed.connect(_on_rabby)
	_learn.pressed.connect(_on_learn_more)
	# Lil Blunt approves: his sprite, gently bobbing beside the title.
	var spr := Sprite2D.new()
	var tex_path := "res://src/assets/sprites/sprite_lil-blunt_idle_01.png"
	spr.texture = load(tex_path) if ResourceLoader.exists(tex_path) \
			else load("res://src/assets/sprites/sprite_item_eth-ring.png")
	spr.position = Vector2(340, 96)
	spr.scale = Vector2(2, 2)
	$Panel.add_child(spr)
	var tw := spr.create_tween().set_loops()
	tw.tween_property(spr, "position:y", 88.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "position:y", 96.0, 1.1).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()

func _dismiss() -> void:
	Web3Bridge.report_metric("onboarding_dismissed", {})
	get_tree().paused = false
	queue_free()

## Brief correction C: Rabby is the player-facing wallet association.
func _on_rabby() -> void:
	Web3Bridge.report_metric("onboarding_wallet_clicked", {})
	Web3Bridge.track("onboarding_rabby")
	OS.shell_open("https://rabby.io/")

## Learn More: the three safety concepts, still jargon-free.
func _on_learn_more() -> void:
	Web3Bridge.track("onboarding_learn_more")
	var dlg := AcceptDialog.new()
	dlg.title = "How the wallet stuff actually works"
	dlg.dialog_text = (
		"WHAT IS A WALLET ADDRESS?\n" +
		"A public identifier, like an email address. Anyone can see it;\n" +
		"only you control it. Sharing it shares nothing private.\n\n" +
		"WHAT IS balanceOf()?\n" +
		"A read-only question to a public ledger: 'how many tokens does\n" +
		"this address hold?' Like checking a public scoreboard - looking\n" +
		"changes nothing and costs nothing.\n\n" +
		"WHY IS THIS SAFE?\n" +
		"No private keys ever leave your wallet. We request zero\n" +
		"approvals, so we CANNOT move or spend your tokens. Reads only.\n\n" +
		"THE ONE EXCEPTION (opt-in): if you press 'Submit score to\n" +
		"chain' on a victory screen, your public address is stored on\n" +
		"the game leaderboard. That's your call, every time.")
	dlg.ok_button_text = "GOT IT"
	add_child(dlg)
	dlg.popup_centered()
