class_name MinerShaftChamber
extends Node3D
## Episode 2 — Chamber 1, Miner Shaft. GRAYBOX 3D shooter/RPG encounter
## (engine primitives only), the chamber half of the runner↔chamber loop.
##
## Brief: artifacts/episode2-gold-mine/chambers/01_CHAMBER_MINER_SHAFT.md.
## Layout rules: spec/CHAMBER_ARCHITECTURE_PLAN.md §3 (cover/sightlines) and
## §4, which explicitly recommends building THIS chamber graybox-first
## *without* Pascal — its identity is a rough mine shaft, not a building, and
## it is story-critical, so it must not wait on an asset pipeline.
##
## Same graybox discipline as runner_graybox.gd: box meshes, deterministic
## `step(delta)` so a headless test can drive the sim without a frame clock,
## pure state + getters, and signals out to the session root. When real GLBs
## arrive they drop into the same node slots without touching this logic.
##
## ECONOMY BOUNDARY (architecture rail #5 — "economy/progression live outside
## disposable scenes"): this chamber NEVER writes to GoldMineSystem. It
## computes the vest/claim outcome and emits it; `ep2_session_root.gd` owns
## the commit. That is what makes the double-reward guard possible at all —
## a scene that credits itself cannot be made idempotent by its caller.
##
## PROTOCOL NUMBERS (rail #1 — never invent them):
##   - 100-day vest at 1%/day, and early claim forfeiting the unvested
##     remainder into the auction pool, are the white paper's real mechanics
##     (docs/whitepapers/GoldMine.md §Overview) and live as
##     GoldMineSystem.MINER_VESTING_DAYS / forfeit_to_auction().
##   - The 20% Diamond burn is GoldMineSystem.DIAMOND_BURN_PCT.
##   - The miner's GOLD principal is NOT a constant anywhere in
##     goldmine_system.gd or the white paper, so it is NOT invented here —
##     it is a required `setup()` argument supplied by the caller.
##   - VEST_SECONDS_FULL is the 100-day→encounter time compression. The
##     chamber brief lists this ratio as an OPEN question ("needs
##     playtesting, not a design-doc answer"), so it is a tunable graybox
##     value, deliberately not presented as a protocol constant.

## Emitted once the rig is running; carries the chosen payment mode.
signal rig_started(payment: String)
## Emitted once, when the encounter resolves. `result` carries the full
## outcome the session root needs to commit:
##   {gold_awarded, gold_forfeited, diamonds_burned, vest_fraction, early}
signal chamber_cleared(result: Dictionary)
## Emitted when the player's health hits zero. The run is over; no reward.
signal chamber_failed
## Emitted each time the player takes a hit; carries remaining health.
signal player_hit(remaining_health: int)

# --- Vest tuning (graybox; feel is tuned later, not law) ----------------------
## Seconds of encounter time that map to the full 100-day vest. Open question
## per the chamber brief — tuned by playtest, not derived from the protocol.
const VEST_SECONDS_FULL := 45.0
## Fraction of a day's vest lost per successful sabotage. A pressure knob, not
## a protocol number: the white paper has no concept of sabotage.
const SABOTAGE_VEST_PENALTY := 0.04

# --- Combat tuning (graybox) --------------------------------------------------
const START_HEALTH := 3
const START_AMMO := 12
const SHOT_RANGE := 18.0           # matches §3's "no sightline longer than 18m"
const BEAR_SPEED := 1.8            # metres/sec toward the rig
const BEAR_HP := 2
const BEAR_SABOTAGE_RANGE := 1.5   # distance from rig at which a bear sabotages
const BEAR_SABOTAGE_COOLDOWN := 2.0
const COVER_DAMAGE_IMMUNITY := true  # in cover, bear contact damages the rig, not you

# --- Layout (metres; CHAMBER_ARCHITECTURE_PLAN §3 tiers) ----------------------
## The rig sits at the far end so the fight pushes entrance→rig, and the Early
## Claim lever sits BESIDE the rig: bailing out is always reachable from the
## position you are already defending, never a separate trek (the brief calls
## the lever "always available").
const RIG_POSITION := Vector3(0.0, 0.0, 14.0)
const ENTRY_APRON_Z := 0.0

var _payment: String = ""
var _rig_started: bool = false
var _vest: float = 0.0             # 0..1; 1.0 == the full 100-day vest
var _resolved: bool = false        # guards double-resolve (rail #5)
var _health: int = START_HEALTH
var _ammo: int = START_AMMO
var _in_cover: bool = false
var _gold_principal: int = 0
var _diamonds_paid: int = 0
var _bears: Array = []             # [{z, hp, alive, cooldown}]
var _running: bool = false

@onready var _rig: Node3D = $Rig

func _ready() -> void:
	if _rig:
		_rig.position = RIG_POSITION

## Configure before the encounter runs. `gold_principal` is the miner's GOLD
## yield at full vest — supplied by the caller because no such constant exists
## in goldmine_system.gd or the white paper (see PROTOCOL NUMBERS above).
## `bears` entries are {z: float} spawn positions; hp/alive/cooldown are filled
## in here so a caller can't hand us a half-initialised enemy.
##
## Safe to call again on a reused instance — resets ALL state, including
## `_resolved` and `_running`. (Same class of bug as the runner's Kimi audit
## #5c: a stale terminal flag from a prior run makes every later step() a
## silent no-op.)
func setup(gold_principal: int, bears: Array = [], diamonds_paid: int = 0) -> void:
	_gold_principal = max(0, gold_principal)
	_diamonds_paid = max(0, diamonds_paid)
	_bears.clear()
	for b in bears:
		_bears.append({
			"z": float(b.get("z", 0.0)),
			"hp": int(b.get("hp", BEAR_HP)),
			"alive": true,
			"cooldown": 0.0,
		})
	_payment = ""
	_rig_started = false
	_vest = 0.0
	_resolved = false
	_health = START_HEALTH
	_ammo = START_AMMO
	_in_cover = false
	_running = true

func _physics_process(delta: float) -> void:
	if _running:
		_advance(delta)

## Split out so a headless test can step the sim deterministically without a
## real frame clock — identical contract to RunnerGraybox.step().
func step(delta: float) -> void:
	if _running:
		_advance(delta)

func _advance(delta: float) -> void:
	# The vest only accrues once the rig is actually started. Standing in the
	# chamber doing nothing must never earn GOLD.
	if _rig_started and not _resolved:
		_vest = minf(1.0, _vest + delta / VEST_SECONDS_FULL)

	_advance_bears(delta)

	# Full vest resolves the encounter on its own — hold-to-full is the
	# patient branch of the brief's risk/reward decision.
	if _rig_started and not _resolved and _vest >= 1.0:
		_resolve(false)

func _advance_bears(delta: float) -> void:
	for b in _bears:
		if not b["alive"]:
			continue
		b["cooldown"] = maxf(0.0, b["cooldown"] - delta)
		# Bears only mobilise once the rig is running — the brief's pressure
		# phase is triggered BY starting the vest, not by entering the room.
		if not _rig_started:
			continue
		var dist: float = RIG_POSITION.z - b["z"]
		if dist > BEAR_SABOTAGE_RANGE:
			b["z"] += BEAR_SPEED * delta
		elif b["cooldown"] <= 0.0:
			_sabotage(b)

## A bear that reaches the rig either damages the player, or — if the player
## is behind cover — attacks the rig's vest instead. Cover is therefore a real
## trade, not a free win: you stop losing health and start losing yield.
func _sabotage(b: Dictionary) -> void:
	b["cooldown"] = BEAR_SABOTAGE_COOLDOWN
	if _in_cover and COVER_DAMAGE_IMMUNITY:
		_vest = maxf(0.0, _vest - SABOTAGE_VEST_PENALTY)
		return
	_health -= 1
	player_hit.emit(_health)
	if _health <= 0:
		_health = 0
		_running = false
		if not _resolved:
			_resolved = true
			chamber_failed.emit()

# --- Player verbs -------------------------------------------------------------

## Start the miner. `payment` is "eth" or "eth_diamonds" — the brief's real
## protocol choice. No-op once started, so a mashed interact can't restart the
## vest or re-emit the signal.
func start_rig(payment: String = "eth") -> bool:
	if _rig_started or _resolved or not _running:
		return false
	if payment != "eth" and payment != "eth_diamonds":
		return false
	# Diamonds only count as paid when the player actually chose to spend them.
	if payment == "eth":
		_diamonds_paid = 0
	_payment = payment
	_rig_started = true
	rig_started.emit(payment)
	return true

## Fire at the nearest live bear within SHOT_RANGE of the rig line. Returns
## true if a shot was actually spent. Deterministic (nearest target, no RNG)
## so the headless gate can assert exact outcomes.
func shoot() -> bool:
	if not _running or _resolved or _ammo <= 0:
		return false
	_ammo -= 1
	var best: Dictionary = {}
	var best_dist: float = INF
	for b in _bears:
		if not b["alive"]:
			continue
		var d: float = absf(RIG_POSITION.z - b["z"])
		if d <= SHOT_RANGE and d < best_dist:
			best_dist = d
			best = b
	if best.is_empty():
		return true  # a miss still costs the round
	best["hp"] = int(best["hp"]) - 1
	if int(best["hp"]) <= 0:
		best["alive"] = false
	return true

func take_cover() -> void:
	_in_cover = true

func leave_cover() -> void:
	_in_cover = false

## The brief's Early Claim lever — always available once the rig runs. Takes
## partial GOLD now and forfeits the unvested remainder to the auction pool.
func early_claim() -> bool:
	if not _rig_started or _resolved or not _running:
		return false
	_resolve(true)
	return true

# --- Resolution ---------------------------------------------------------------

## Computes the outcome and emits it. NEVER writes to GoldMineSystem — the
## session root commits (see ECONOMY BOUNDARY above). Idempotent via
## `_resolved`, so a full-vest tick landing on the same frame as a lever pull
## cannot pay out twice.
func _resolve(early: bool) -> void:
	if _resolved:
		return
	_resolved = true
	_running = false
	var vest: float = clampf(_vest, 0.0, 1.0)
	# Linear 1%/day over the 100-day term: the fraction of the term served IS
	# the fraction of principal earned. floor() so rounding never mints GOLD
	# that the forfeit side isn't debited for.
	var awarded: int = int(floor(_gold_principal * vest))
	var forfeited: int = _gold_principal - awarded
	var burned: int = 0
	if _payment == "eth_diamonds" and _diamonds_paid > 0:
		burned = int(round(_diamonds_paid * _diamond_burn_pct()))
	chamber_cleared.emit({
		"gold_awarded": awarded,
		"gold_forfeited": forfeited,
		"diamonds_burned": burned,
		"vest_fraction": vest,
		"early": early,
	})

## Reads the burn rate from the real economy autoload when it is present, so
## this can never drift from GoldMineSystem.DIAMOND_BURN_PCT. Falls back to
## the white paper's documented 20% only when the autoload is absent (the
## graybox is designed to be reasoned about in isolation).
##
## Deliberately NOT `if "DIAMOND_BURN_PCT" in gm`: in Godot 4 the `in` operator
## on an Object tests the *property* list, and script constants are not
## properties — that check returns false for a const that is perfectly
## readable as `gm.DIAMOND_BURN_PCT`, so it would silently take the fallback
## branch forever and defeat the whole point of reading the live value.
func _diamond_burn_pct() -> float:
	var gm: Node = get_node_or_null("/root/GoldMineSystem")
	if gm == null:
		return 0.20
	return float(gm.DIAMOND_BURN_PCT)

# --- Getters (headless assertions read these) ---------------------------------
func get_vest() -> float: return _vest
func get_health() -> int: return _health
func get_ammo() -> int: return _ammo
func is_rig_started() -> bool: return _rig_started
func is_resolved() -> bool: return _resolved
func is_running() -> bool: return _running
func is_in_cover() -> bool: return _in_cover
func get_payment() -> String: return _payment
func get_live_bear_count() -> int:
	var n: int = 0
	for b in _bears:
		if b["alive"]:
			n += 1
	return n
func get_bear_z(i: int) -> float:
	return float(_bears[i]["z"]) if i >= 0 and i < _bears.size() else 0.0
