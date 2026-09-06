extends Node
## Regression gate: the boss-defeat cutscenes must MUTE the stage/boss music
## while their video (with its own baked-in VO) plays, then RESTORE it so the
## next stage's music is audible. Founder report: the stage music was playing
## over the cutscene VO and intersecting it.
##
## Proves, for all three cutscenes, without waiting the full ~15s each:
##   1. before play(): Music bus not muted
##   2. during play(): Music bus muted
##   3. after _finish(): Music bus restored (not muted)
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/cutscene_music_mute_test.tscn

const CUTSCENES := {
	"stage1": "res://src/level/stage1_boss_defeat_cutscene.gd",
	"stage2": "res://src/level/stage2_boss_defeat_cutscene.gd",
	"stage3": "res://src/level/stage3_boss_defeat_cutscene.gd",
}

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("CUTSCENE MUSIC MUTE:")
	var music_bus := AudioServer.get_bus_index("Music")
	_check("Music bus exists", music_bus >= 0, "no 'Music' bus registered")
	if music_bus < 0:
		get_tree().quit(1)
		return

	for name in CUTSCENES:
		var path: String = CUTSCENES[name]
		# Arrange: ensure the Music bus starts un-muted for a clean read.
		AudioServer.set_bus_mute(music_bus, false)
		var scene = load(path).new()
		add_child(scene)
		await get_tree().process_frame

		_check("%s: music not muted before play()" % name,
			not AudioServer.is_bus_mute(music_bus))

		# Act: start the cutscene (loads + plays the real video asset).
		scene.play()
		await get_tree().process_frame

		# Assert: music is silenced for the duration of the video.
		_check("%s: music MUTED during cutscene playback" % name,
			AudioServer.is_bus_mute(music_bus),
			"stage music would play over the cutscene VO")

		# Act: end the cutscene early (don't wait the full ~15s).
		scene._finish()
		await get_tree().process_frame

		# Assert: music restored so the next stage isn't left silent.
		_check("%s: music RESTORED after cutscene finishes" % name,
			not AudioServer.is_bus_mute(music_bus),
			"Music bus left muted after the cutscene")

	# Leave the bus in a clean state regardless.
	AudioServer.set_bus_mute(music_bus, false)
	print("CUTSCENE_MUSIC_MUTE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
