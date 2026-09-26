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
}

## Mix levels in dB; beds sit under the action.
const VOLUME_DB := {
	"ep2_runner_bed_mine_loop_01": -10.0,
	"ep2_runner_cart_rails_loop_01": -8.0,
	"ep2_runner_score_drone_loop_01": -14.0,
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

func _ready() -> void:
	_sim = get_parent()
	for id in STEMS:
		var p := AudioStreamPlayer.new()
		var bus: String = str(STEMS[id][0])
		p.bus = bus if AudioServer.get_bus_index(bus) != -1 else "Master"
		p.volume_db = float(VOLUME_DB.get(id, 0.0))
		var path: String = AUDIO_DIR + str(id) + ".wav"
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path) as AudioStream
			if bool(STEMS[id][1]):
				_make_loop(s, p)
			p.stream = s
		add_child(p)
		_players[id] = p
	if _sim and _sim.has_signal("zip_caught"):
		_sim.zip_caught.connect(func(_i: int) -> void: _play("ep2_runner_zipline_rush_01"))

## Loop a 10 s VARCO take in Godot (the skill's fallback when the API loop is absent).
func _make_loop(s: AudioStream, p: AudioStreamPlayer) -> void:
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
