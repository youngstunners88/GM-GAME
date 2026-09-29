class_name RunnerVoice
extends Node
## Lil Blunt's VOICE + the bears' voices in the Episode 2 runner (skill: ep2-voice-barks).
## Founder, 2026-09-29: "Lil Blunt is not even reacting to anything vocally. A boulder
## smashes a cart, that's life-threatening! Hopping over is something to celebrate ...
## I want a variation in his vocabulary." Bears: "we should hear them in the distance
## as we approach closer."
##
## Reads the sim (the parent RunnerGraybox), never writes to it. Lines come from
## VoiceBank (generated from assets/ep2-voice-bank.json). A missing take = silent slot.
##
## Variety rules (all in the pure static Pick so tests run headless):
##  - a category deals its lines from a shuffled BAG: no line repeats until every line
##    has been said, and the first line of a new bag is never the last of the old one
##  - one voice at a time; a higher-priority line cuts a lower one, never the reverse
##  - per-category gap so "Bitcoin, baby!" is an occasion, not a tic

const Bank := preload("res://src/episode2/runner/voice_bank.gd")

const BEAR_DIR := "res://src/assets/sounds/"
const BEAR_GROWLS := ["ep2_bear_growl_1", "ep2_bear_growl_2", "ep2_bear_growl_3"]
## Bears become audible inside this range (m) and grow louder as the cart closes in.
const BEAR_HEAR := 46.0
const BEAR_LOUD := 8.0
const COIN_EVERY := 6
const BOULDER_WARN := 22.0
const BEAR_SIGHT := 34.0
const VOICE_DB := 2.0

## ---- pure logic (headless-testable) ------------------------------------------

## One shuffled bag per category. Returns the next line id, or "" if the category is empty.
class Pick extends RefCounted:
	var _bags: Dictionary = {}
	var _last: Dictionary = {}
	var rng := RandomNumberGenerator.new()

	func next(cat: String, ids: Array) -> String:
		if ids.is_empty():
			return ""
		var bag: Array = _bags.get(cat, [])
		if bag.is_empty():
			bag = ids.duplicate()
			_shuffle(bag)
			var last: String = str(_last.get(cat, ""))
			if bag.size() > 1 and str(bag[0]) == last:
				var j: int = rng.randi_range(1, bag.size() - 1)
				var t: Variant = bag[0]
				bag[0] = bag[j]
				bag[j] = t
		var id: String = str(bag.pop_front())
		_bags[cat] = bag
		_last[cat] = id
		return id

	func _shuffle(a: Array) -> void:
		for i in range(a.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var t: Variant = a[i]
			a[i] = a[j]
			a[j] = t

## May `cat` speak now? `busy_priority` is the priority of the line currently playing (-1 = none).
static func may_speak(cat: String, now: float, last_by_cat: Dictionary, busy_priority: int) -> bool:
	var c: Dictionary = Bank.CATEGORIES.get(cat, {})
	if c.is_empty():
		return false
	if now - float(last_by_cat.get(cat, -999.0)) < float(c["gap"]):
		return false
	return busy_priority < 0 or int(c["priority"]) > busy_priority

## Volume (dB) a bear is heard at, `d` metres away. Silent past BEAR_HEAR, full at BEAR_LOUD.
static func bear_db(d: float) -> float:
	if d >= BEAR_HEAR:
		return -80.0
	var t: float = clampf((BEAR_HEAR - d) / (BEAR_HEAR - BEAR_LOUD), 0.0, 1.0)
	return lerpf(-30.0, 0.0, t * t)

## ---- node ----------------------------------------------------------------------

var _sim: Node
var _voice: AudioStreamPlayer
var _pick := Pick.new()
var _streams: Dictionary = {}
var _last_by_cat: Dictionary = {}
var _cur_priority: int = -1
var _now: float = 0.0
var _coins: int = 0
var _lane: int = -1
var _bail_t: float = -9.0
var _was_airborne: bool = false
var _announced: Dictionary = {}
var _bear_players: Dictionary = {}     # archer id -> AudioStreamPlayer3D
var _bear_next: Dictionary = {}        # archer id -> next growl time
var _bear_fx: Dictionary = {}          # sfx id -> stream
var spoken: Array = []                 # test hook: every id said, in order

func _ready() -> void:
	_pick.rng.randomize()
	_sim = get_parent()
	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_voice.volume_db = VOICE_DB
	add_child(_voice)
	_voice.finished.connect(func() -> void: _cur_priority = -1)
	if _sim == null or not _sim.has_signal("cart_wrecked"):
		return
	_sim.cart_wrecked.connect(func(_l: int, cause: String) -> void:
		if cause == "boulder":
			say("boulder_smash"))
	_sim.obstacle_hit.connect(func(_h: int) -> void: say("hit"))
	_sim.zip_caught.connect(func(_i: int) -> void: say("zip_catch"))
	_sim.archer_down.connect(_on_archer_down)
	_sim.dry_fire.connect(func() -> void: say("dry"))
	_sim.reload_started.connect(func() -> void: say("reload"))
	_sim.hop_blocked.connect(func(_l: int) -> void: say("hop_blocked"))
	_sim.cart_spawned.connect(func(_l: int) -> void: say("cart_spawn"))
	_sim.rider_bailed.connect(func(_a: int, _b: int) -> void: _bail_t = _now)
	_sim.gold_collected.connect(_on_gold)

func _on_gold(_total: int) -> void:
	_coins += 1
	if _coins % COIN_EVERY == 0:
		say("coin_streak")

func _stream(id: String) -> AudioStream:
	if not _streams.has(id):
		var path: String = Bank.DIR + id + ".mp3"
		_streams[id] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[id]

## Say one line of `cat` if the category may speak now. Returns the id said ("" = held back).
func say(cat: String) -> String:
	if not Bank.CATEGORIES.has(cat) or not is_inside_tree():
		return ""
	if not may_speak(cat, _now, _last_by_cat, _cur_priority if _voice.playing else -1):
		return ""
	var id: String = _pick.next(cat, Bank.CATEGORIES[cat]["ids"])
	if id == "":
		return ""
	_last_by_cat[cat] = _now
	_cur_priority = int(Bank.CATEGORIES[cat]["priority"])
	spoken.append(id)
	var s: AudioStream = _stream(id)
	if s:
		_voice.stream = s
		_voice.play()
	return id

func _on_archer_down(id: String) -> void:
	say("bear_down")
	var p: AudioStreamPlayer3D = _bear_players.get(id)
	if p:
		var fall: AudioStream = _fx("ep2_bear_fall")
		if fall:
			p.stream = fall
			p.volume_db = 0.0
			p.play()
	_bear_next.erase(id)

func _fx(id: String) -> AudioStream:
	if not _bear_fx.has(id):
		var path: String = BEAR_DIR + id + ".mp3"
		_bear_fx[id] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _bear_fx[id]

func _process(delta: float) -> void:
	_now += delta
	if _sim == null or not _sim.has_method("is_running") or not _sim.is_running():
		return
	var d: float = _sim.get_distance()
	# Hopping to another cart = celebration (unless a wreck bailed him out).
	var lane: int = _sim.get_lane()
	if _lane >= 0 and lane != _lane and _now - _bail_t > 0.4 and not _sim.is_ziplining():
		say("hop_success")
	_lane = lane
	# Landing a jump = celebration too.
	var airborne: bool = float(_sim.get_cart_y()) > 0.35 and not _sim.is_ziplining()
	if _was_airborne and not airborne and not _sim.is_ziplining():
		say("jump_clear")
	_was_airborne = airborne
	if _sim.is_ducking() and not _announced.has("duck_%d" % int(d / 12.0)):
		_announced["duck_%d" % int(d / 12.0)] = true
		say("duck")
	var obstacles: Array = _sim.get_obstacles()
	for i in obstacles.size():
		var o: Dictionary = obstacles[i]
		var ahead: float = float(o.get("z", 0.0)) - d
		if ahead >= 0.0 and ahead <= BOULDER_WARN and str(o.get("type", "")) == "boulder" and not _announced.has("b%d" % i):
			_announced["b%d" % i] = true
			say("boulder_warning")
	_update_bears(d)

## Each living bear grumbles from its ledge; quiet far away, louder as we close in.
func _update_bears(d: float) -> void:
	for a in _sim.get_archers():
		var ad: Dictionary = a
		var id: String = str(ad.get("id", ""))
		if not bool(ad.get("alive", false)):
			continue
		var ahead: float = float(ad.get("z", 0.0)) - d
		if ahead < -6.0 or ahead > BEAR_HEAR:
			continue
		var p: AudioStreamPlayer3D = _bear_players.get(id)
		if p == null:
			p = AudioStreamPlayer3D.new()
			p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
			p.unit_size = 14.0
			p.max_distance = BEAR_HEAR + 4.0
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
			add_child(p)
			_bear_players[id] = p
			_bear_next[id] = _now + randf_range(0.2, 1.2)
			if not _announced.has("sight_" + id) and ahead <= BEAR_SIGHT:
				_announced["sight_" + id] = true
				say("bear_sighted")
		p.global_position = _sim.archer_world_pos(ad)
		if _bear_next.has(id) and _now >= float(_bear_next[id]) and not p.playing:
			var first: bool = not _announced.has("roar_" + id)
			var sid: String = "ep2_bear_roar" if first and ahead < BEAR_HEAR * 0.7 else str(BEAR_GROWLS[randi() % BEAR_GROWLS.size()])
			if first and sid == "ep2_bear_roar":
				_announced["roar_" + id] = true
			var s: AudioStream = _fx(sid)
			if s:
				p.stream = s
				p.volume_db = bear_db(maxf(ahead, 1.0)) * 0.35
				p.play()
			_bear_next[id] = _now + randf_range(2.6, 5.0)
