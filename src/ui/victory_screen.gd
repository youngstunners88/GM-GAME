extends CanvasLayer
## Boss-victory / Level-Complete screen with the Movie + Video-Game Layer hooks:
##   - CLAIM YOUR BADGE  (Movie Layer)   -> connect wallet + mint the "SmokeRing
##     Survivor" ERC-721. Skippable; the level is already won without it.
##   - SUBMIT SCORE       (Video-Game Layer) -> post score+wallet to the on-chain
##     leaderboard proxy.
##   - VIEW YOUR NFT      (Marketing funnel) -> open the badge on the block explorer.
##   - CONTINUE           -> back to the hub.
## The Book Layer (beating the boss) is complete before this screen appears; every
## button here is purely additive and degrades to a friendly message with no
## wallet/backend/contract configured. See LAYER_SHIFT.md.

@onready var _title: Label = $Root/Title
@onready var _status: Label = $Root/Status
@onready var _claim: Button = $Root/Buttons/ClaimBadge
@onready var _score: Button = $Root/Buttons/SubmitScore
@onready var _nft: Button = $Root/Buttons/ViewNFT
@onready var _continue: Button = $Root/Buttons/Continue

var _final_score: int = 0
var _level: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _final_score == 0:
		_final_score = GameManager.total_score
	_claim.pressed.connect(_on_claim)
	_score.pressed.connect(_on_score)
	_nft.pressed.connect(_on_view_nft)
	_continue.pressed.connect(_on_continue)
	# The "View NFT" link only makes sense once a badge contract is configured.
	_nft.visible = Web3Bridge.badge_explorer_url() != ""
	Web3Bridge.track("level_complete")
	_status.text = "Score: %d" % _final_score

## Configure before adding to tree (score/level for the leaderboard submission).
func setup(score: int, level: int) -> void:
	_final_score = score
	_level = level

func _on_claim() -> void:
	Web3Bridge.track("badge_claim_click")
	if not Web3Bridge.is_web3_available():
		_status.text = "Play the web build with a wallet to claim your badge.\n(Your victory still counts!)"
		return
	_status.text = "Connecting wallet..."
	if Web3Bridge.wallet_address == "":
		# connect_wallet() emits EITHER wallet_connected OR wallet_failed, so we
		# can't await one signal (a decline would hang here). It resolves within
		# ~1.2s internally; kick it and re-check the address.
		Web3Bridge.connect_wallet()
		await get_tree().create_timer(1.6).timeout
	if Web3Bridge.wallet_address == "":
		_status.text = "Wallet not connected.\n(Your victory still counts!)"
		return
	if Web3Bridge.mint_survivor_badge():
		_status.text = "Minting your SmokeRing Survivor badge...\nConfirm in your wallet."
		_claim.disabled = true
		_nft.visible = Web3Bridge.badge_explorer_url() != ""
	else:
		_status.text = "Badge contract not live yet.\n(See LAYER_SHIFT.md — set survivor_badge_erc721 in config.json.)"

func _on_score() -> void:
	Web3Bridge.track("score_submit_click")
	if not Web3Bridge.has_backend():
		_status.text = "Leaderboard server not configured yet.\nYour score is saved locally."
		return
	_status.text = "Submitting score to the chain..."
	_score.disabled = true
	Web3Bridge.submit_score(_final_score, _level, func(res: Variant):
		if typeof(res) == TYPE_DICTIONARY and not (res as Dictionary).is_empty():
			_status.text = "Score submitted! Check the leaderboard."
		else:
			_status.text = "Couldn't reach the leaderboard. Try later."
			_score.disabled = false)

func _on_view_nft() -> void:
	Web3Bridge.track("view_nft_click")
	var url := Web3Bridge.badge_explorer_url()
	if url != "":
		OS.shell_open(url)

func _on_continue() -> void:
	get_tree().paused = false
	SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.DIAMOND)
