class_name Ep2TownSoundscape
extends Node3D
## Recorded ambient life; one nearby greeting at a time. No bell in ambience.
signal bell_rung
const ROOT := "res://src/episode2/extras/audio/town/"
var _celebration: AudioStreamPlayer
var _celebration_left: float = 0.0
var _wind: AudioStreamPlayer
var _saloon: AudioStreamPlayer3D
var _greeting: AudioStreamPlayer3D
var _bell: AudioStreamPlayer3D
var _boots: AudioStreamPlayer3D
var _people_bed: AudioStreamPlayer3D
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_next: int = 0
var _spur_cd: float = 4.0
var _rng := RandomNumberGenerator.new()
var effect_counts: Dictionary = {}
var active := false
var quiet := false
var story_busy := false
var _greet_cd := 0.0
var _foot_cd := 0.0
var _queued: Array[String] = []
var bell_count := 0
## How far the music dips under a passing greeting (a story line ducks it further, to AudioManager.VOICE_DUCK_DB).
const GREETING_MUSIC_DUCK_DB := -10.0

func _ready() -> void:
	_rng.seed = 18861027
	_wind = AudioStreamPlayer.new()
	_wind.bus = "SFX"
	_wind.stream = _effect("town_wind", true)
	_wind.volume_db = -16.0
	add_child(_wind)
	_saloon = _spatial("town_saloon", -10.0, 24.0, true)
	_saloon.position = Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0, 1.5, -5))
	_people_bed = _spatial("town_people_loop", -25.0, 46.0, true)
	_people_bed.position = Vector3(0.0, 1.4, 1425.0)
	_people_bed.unit_size = 13.0                       # a quiet street bed, never a wall of chatter over a line
	# A greeting must read over the town theme (founder 2026-10-25: "people VO overshadowed by music"): unity gain, a wider
	# unit size (full level within 8 m instead of 5), heard to 18 m, and the music dips under it while it plays (greet()).
	_greeting = _spatial("", 0.0, 18.0)
	_greeting.unit_size = 8.0
	_bell = _spatial("town_draw_bell", 5.0, 180.0)
	_bell.position = Vector3(0.0, 10.0, 1478.0)
	_bell.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_boots = _spatial("town_boardwalk", -14.0, 10.0)
	for i in 12:
		_voices.append(_spatial("", -12.0, 20.0))

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
	if _people_bed.stream != null: _people_bed.play()


func _speech_ducked() -> bool:
	if story_busy or quiet:
		return true
	var am: Node = get_node_or_null("/root/AudioManager")
	return am != null and am.has_method("is_speech_ducking") and bool(am.call("is_speech_ducking"))


## Play one recorded town effect at a world position. A small round-robin pool keeps laughs, glass, bumps and
## spurs spatial and bounded; every one dips under speech just as the train does. False means not active/no recording.
func play_effect(id: String, at: Vector3, db: float = -12.0, distance: float = 20.0) -> bool:
	if not active or _voices.is_empty():
		return false
	var stream: AudioStream = _effect(id)
	if stream == null:
		return false
	var p: AudioStreamPlayer3D = _voices[_voice_next]
	_voice_next = (_voice_next + 1) % _voices.size()
	p.stop()
	p.stream = stream
	p.position = at
	p.max_distance = distance
	p.set_meta("base_db", db)
	p.volume_db = db - (10.0 if _speech_ducked() else 0.0)
	p.play()
	effect_counts[id] = int(effect_counts.get(id, 0)) + 1
	return true


func step(delta: float, people: Ep2TownPeople, player: Vector3, busy: bool, duel: bool) -> void:
	story_busy = busy
	quiet = duel
	_greet_cd = maxf(0.0, _greet_cd - delta)
	_foot_cd = maxf(0.0, _foot_cd - delta)
	_spur_cd = maxf(0.0, _spur_cd - delta)
	if busy or duel: silence_greeting()
	if _wind != null: _wind.volume_db = -24.0 if busy or duel else -16.0
	if _saloon != null: _saloon.volume_db = -28.0 if busy or duel else -10.0
	if _people_bed != null: _people_bed.volume_db = -36.0 if busy or duel else -25.0
	var ducked: bool = _speech_ducked()
	for voice in _voices:
		if voice.playing:
			var base: float = float(voice.get_meta("base_db", -12.0))
			voice.volume_db = move_toward(voice.volume_db, base - (10.0 if ducked else 0.0), 35.0 * delta)
	if not active or people == null: return
	for person in people.people:
		var events: Array = person.drink_events.duplicate()
		person.drink_events.clear()
		if duel: continue
		for event in events:
			var kind: String = str(event.get("kind", ""))
			var at: Vector3 = event.get("at", person.folk.position)
			match kind:
				"laugh":
					var id: String = "woman_laugh" if bool(event.get("female", false)) else ("man_laugh_b" if int(event.get("variant", 0)) == 1 else "man_laugh_a")
					if int(event.get("variant", 0)) == 2: id = "saloon_laughter"
					play_effect(id, at, -15.0, 22.0)
				"clink": play_effect("bar_glasses_clink", at, -18.0, 17.0)
				"exhale": play_effect("cigar_exhale", at, -23.0, 12.0)
	if duel: return
	if _foot_cd <= 0.0:
		for person in people.people:
			if person.state == "walk" and person.folk.position.distance_to(player) < 8.0:
				if _boots.stream != null:
					_boots.position = person.folk.position
					_boots.play()
				_foot_cd = 0.65
				break
	# Only some of the men wear audible spurs, and only now and then - never another sound on every boot step.
	if _spur_cd <= 0.0:
		_spur_cd = _rng.randf_range(5.0, 11.0)
		for person in people.people:
			if person.state == "walk" and Ep2TownPeople.sex_of(person.id) == "m" and int(person.id.hash()) % 3 == 0 \
					and person.folk.position.distance_to(player) < 7.0 and _rng.randf() < 0.45:
				play_effect("spurs_jingle", person.folk.position + Vector3(0.0, 0.25, 0.0), -18.0, 13.0)
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
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("duck_for_speech"):
		am.duck_for_speech(recording.get_length(), GREETING_MUSIC_DUCK_DB)
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

## Story celebration has a dedicated non-positional lane: pooled footsteps and
## greetings cannot steal it, and the listener's distance cannot attenuate it.
func play_celebration() -> bool:
	if not active: return false
	if _celebration == null:
		_celebration = AudioStreamPlayer.new()
		_celebration.bus = "SFX"
		_celebration.stream = _effect("crowd_cheer")
		_celebration.volume_db = 2.0
		add_child(_celebration)
	if _celebration.stream == null: return false
	_celebration_left = 14.0
	_celebration.play()
	effect_counts["crowd_cheer"] = int(effect_counts.get("crowd_cheer",0))+1
	return true

func _process(delta: float) -> void:
	if _celebration_left <= 0.0: return
	_celebration_left -= delta
	if _celebration_left <= 0.0:
		_celebration.stop()
	elif not _celebration.playing:
		_celebration.play()
