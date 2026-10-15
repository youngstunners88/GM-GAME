extends Node
## Gate for the founder's three Episode 2 corrections of 2026-10-04:
##  1. "the song is supposed to continue and not start again" - the REAL finish path (`_finish`, which stops the
##     video) must hand the theme over at the film's position. VideoStreamPlayer.stop() rewinds to 0; reading the
##     position after it restarted the song from bar one (skill ep2-theme-song-handoff).
##  2. "the sound of the winchester is horrid ... needs to sound dangerous" - the FPS rifle fires the layered
##     Winchester samples on its own pool and racks the lever after each shot (skill ep2-winchester-sound).
##  3. "we still can't see his rifle or the whiskey glass" - after the film the Bull faces Lil Blunt, his own
##     Winchester is shoulder-carried (muzzle well above his hand).
##     Founder 2026-10-10 supersedes the glass-in-hand requirement: keep it on the table.
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_hideout_corrections_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("EP2 HIDEOUT CORRECTIONS:")
	await _song_continues()
	await _winchester()
	await _bull_props()
	print("EP2_HIDEOUT_CORRECTIONS: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)


func _song_continues() -> void:
	var F = SmeltingFacilityChamber
	var am: Node = get_node("/root/AudioManager")
	# A film that has been playing ~1.2 s, finished through the REAL path. Offset 0 so the song position must equal
	# the film position: the old code read the position after stop() and always got 0.
	var vf := Ep2VideoFilm.new()
	_check("the founder's film loads into the player", vf.prepare(F.FILM_VIDEO, F.FILM_SECONDS))
	vf.continue_track = F.STAGE_THEME
	vf.song_video_offset = 0.0
	add_child(vf)
	vf.start()
	var t_end: int = Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	vf.skip()                     # -> _finish(): reads the position, THEN stops the video
	await get_tree().process_frame
	_check("finishing hands over the film position, not 0 (song at %.2f s)" % vf.last_song_position,
		vf.last_song_position > 0.8)
	var pl: AudioStreamPlayer = am.current_music_player
	var pos: float = pl.get_playback_position() if pl else -1.0
	_check("the theme really plays from there (player at %.2f s)" % pos, pl != null and pl.playing and pos > 0.8)
	vf.queue_free()
	am.fade_out_music(0.01)
	await get_tree().create_timer(0.1).timeout
	# The founder's real numbers: the film ends at 60.83 s with the song at 34.30 s (waveform cross-correlation,
	# film 26.531 s == song 0 s, normalised correlation 0.99 over the film's last second).
	var vf2 := Ep2VideoFilm.new()
	vf2.prepare(F.FILM_VIDEO, F.FILM_SECONDS)
	vf2.continue_track = F.STAGE_THEME
	vf2.song_video_offset = F.FILM_SONG_OFFSET
	vf2.drive_externally()
	add_child(vf2)
	vf2._t = 60.83                # a full play-through, decoder clock unavailable -> wall clock fallback
	vf2.skip()
	await get_tree().process_frame
	_check("full film -> theme continues at 34.3 s (got %.2f)" % vf2.last_song_position,
		absf(vf2.last_song_position - 34.30) < 0.15)
	_check("the measured offset is the waveform-matched 26.53 s", absf(F.FILM_SONG_OFFSET - 26.531) < 0.02)
	vf2.queue_free()
	am.fade_out_music(0.01)
	await get_tree().create_timer(0.1).timeout


func _facility() -> Node:
	var f: Node = (load("res://src/episode2/chamber/smelting_facility.tscn") as PackedScene).instantiate()
	f.intro_film = false
	add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	return f


func _winchester() -> void:
	var F = SmeltingFacilityChamber
	for p in F.WINCHESTER_SHOTS + [F.WINCHESTER_LEVER]:
		var path: String = "res://src/assets/sounds/" + str(p)
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		_check("%s is in the build" % p, s != null)
		if s and str(p).begins_with("ep2_winchester_shot"):
			_check("...and has a real echo tail (%.2f s >= 2.0 s)" % s.get_length(), s.get_length() >= 2.0)
	var f: Node = _facility()
	await get_tree().process_frame
	f._on_video_film_finished()
	for i in 10:
		f.step(1.0 / 60.0)
	f._fire_fx()
	_check("a shot plays a Winchester sample", f.winchester_shots_played == 1)
	_check("...louder than the old play_sfx (%.0f dB)" % F.WINCHESTER_DB, F.WINCHESTER_DB >= 3.0)
	_check("...not yet the lever", f.winchester_levers_played == 0)
	for i in 40:
		f.step(1.0 / 60.0)
	_check("the lever racks after the shot", f.winchester_levers_played == 1)
	f._fire_fx()
	f._fire_fx()
	_check("rapid shots round-robin their own players (no cut-off echo)", f.winchester_shots_played == 3 and f._win_next == 3)
	f.queue_free()
	await get_tree().process_frame


func _bull_props() -> void:
	var f: Node = _facility()
	await get_tree().process_frame
	_check("glass is on the table while Bull is seated", f._glass_node.get_parent() == f._visuals)
	f._on_video_film_finished()
	var bull: Node3D = f._bull
	var to_hero: float = atan2(f._player_pos.x - bull.position.x, f._player_pos.z - bull.position.z)
	_check("after the film the Bull faces Lil Blunt (off by %.2f rad)" % absf(angle_difference(bull.facing, to_hero)),
		absf(angle_difference(bull.facing, to_hero)) < 0.3)
	# the lesson then sends him to the range (tests/ep2_range_lesson_test.gd); skip it to test the resting props
	f.debug_skip_lesson()
	for i in 90:
		f.step(1.0 / 60.0)
	var gun: Node3D = f._bull_guard_rifle
	_check("his own Winchester is shown", gun != null and gun.is_visible_in_tree())
	if gun:
		var muzzle_dir: Vector3 = gun.global_transform.basis.z.normalized()
		_check("...shoulder-carried, muzzle up (dir.y %.2f)" % muzzle_dir.y, muzzle_dir.y > 0.85)
		_check("...at a readable size (scale %.2f)" % gun.global_transform.basis.get_scale().x,
			gun.global_transform.basis.get_scale().x >= 1.2)
		var muzzle_top: Vector3 = gun.global_position + muzzle_dir * 0.6 * gun.global_transform.basis.get_scale().x
		_check("...its muzzle rises to his shoulder line (%.2f m)" % muzzle_top.y, muzzle_top.y > 2.0)
	var glass: Node3D = f._glass_node
	_check("his whiskey stays on the table, leaving his hand free", glass != null and glass.is_visible_in_tree() and glass.get_parent() == f._visuals)
	_check("...with whiskey, ice and a rim inside", glass != null and glass.get_node_or_null("Whiskey") != null
		and glass.get_node_or_null("Ice") != null and glass.get_node_or_null("Rim") != null)
	var table_pose: Transform3D = glass.global_transform
	f._return_bull_glass()
	_check("handover cleanup cannot reattach the glass", glass.get_parent() == f._visuals)
	f._player_pos = Vector3(4.6, 0.0, 8.4)
	for i in 150:
		f.step(1.0 / 60.0)
	_check("glass stays fixed while Bull moves and turns", glass.global_transform.is_equal_approx(table_pose))
	to_hero = atan2(f._player_pos.x - bull.position.x, f._player_pos.z - bull.position.z)
	_check("...and turns to face him from the other side (off by %.2f rad)" % absf(angle_difference(bull.facing, to_hero)),
		absf(angle_difference(bull.facing, to_hero)) < f.REST_FACE_SLACK + 0.05)
	f.queue_free()
	await get_tree().process_frame
