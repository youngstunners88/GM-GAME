extends CanvasLayer
## "Talk to Lil Blunt" — the Episode 1 companion chat MVP.
##
## Distinct from the Smoke Oracle (src/ui/oracle_panel.gd): the Oracle is a
## cryptic third-party sage who answers lore questions. THIS is Lil Blunt
## himself, the character the player is controlling, talking to them mid-run
## with awareness of what is actually happening — which level, how many lives
## are left, whether a boss is active, whether they're in Blaze Rush, what
## power-ups are live. That state awareness is the whole point: a generic
## chatbot bolted onto a game is the "book layer" trap this project explicitly
## avoids (docs/roadmap/episode-strategy-and-voice-system.md).
##
## Architecture: same hardened proxy path as the Oracle — the Godot client
## NEVER holds an API key. Game state is POSTed to the backend's /companion
## endpoint, which owns the Mistral key, whitelists/clamps every state field,
## rate-limits per IP, and caps daily spend.
##
## Degradation ladder (the game must never depend on this working):
##   backend absent   -> in-character "no signal" line
##   offline mode     -> STATE-AWARE canned lines (still reacts to the run)
##   request fails    -> in-character retry line
## Core platforming is never blocked by any of these.

## Offline/no-backend replies. These are deliberately state-conditioned rather
## than one generic fallback: even with zero connectivity Lil Blunt should say
## something that matches the run, because "aware of the run" is the feature.
## Tone from the Grok 4.5 brief (docs/model-responses/2026-08-05-grok-vo-lines-companion.md).
const OFFLINE_LINES := {
	"boss_death": "Oof. That boss caught us slippin'. We got next — no sweat.",
	"low_lives": "Last life, huh. Slow is smooth — I'm right here with you.",
	"blaze_rush": "Blaze Rush is live… floaty and fast. Don't overthink it.",
	"powered_up": "We're buffed up right now. Go make a mess.",
	"boss_active": "Big fella's up. Watch the wind-up, then punish it.",
	"early": "Just gettin' started. Take the scenic route if you want, no rush.",
	"default": "Signal's hazy so I'm keepin' it short — but I'm here. Keep goin'.",
}

## Extra variants for the two states a struggling player hits most often.
## Without these, dying to the Auditor repeatedly replays one identical
## sentence, which reads as canned exactly when the player most needs it not
## to. Lines from the Grok 4.5 pass
## (docs/model-responses/2026-08-06-grok-companion-extra-lines.md).
const OFFLINE_VARIANTS := {
	"low_lives": [
		"One left. Breathe with me — we still got this.",
		"Final life. Easy does it. I'm riding shotgun.",
		"Down to the wire. Stay loose. Right beside you.",
	],
	"boss_death": [
		"Auditor clipped us. Shake it off — rematch time.",
		"He got the jump. Next round's ours, real talk.",
		"Tough hit. Dust off. We learn, we go again.",
	],
}

## Round-robin index per state key, so consecutive hits of the same state
## cycle instead of repeating. Deliberately not random: random repeats itself
## visibly often at these small pool sizes.
var _variant_turn: Dictionary = {}

var _cache: Dictionary = {}   # question -> answer, this session

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
	_input.text_submitted.connect(func(_t: String) -> void: _on_ask())

func open() -> void:
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_answer.text = "Yo. What's good?"
	_input.text = ""
	_input.grab_focus()
	Web3Bridge.track("companion_opened")

## Kimi audit (2026-08-06): this MUST free the panel, not just hide it.
## The pause-menu opener re-shows itself on this node's `tree_exited`. A
## hidden-but-alive panel never fires that signal, which left the pause menu
## hidden while StateMachine was still PAUSED and the tree was unpaused —
## gameplay stays gated off (player.gd early-returns when not PLAYING) with
## no visible menu, i.e. a soft-lock recoverable only via the pause key. It
## also leaked one invisible panel per Talk-button press.
func close() -> void:
	visible = false
	# Hand the tree back to gameplay ONLY if we are not returning to a paused
	# menu. Opened from the main menu (not PAUSED) -> unpause. Opened from the
	# pause menu (PAUSED) -> stay paused so the re-shown menu isn't sitting
	# over a running game.
	get_tree().paused = StateMachine.is_paused()
	queue_free()

## Read-only snapshot of the run. Every field here is safe to show the player
## — nothing secret, no wallet keys, no unearned spoilers. The backend
## re-validates and clamps all of it; this is a convenience, not a trust
## boundary.
func _build_state() -> Dictionary:
	var level_names := {
		1: "The Smoke Realm", 2: "Crystal Caverns", 3: "GoldMine Rush",
	}
	var boss_id: String = ""
	if BossVoiceSystem and "_active_boss_id" in BossVoiceSystem:
		boss_id = str(BossVoiceSystem._active_boss_id)
	var powers: Array = []
	if GameManager.current_power_up != "":
		powers.append(GameManager.current_power_up)
	# "In Blaze Rush" is inferred from the running scene rather than a global
	# flag, because Blaze Rush is a separate scene with its own lifecycle.
	var in_rush := false
	var scn := get_tree().current_scene
	if scn != null:
		in_rush = String(scn.scene_file_path).contains("blaze_rush")
	return {
		"level": GameManager.current_level,
		"level_name": level_names.get(GameManager.current_level, "the Realm"),
		"lives": GameManager.lives,
		"health": GameManager.player_health,
		"score": GameManager.total_score,
		"in_blaze_rush": in_rush,
		"boss_active": boss_id,
		"power_ups": powers,
		"last_death": GameManager.last_damage_source,
		"first_run": GameManager.total_score == 0 and GameManager.current_level == 1,
	}

## Picks the offline line that best matches the live run — checked most
## specific first so "last life during a boss fight" reads as the boss line,
## not the generic one.
## Returns the base line for `key`, rotating through OFFLINE_VARIANTS when
## that state has extras. Falls back to OFFLINE_LINES for states with none.
func _line_for(key: String) -> String:
	if OFFLINE_VARIANTS.has(key):
		var pool: Array = OFFLINE_VARIANTS[key]
		var turn: int = int(_variant_turn.get(key, 0))
		_variant_turn[key] = turn + 1
		# Turn 0 uses the original OFFLINE_LINES entry so the established
		# first-impression wording is still what a player hears first.
		if turn == 0:
			return OFFLINE_LINES[key]
		return str(pool[(turn - 1) % pool.size()])
	return OFFLINE_LINES[key]

func _offline_line(state: Dictionary) -> String:
	if str(state.get("last_death", "")) != "" and int(state.get("lives", 3)) < 3:
		return _line_for("boss_death")
	if int(state.get("lives", 3)) <= 1:
		return _line_for("low_lives")
	if bool(state.get("in_blaze_rush", false)):
		return _line_for("blaze_rush")
	if str(state.get("boss_active", "")) != "":
		return _line_for("boss_active")
	if not (state.get("power_ups", []) as Array).is_empty():
		return _line_for("powered_up")
	if bool(state.get("first_run", false)):
		return _line_for("early")
	return _line_for("default")

func _on_ask() -> void:
	var q := _input.text.strip_edges()
	if q == "":
		return
	if _cache.has(q):
		_answer.text = _cache[q]
		return
	var state := _build_state()
	if not Web3Bridge.has_backend():
		_answer.text = _offline_line(state)
		return
	if GameManager.offline_mode:
		_answer.text = _offline_line(state)
		return
	_answer.text = "*thinking…*"
	Web3Bridge.ask_companion(q, state, func(res: Dictionary) -> void:
		var a: String = res.get("answer", "")
		if a == "":
			a = _offline_line(state)
		_cache[q] = a
		_answer.text = a)
