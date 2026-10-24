class_name Ep2TownSoundscape
extends Node3D
## Recorded ambient life; one nearby greeting at a time. No bell in ambience.
signal bell_rung
const ROOT := "res://src/episode2/extras/audio/town/"
var _wind: AudioStreamPlayer
var _saloon: AudioStreamPlayer3D
var _greeting: AudioStreamPlayer3D
var _bell: AudioStreamPlayer3D
var _boots: AudioStreamPlayer3D
var active := false
var quiet := false
var story_busy := false
var _greet_cd := 0.0
var _foot_cd := 0.0
var _queued: Array[String] = []
var bell_count := 0

func _ready() -> void:
	_wind = AudioStreamPlayer.new()
	_wind.bus = "SFX"
	_wind.stream = _effect("town_wind", true)
	_wind.volume_db = -16.0
	add_child(_wind)
	_saloon = _spatial("town_saloon", -10.0, 24.0, true)
	_saloon.position = Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0, 1.5, -5))
	_greeting = _spatial("", -2.0, 14.0)
	_bell = _spatial("town_draw_bell", 5.0, 180.0)
	_bell.position = Vector3(0.0, 10.0, 1478.0)
	_bell.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_boots = _spatial("town_boardwalk", -14.0, 10.0)

func _effect(id: String, loop: bool = false) -> AudioStream:
	var path: String = ROOT + id + ".ogg"
	if not ResourceLoader.exists(path): return null
	var stream: AudioStream = load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	return stream

func _spatial(id: String, db: float, distance: float, loop: bool = false) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.volume_db = db
	p.max_distance = distance
	p.unit_size = 5.0
	if id != "": p.stream = _effect(id, loop)
	add_child(p)
	return p

func start() -> void:
	if active: return
	active = true
	if _wind.stream != null: _wind.play()
	if _saloon.stream != null: _saloon.play()

func step(delta: float, people: Ep2TownPeople, player: Vector3, busy: bool, duel: bool) -> void:
	story_busy = busy
	quiet = duel
	_greet_cd = maxf(0.0, _greet_cd - delta)
	_foot_cd = maxf(0.0, _foot_cd - delta)
	if busy or duel: silence_greeting()
	if _wind != null: _wind.volume_db = -24.0 if busy or duel else -16.0
	if _saloon != null: _saloon.volume_db = -28.0 if busy or duel else -10.0
	if not active or duel or _foot_cd > 0.0 or people == null: return
	for person in people.people:
		if person.state == "walk" and person.folk.position.distance_to(player) < 8.0:
			if _boots.stream != null:
				_boots.position = person.folk.position
				_boots.play()
			_foot_cd = 0.65
			break

func greet(person_id: String, actor: Ep2TownFolk, count: int) -> bool:
	if not active or quiet or story_busy or _greet_cd > 0.0 or not Ep2TownVoiceBank.GREETINGS.has(person_id): return false
	var choices: Array = Ep2TownVoiceBank.GREETINGS[person_id]
	var id: String = choices[(count - 1) % choices.size()]
	var recording: AudioStream = Ep2TownVoiceBank.stream(id)
	if recording == null: return false
	_greeting.position = actor.position + Vector3(0, actor.height_m * 0.85, 0)
	_greeting.stream = recording
	_greeting.play()
	_greet_cd = maxf(7.0, recording.get_length() + 3.0)
	return true

func silence_greeting() -> void:
	if _greeting != null and _greeting.playing: _greeting.stop()

func queue_line(id: String) -> void:
	if not Ep2TownVoiceBank.LINES.has(id): return
	if _queued.size() < 4 and (_queued.is_empty() or _queued[-1] != id): _queued.append(id)

func has_queued() -> bool:
	return not _queued.is_empty()

func take_line() -> String:
	return _queued.pop_front() if not _queued.is_empty() else ""

func ring_bell() -> bool:
	if _bell == null or _bell.stream == null: return false
	silence_greeting()
	_bell.play()
	bell_count += 1
	bell_rung.emit()
	return true
