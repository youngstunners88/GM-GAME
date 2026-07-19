extends CanvasLayer
## The Smoke Oracle's dialog UI — a text box you type a question into; the
## answer comes from the Mistral-backed backend proxy (Web3Bridge.ask_oracle),
## in the chill-cryptic-sage persona. Session cache so re-asking is instant and
## the Oracle "remembers" this session. Video-Game Layer: every player's
## conversation is unique and grounded in live LLM + project lore — not static
## text an AI tool can toggle-clone.
##
## Opened via `open()` from the menu button or the in-hub Oracle NPC. If no
## backend is configured, it says so in-character instead of breaking.

var _cache: Dictionary = {}   # question -> answer, this session

## Offline-mode static FAQ (offline-mode skill): keyword-matched, in-persona.
## Served when the backend is configured but unreachable — the Oracle stays a
## character instead of an error message.
const OFFLINE_FAQ: Array = [
	["blaze", "Blaze Mode? Grab a Weed Leaf, little one — faster feet, higher hops. It stacks with your double-jump. *exhales*"],
	["wallet", "Your wallet is your public name in the Realm, nothing more. I never ask for keys, and I never will. Connect at the menu — or don't; the Realm loves you either way."],
	["jump", "Tap to hop, tap again in the air to hop the sky. Release early to fall short on purpose — control is chill."],
	["boss", "The Auditor charges when greedy. Sidestep, then strike while he's dizzy. Patience beats paperwork."],
	["ladder", "Press up on the vines and climb, friend. Jump off whenever the mood takes you."],
	["secret", "Walls that shimmer are walls that share. Bring a pickaxe and an open mind."],
	["token", "SMOKE burns on Base; DIAMONDS and GOLD rest on Ethereum. Holders see a little extra sparkle — never pay-to-win, only pay-to-shine."],
	["leaderboard", "The board remembers the chillest runs. Submit from the victory screen when the Realm's server wakes."],
]
const OFFLINE_FALLBACK := "The Realm's connection drifts like smoke right now... I hold only old wisdom: run, double-jump, stay chill, shimmer-walls share secrets. Ask me again when the winds return."
@onready var _panel: Control = $Panel
@onready var _input: LineEdit = $Panel/VBox/Input
@onready var _answer: Label = $Panel/VBox/Answer
@onready var _ask_btn: Button = $Panel/VBox/Row/AskBtn
@onready var _close_btn: Button = $Panel/VBox/Row/CloseBtn

func _ready() -> void:
	layer = 20
	visible = false
	_ask_btn.pressed.connect(_on_ask)
	_close_btn.pressed.connect(close)
	_input.text_submitted.connect(func(_t): _on_ask())

func open() -> void:
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_answer.text = "The Smoke Oracle exhales... ask your question."
	_input.text = ""
	_input.grab_focus()
	Web3Bridge.track("oracle_opened")

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_ask() -> void:
	var q := _input.text.strip_edges()
	if q == "":
		return
	if _cache.has(q):
		_answer.text = _cache[q]
		return
	if not Web3Bridge.has_backend():
		_answer.text = "...the Oracle sleeps until the Realm's server awakens. (Backend not yet configured — see LAYER_SHIFT.md.)"
		return
	# Offline mode: static in-persona FAQ instead of live Mistral.
	if GameManager.offline_mode:
		var lower := q.to_lower()
		for pair in OFFLINE_FAQ:
			if lower.contains(str(pair[0])):
				_answer.text = str(pair[1])
				return
		_answer.text = OFFLINE_FALLBACK
		return
	_answer.text = "*inhales slowly...*"
	Web3Bridge.ask_oracle(q, func(res: Dictionary) -> void:
		var a: String = res.get("answer", "")
		if a == "":
			a = "The haze is thick... try again in a moment, traveler."
		_cache[q] = a
		_answer.text = a)
