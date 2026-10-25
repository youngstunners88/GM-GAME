extends Node
## EP2 AUDIO MIX (founder 2026-10-25: "people VO overshadowed by music" and "train inaudible when it passes").
##  * The music stays DOWN under a line even while a track is fading in (the forest -> town crossfade used to tween it back to full
##    over the words), and when a new line starts during the restore after the last one.
##  * A townsperson's passing greeting (3D, not the announcer slot) dips the music too, and the recorded town takes get +2.5 dB.
##  * The town's train has a sound: a looping steam run on the locomotive and a whistle, heard across the river (the track is ~106 m
##    from mid-street), silent in a room built off-screen, dipping under speech.
## Run: godot --headless res://tests/ep2_audio_mix_test.tscn

var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	print("EP2 AUDIO MIX:")
	var am: Node = get_node("/root/AudioManager")
	var forest := "res://src/assets/music/ep2_deep_mining3_quad.ogg"
	var theme := "res://src/assets/music/ep2_deep_mining_theme.mp3"
	am.play_track_from(forest, 0.0, 0.0)
	await get_tree().process_frame
	# ---- a line that starts as the next track begins its 4 s fade-in
	am.crossfade_music(theme, 4.0)
	am.play_voice("vo_bull_plan1")
	await _wait(1.2)
	var mp: AudioStreamPlayer = am.current_music_player
	check("the town track fading in is held under the line (1.2 s in)", mp != null and mp.volume_db <= -10.0, "%.1f dB" % (mp.volume_db if mp else 99.0))
	await _wait(2.2)
	check("...and still under it when the old fade would have reached full (3.4 s in)", mp.volume_db <= -10.0, "%.1f dB" % mp.volume_db)
	# ---- the speech ends; a new line starts while the music is on its way back up
	am._on_voice_finished()
	await _wait(AudioManager.VOICE_RESTORE_GRACE + 0.15)
	am.play_voice("vo_bull_plan2")
	await _wait(0.5)
	check("a line that starts during the restore pulls the music straight back down", mp.volume_db <= -10.0, "%.1f dB" % mp.volume_db)
	am._on_voice_finished()
	await _wait(AudioManager.VOICE_RESTORE_GRACE + 0.9)
	check("after the last line (+grace) the music returns to full", mp.volume_db > -3.0 and not am.is_speech_ducking(), "%.1f dB" % mp.volume_db)
	# ---- recorded town takes are lifted; greetings duck the music
	var take: AudioStream = load("res://src/episode2/extras/audio/town/town_greet_lady_0.ogg") if ResourceLoader.exists("res://src/episode2/extras/audio/town/town_greet_lady_0.ogg") else null
	if take != null:
		am.play_voice("town_greet_lady_0", take)
		check("a recorded town take plays +2.5 dB over unity (all takes peak <= -2.8 dBTP)", is_equal_approx(am._voice_player.volume_db, AudioManager.TOWN_TAKE_GAIN_DB))
		am._on_voice_finished()
		await _wait(AudioManager.VOICE_RESTORE_GRACE + 0.9)
	am.duck_for_speech(1.0, -10.0)
	await _wait(0.4)
	check("a townsperson's greeting dips the music under it", mp.volume_db <= -8.0 and am.is_speech_ducking(), "%.1f dB" % mp.volume_db)
	await _wait(1.0 + AudioManager.VOICE_RESTORE_GRACE + 0.8)
	check("...and lets it back up after the greeting", mp.volume_db > -3.0 and not am.is_speech_ducking(), "%.1f dB" % mp.volume_db)
	var scape := Ep2TownSoundscape.new()
	add_child(scape)
	check("greetings carry: unity gain, full level within 8 m", is_equal_approx(scape._greeting.volume_db, 0.0) and is_equal_approx(scape._greeting.unit_size, 8.0))
	scape.queue_free()

	# ---- the train
	print("-- the train")
	var world := Node3D.new()
	add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0.0, 1.6, 1440.0)          # mid-street
	cam.current = true
	Ep2TownLife.build(world, [])
	var life: Ep2TownLife = world.get_node("TownLife") as Ep2TownLife
	check("the train has a run sound and a whistle on it", life._run_sfx != null and life._whistle_sfx != null and life._run_sfx.get_parent() == life._train)
	life._wait = 0.0
	life._process(0.016)
	life._process(0.016)
	check("when the train comes into view its run sound plays (loaded from the extras)", life._train.visible and life._run_sfx.playing and life._run_sfx.stream != null)
	check("...a loop", life._run_sfx.stream is AudioStreamOggVorbis and (life._run_sfx.stream as AudioStreamOggVorbis).loop)
	var d: float = absf(Ep2GoldTown.TRACK_Z - cam.position.z)
	var at_street_db: float = life.TRAIN_RUN_DB + linear_to_db(life.TRAIN_UNIT_SIZE / d)
	check("it is clearly heard at mid-street (%.0f m): about %.1f dB before the mix, inside its range" % [d, at_street_db],
		at_street_db > -6.0 and d < life.TRAIN_MAX_DISTANCE)
	life._train_x = 149.0
	life._process(0.016)
	check("the whistle blows as it comes into view", life._whistle_sfx.playing)
	am.play_voice("vo_bull_plan3")
	for i in 30:
		life._process(1.0 / 60.0)
	check("under a line the train dips (it never buries speech)", life._run_sfx.volume_db < life.TRAIN_RUN_DB - 3.0, "%.1f dB" % life._run_sfx.volume_db)
	am._on_voice_finished()
	# a town built OFF-SCREEN (the next room, prebuilt in its own world) stays silent
	var vp := SubViewport.new()
	vp.own_world_3d = true
	add_child(vp)
	var off := Node3D.new()
	vp.add_child(off)
	Ep2TownLife.build(off, [])
	var life2: Ep2TownLife = off.get_node("TownLife") as Ep2TownLife
	life2._wait = 0.0
	life2._process(0.016)
	life2._process(0.016)
	check("a town built off-screen makes no train sound", life2._train.visible and not life2._run_sfx.playing)
	am.fade_out_music(0.01)
	print("EP2_AUDIO_MIX: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
