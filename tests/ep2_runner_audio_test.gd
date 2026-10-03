extends Node
## Gate for runner_audio.gd (VARCO stems, skill gm-game-varco-ep2): missing WAVs are
## silent holes, a present loop stem is set to loop, and hazards are announced once.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_audio_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	var r: Node3D = SCENE.instantiate()
	add_child(r)
	r.set_physics_process(false)
	var audio: Node = r.get_node_or_null("Audio")
	_check("Audio node present in runner scene", audio != null)
	if audio == null:
		_finish()
		return
	_check("one player per runner.json stem", audio._players.size() == audio.STEMS.size() and audio.STEMS.size() >= 14, str(audio._players.size()))
	for id in audio._players:
		var p: AudioStreamPlayer = audio._players[id]
		var path: String = audio.AUDIO_DIR + str(id) + ".wav"
		var any_src: bool = ResourceLoader.exists(path) \
			or (audio.FALLBACK.has(id) and ResourceLoader.exists(audio.ELEVEN + str(audio.FALLBACK[id]))) \
			or (audio.PREFER.has(id) and ResourceLoader.exists(audio.ELEVEN + str(audio.PREFER[id])))
		_check("%s stream matches source presence" % id, (p.stream != null) == any_src)
		var want: String = "Music" if id == "ep2_runner_score_drone_loop_01" else "SFX"
		_check("%s on %s bus" % [id, want], p.bus == want or (p.bus == "Master" and AudioServer.get_bus_index(want) == -1), p.bus)
		if p.stream is AudioStreamWAV and bool(audio.STEMS[id][1]):
			var w: AudioStreamWAV = p.stream
			_check("%s loops" % id, w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end > 0)
	r.setup(200.0, [{"z": 20.0, "lane": 1, "type": "arrow"}, {"z": 30.0, "lane": 0, "type": "boulder"}], [], [{"id": "b1", "z": 35.0, "side": 1}], true)
	audio._process(0.016)
	_check("bear announced at d=0 (within 40 m)", audio._announced.size() == 1, str(audio._announced))
	while r.get_distance() < 12.0 and r.is_running():
		r.step(0.05)
	audio._process(0.016)
	_check("arrow/boulder/bear announced once each", audio._announced.size() == 3, str(audio._announced))
	audio._process(0.016)
	_check("no re-announce", audio._announced.size() == 3)

	# THE REVOLVER IS AUDIBLE (founder 2026-10-03): every shot starts a hammer click and a report sample, and a
	# volley overlaps instead of cutting itself off.
	for f in audio.GUN_BLASTS:
		var st: AudioStream = load(audio.ELEVEN + str(f)) as AudioStream
		_check("%s loads and is a real sample" % f, st != null and st.get_length() > 1.0)
	_check("revolver pool built", audio._gun_players.size() == audio.GUN_POOL and audio._hammer != null and audio._hammer.stream != null)
	r.setup(200.0, [], [], [], true)
	var before: int = audio.shots_played
	r.shot_fired.emit()
	r.shot_fired.emit()
	r.shot_fired.emit()
	_check("three shots start three report samples", audio.shots_played == before + 3, str(audio.shots_played))
	var playing: int = 0
	for gp in audio._gun_players:
		if (gp as AudioStreamPlayer).playing:
			playing += 1
	_check("they overlap (volley does not cut itself off)", playing >= 2, str(playing))
	_check("the report is louder than +0 dB", audio._gun_players[0].volume_db >= 3.0)

	# THE ZIPLINE IS LOUD: a looping cable rush, louder than the rail loop, only while hooked.
	var zp: AudioStreamPlayer = audio._players.get("ep2_runner_zipline_rush_loop_02")
	_check("zipline rush loop player exists with a stream", zp != null and zp.stream != null)
	_check("zipline rush loops", zp != null and zp.stream is AudioStreamMP3 and (zp.stream as AudioStreamMP3).loop)
	_check("zipline rush is much louder than the rail loop", zp != null and zp.volume_db >= audio.VOLUME_DB["ep2_runner_cart_rails_loop_01"] + 10.0)
	_finish()

func _finish() -> void:
	print("ALL PASS" if _fail == 0 else "FAILURE: %d" % _fail)
	get_tree().quit(1 if _fail else 0)
