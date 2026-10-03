extends Node
## Episode 2 runner soundscape — plays the VARCO stems from
## artifacts/episode2-gold-mine/audio/prompts/runner.json once they are promoted to
## src/episode2/assets/audio/<stem_id>.wav (skill: gm-game-varco-ep2).
##
## Reads the sim (the parent RunnerGraybox) and never writes to it, same contract
## as runner_view.gd. A missing WAV is a content hole: that slot stays silent, no error.
## Buses: score drone -> Music, everything else -> SFX (Master if a bus is absent).
## The gun layer (shot / reload / dry / bear hit) stays in runner_view.gd.

const AUDIO_DIR := "res://src/episode2/assets/audio/"

## stem id -> [bus, loop]
const STEMS := {
	"ep2_runner_bed_mine_loop_01": ["SFX", true],
	"ep2_runner_cart_rails_loop_01": ["SFX", true],
	"ep2_runner_score_drone_loop_01": ["Music", true],
	"ep2_runner_zipline_rush_01": ["SFX", false],
	"ep2_runner_duck_01": ["SFX", false],
	"ep2_runner_jump_land_01": ["SFX", false],
	"ep2_runner_arrow_flyby_01": ["SFX", false],
	"ep2_runner_arrow_flyby_02": ["SFX", false],
	"ep2_runner_boulder_roll_01": ["SFX", false],
	"ep2_runner_bear_distant_01": ["SFX", false],
	# v2 — cart attrition layer (2026-09-27).
	"ep2_runner_cart_smash_01": ["SFX", false],
	"ep2_runner_cart_spawn_01": ["SFX", false],
	"ep2_runner_gold_pickup_01": ["SFX", false],
	"ep2_runner_hop_blocked_01": ["SFX", false],
	# 2026-10-03: a LOUD rush for the whole ride (loops while hooked on the cable; the rail loop is off then).
	"ep2_runner_zipline_rush_loop_02": ["SFX", true],
}

## ElevenLabs takes used when a slot has no promoted VARCO WAV (VARCO ran out
## of credits 2026-09-27) — or, for the coin, INSTEAD of it: the coins are
## Bitcoin-branded now and the VARCO "nugget in a glove" take doesn't fit.
const ELEVEN := "res://src/assets/sounds/"
const FALLBACK := {
	"ep2_runner_hop_blocked_01": "ep2_runner_hop_blocked.mp3",
	"ep2_runner_cart_smash_01": "ep2_cart_smash.mp3",
	"ep2_runner_cart_spawn_01": "ep2_cart_spawn.mp3",
}
const PREFER := {
	"ep2_runner_gold_pickup_01": "ep2_bitcoin_coin.mp3",
	"ep2_runner_zipline_rush_loop_02": "ep2_zipline_rush_loud.mp3",
}

## THE REVOLVER (founder 2026-10-03: "it's a fucking REVOLVER" and it fired silent). Every shot plays a hammer
## click and a full report with its tunnel echo, from a small pool so a volley overlaps instead of cutting itself
## off. Normalised to -1 dB peak; +4 dB on top. Wired HERE (not only in the view) so the sim's shot_fired signal is
## the single trigger and a test can see it.
const GUN_BLASTS := ["ep2_revolver_blast_1.mp3", "ep2_revolver_blast_2.mp3", "ep2_revolver_blast_3.mp3"]
const GUN_HAMMER := "ep2_revolver_hammer.mp3"
const GUN_POOL := 6
const GUN_DB := 4.0

## Mix levels in dB; beds sit under the action.
const VOLUME_DB := {
	"ep2_runner_bed_mine_loop_01": -10.0,
	"ep2_runner_cart_rails_loop_01": -8.0,
	"ep2_runner_score_drone_loop_01": -14.0,
	"ep2_runner_zipline_rush_loop_02": 5.0,       # the rail loop sits at -8 dB: the cable is clearly the loudest thing
	"ep2_runner_zipline_rush_01": 6.0,
}

## How far ahead (metres) a hazard is announced.
const ARROW_LEAD := 10.0
const BOULDER_LEAD := 28.0
const BEAR_LEAD := 40.0
const LAND_HEIGHT := 0.35

var _sim: Node
var _players: Dictionary = {}
var _announced: Dictionary = {}
var _arrow_flip: bool = false
var _was_ducking: bool = false
var _was_airborne: bool = false
var _was_running: bool = false
var _gun_players: Array = []
var _gun_next: int = 0
var _hammer: AudioStreamPlayer = null
var shots_played: int = 0          # test hook: how many report samples were started

func _ready() -> void:
	_sim = get_parent()
	for id in STEMS:
		var p := AudioStreamPlayer.new()
		var bus: String = str(STEMS[id][0])
		p.bus = bus if AudioServer.get_bus_index(bus) != -1 else "Master"
		p.volume_db = float(VOLUME_DB.get(id, 0.0))
		var path: String = AUDIO_DIR + str(id) + ".wav"
		if PREFER.has(id) and ResourceLoader.exists(ELEVEN + str(PREFER[id])):
			path = ELEVEN + str(PREFER[id])
		elif not ResourceLoader.exists(path) and FALLBACK.has(id):
			path = ELEVEN + str(FALLBACK[id])
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path) as AudioStream
			if bool(STEMS[id][1]):
				_make_loop(s, p)
			p.stream = s
		add_child(p)
		_players[id] = p
	_build_gun_layer()
	if _sim and _sim.has_signal("shot_fired"):
		_sim.shot_fired.connect(_on_shot_fired)
	if _sim and _sim.has_signal("zip_caught"):
		_sim.zip_caught.connect(func(_i: int) -> void: _play("ep2_runner_zipline_rush_01"))
	if _sim and _sim.has_signal("cart_wrecked"):
		_sim.cart_wrecked.connect(func(_l: int, _c: String) -> void: _play("ep2_runner_cart_smash_01"))
		_sim.cart_spawned.connect(func(_l: int) -> void: _play("ep2_runner_cart_spawn_01"))
		_sim.gold_collected.connect(func(_n: int) -> void: _play("ep2_runner_gold_pickup_01"))
		_sim.hop_blocked.connect(func(_l: int) -> void: _play("ep2_runner_hop_blocked_01"))

func _sfx_bus() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

func _build_gun_layer() -> void:
	for i in GUN_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = _sfx_bus()
		p.volume_db = GUN_DB
		var f: String = ELEVEN + str(GUN_BLASTS[i % GUN_BLASTS.size()])
		if ResourceLoader.exists(f):
			p.stream = load(f) as AudioStream
		add_child(p)
		_gun_players.append(p)
	_hammer = AudioStreamPlayer.new()
	_hammer.bus = _sfx_bus()
	_hammer.volume_db = 2.0
	if ResourceLoader.exists(ELEVEN + GUN_HAMMER):
		_hammer.stream = load(ELEVEN + GUN_HAMMER) as AudioStream
	add_child(_hammer)

## Hammer first, then the report a hair later (the click is what you hear the instant you press the button).
func _on_shot_fired() -> void:
	if _hammer and _hammer.stream:
		_hammer.play()
	if _gun_players.is_empty():
		return
	var p: AudioStreamPlayer = _gun_players[_gun_next % _gun_players.size()]
	_gun_next += 1
	if p.stream == null:
		return
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
	shots_played += 1

## Loop a 10 s VARCO take in Godot (the skill's fallback when the API loop is absent).
func _make_loop(s: AudioStream, p: AudioStreamPlayer) -> void:
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
		return
	var w := s as AudioStreamWAV
	if w and w.format == AudioStreamWAV.FORMAT_16_BITS:
		var frame_bytes: int = 2 * (2 if w.stereo else 1)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / frame_bytes
	else:
		p.finished.connect(p.play)

func _play(id: String) -> void:
	var p: AudioStreamPlayer = _players.get(id)
	if p and p.stream and p.is_inside_tree():
		p.play()

func _set_bed(id: String, on: bool) -> void:
	var p: AudioStreamPlayer = _players.get(id)
	if p == null or p.stream == null:
		return
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()

func _process(_delta: float) -> void:
	if _sim == null or not _sim.has_method("is_running"):
		return
	var running: bool = _sim.is_running()
	if running and not _was_running:
		_announced.clear()
	_was_running = running
	var zipping: bool = _sim.is_ziplining()
	_set_bed("ep2_runner_bed_mine_loop_01", running)
	_set_bed("ep2_runner_score_drone_loop_01", running)
	_set_bed("ep2_runner_cart_rails_loop_01", running and not zipping)
	_set_bed("ep2_runner_zipline_rush_loop_02", running and zipping)
	if not running:
		return

	var ducking: bool = _sim.is_ducking()
	if ducking and not _was_ducking:
		_play("ep2_runner_duck_01")
	_was_ducking = ducking

	var airborne: bool = float(_sim.get_cart_y()) > LAND_HEIGHT and not zipping
	if _was_airborne and not airborne and not zipping:
		_play("ep2_runner_jump_land_01")
	_was_airborne = airborne

	var d: float = _sim.get_distance()
	var obstacles: Array = _sim.get_obstacles()
	for i in obstacles.size():
		var o: Dictionary = obstacles[i]
		var ahead: float = float(o.get("z", 0.0)) - d
		var key: String = "o%d" % i
		if ahead < 0.0 or _announced.has(key):
			continue
		var t: String = str(o.get("type", ""))
		if t == "arrow" and ahead <= ARROW_LEAD:
			_announced[key] = true
			_arrow_flip = not _arrow_flip
			_play("ep2_runner_arrow_flyby_01" if _arrow_flip else "ep2_runner_arrow_flyby_02")
		elif t == "boulder" and ahead <= BOULDER_LEAD:
			_announced[key] = true
			_play("ep2_runner_boulder_roll_01")

	var archers: Array = _sim.get_archers()
	for a in archers:
		var ad: Dictionary = a
		var key: String = "a" + str(ad.get("id", ""))
		var ahead: float = float(ad.get("z", 0.0)) - d
		if bool(ad.get("alive", false)) and ahead >= 0.0 and ahead <= BEAR_LEAD and not _announced.has(key):
			_announced[key] = true
			_play("ep2_runner_bear_distant_01")
