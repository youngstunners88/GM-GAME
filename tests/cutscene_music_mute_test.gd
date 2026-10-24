extends Node
## Regression gate: the boss-defeat cutscenes must MUTE the stage/boss music
## while their video (with its own baked-in VO) plays, then RESTORE it so the
## next stage's music is audible. Founder report: the stage music was playing
## over the cutscene VO and intersecting it.
##
## Proves, for the Stage 1 and Stage 2 cutscenes, without waiting the full ~15s each:
##   1. before play(): Music bus not muted
##   2. during play(): Music bus muted
##   3. after _finish(): Music bus restored (not muted)
##
## STAGE 3 (the hand-off into Episode 2) no longer mutes the bus (2026-10-22 mobile transitions audit F06): a muted bus
## kept the boss theme playing silently for the whole film and it re-entered mid-song when the bus was unmuted. The stage
## music now leaves with AudioManager.fade_out_music (the bosses call it at the top of die(); play() repeats it so the film
## is correct on its own). For stage 3 this test proves: the bus is NEVER muted, the stage track is faded out and its
## playlist emptied during the film, and nothing starts music again when the film finishes (no blip).
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

		if name == "stage3":
			await _stage3_fades_instead_of_muting(scene, music_bus)
			continue

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
	AudioManager.fade_out_music(0.01)
	print("CUTSCENE_MUSIC_MUTE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## Stage 3: a stage track is playing, the film starts, the film ends.
func _stage3_fades_instead_of_muting(scene: Node, music_bus: int) -> void:
	var am: Node = get_node("/root/AudioManager")
	am.play_playlist(["res://src/assets/music/boss03_theme.ogg", "res://src/assets/music/boss03_theme_alt.ogg"], true, 0.1)
	await get_tree().process_frame
	_check("stage3: a stage track is playing before the film", am.current_music_player != null and am.current_music_player.playing)
	scene.play()
	await get_tree().process_frame
	_check("stage3: the Music bus is NOT muted during the film (it fades the track, it does not mute the bus)",
		not AudioServer.is_bus_mute(music_bus), "a muted bus keeps the boss theme running silently and it re-enters at film end")
	_check("stage3: the stage track is faded out and its playlist emptied during the film",
		am.current_music_player == null and am._playlist.is_empty())
	scene._finish()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("stage3: the Music bus is still not muted after the film", not AudioServer.is_bus_mute(music_bus))
	_check("stage3: finishing the film starts NO music again (no boss-theme blip)",
		am.current_music_player == null and am._playlist.is_empty())
