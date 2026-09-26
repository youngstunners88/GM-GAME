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
	_check("one player per runner.json stem", audio._players.size() == 10, str(audio._players.size()))
	for id in audio._players:
		var p: AudioStreamPlayer = audio._players[id]
		var path: String = audio.AUDIO_DIR + str(id) + ".wav"
		_check("%s stream matches file presence" % id, (p.stream != null) == ResourceLoader.exists(path))
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
	_finish()

func _finish() -> void:
	print("ALL PASS" if _fail == 0 else "FAILURE: %d" % _fail)
	get_tree().quit(1 if _fail else 0)
