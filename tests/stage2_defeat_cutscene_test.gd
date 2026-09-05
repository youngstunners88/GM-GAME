extends Node
## Gate for src/level/stage2_boss_defeat_cutscene.gd — a real Seedance-
## generated Ogg Theora+Vorbis video. Proves the video actually decodes,
## plays for close to its real duration, and produces non-silent audio
## activity on the AudioServer bus.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/stage2_defeat_cutscene_test.tscn

const CUTSCENE := preload("res://src/level/stage2_boss_defeat_cutscene.gd")
const VIDEO_PATH := "res://src/assets/video/cutscenes/stage2_boss_defeat.ogv"

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("STAGE2 DEFEAT CUTSCENE:")
	_check("video asset exists on disk", ResourceLoader.exists(VIDEO_PATH))
	await _run_normal()
	print("STAGE2_DEFEAT_CUTSCENE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _run_normal() -> void:
	var cutscene: CanvasLayer = CUTSCENE.new()
	add_child(cutscene)
	var start_ms := Time.get_ticks_msec()

	var master_bus := AudioServer.get_bus_index("Master")
	var saw_audio_activity := false

	cutscene.play()

	while is_instance_valid(cutscene):
		if master_bus != -1:
			var peak_l: float = AudioServer.get_bus_peak_volume_left_db(master_bus, 0)
			if peak_l > -60.0:
				saw_audio_activity = true
		await get_tree().create_timer(0.3, true, false, true).timeout

	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	_check("finishes", true)
	_check("ran close to the video's real ~15s duration (took %.1fs)" % elapsed,
		elapsed > 10.0 and elapsed < 22.0,
		"took %.1fs — too short means it degraded instead of actually playing; too long means the 20s hard deadline fired" % elapsed)
	_check("AudioServer registered non-silent activity while the video played", saw_audio_activity,
		"peak level never rose above -60dB — the embedded audio track may not be decoding/mixing")

	await get_tree().process_frame
	await get_tree().process_frame
	_check("frees itself after finishing", not is_instance_valid(cutscene))
