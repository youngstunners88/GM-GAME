extends Node
## Gate for the founder's Episode 2 film + stage theme hand-off (skill ep2-theme-song-handoff, 2026-10-04):
## the runner music phases out before the film, the film carries the theme, and the game CONTINUES the theme from
## the matching position (never restarting, never jumping).
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_theme_handoff_test.tscn

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	print("EP2 THEME HANDOFF:")
	var F = SmeltingFacilityChamber
	_check("the founder's film is in the build", ResourceLoader.exists(F.FILM_VIDEO))
	_check("the stage theme is in the build", ResourceLoader.exists(F.STAGE_THEME))
	var theme: AudioStream = load(F.STAGE_THEME)
	_check("the theme is a real, long track (%.0f s)" % theme.get_length(), theme != null and theme.get_length() > 120.0)
	_check("the film constant matches the 60.8 s file", absf(F.FILM_SECONDS - 60.9) < 0.2)

	var am: Node = get_node("/root/AudioManager")
	# 1. play_track_from continues at the given position.
	am.play_track_from(F.STAGE_THEME, 34.3, 0.0)
	await get_tree().process_frame
	var pl: AudioStreamPlayer = am.current_music_player
	_check("play_track_from starts the theme", pl != null and pl.playing)
	var pos: float = pl.get_playback_position() if pl else -1.0
	_check("...at the requested position (34.3 s, got %.2f)" % pos, pos > 33.5 and pos < 36.5)
	_check("...on the Music bus", pl != null and pl.bus == "Music")

	# 2. The film hands the theme over at the right position when it ends (natural end).
	am.fade_out_music(0.01)
	await get_tree().create_timer(0.2).timeout
	var vf := Ep2VideoFilm.new()
	vf.continue_track = F.STAGE_THEME
	vf.song_video_offset = F.FILM_SONG_OFFSET
	add_child(vf)
	vf._continue_song(60.83)
	await get_tree().process_frame
	pl = am.current_music_player
	pos = pl.get_playback_position() if pl else -1.0
	_check("film end (60.83 s) continues the theme at ~34.3 s (got %.2f)" % pos, pl != null and pos > 33.5 and pos < 36.5)
	# 3. Skipping before the song starts in the film starts the theme from 0, never negative.
	vf._continue_song(10.0)
	await get_tree().process_frame
	pl = am.current_music_player
	pos = pl.get_playback_position() if pl else -1.0
	_check("a skip before the song begins starts it from the top (got %.2f)" % pos, pl != null and pos >= 0.0 and pos < 2.0)
	vf.queue_free()

	# 4. The runner music phases out before the film.
	var sr: Node = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(sr)
	await get_tree().process_frame
	am.play_playlist([F.STAGE_THEME], true, 0.1)
	sr._on_cliff_panic_music(1)
	_check("panic level 1 does NOT fade the music yet", not am._playlist.is_empty())
	sr._on_cliff_panic_music(2)
	_check("panic level 2 (~90 m, ~3.5 s before the mouth) fades the runner music out", am._playlist.is_empty())
	sr.queue_free()
	am.fade_out_music(0.01)

	await _boss3_to_runner_audio(am)

	print("EP2_THEME_HANDOFF: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)


## 5. THE BOSS-3 -> EPISODE 2 HAND-OFF AUDIO (mobile transitions audit F06, 2026-10-22). The REAL chain, in the order
## claim_jumper.die() runs it: the boss theme leaves with a FADE at the kill, the film plays (Stage3BossDefeatCutscene),
## the director takes its last frame as the cover, the first runner leg is built under it. Proven: the Music bus is never
## muted, the boss theme does not re-enter (no blip at film end), NO track starts while the cover is up (the audit's
## "track starts inside the stall"), the runner theme comes in after the reveal with a slow fade, and a later leg / retry
## (director idle) is not delayed at all.
func _boss3_to_runner_audio(am: Node) -> void:
	var root: Node = get_tree().root
	reparent.call_deferred(root)               # the director swaps the current scene: this node must outlive it
	await get_tree().process_frame
	var dummy := Node.new()
	dummy.name = "DummyCurrentScene"
	root.add_child(dummy)
	get_tree().current_scene = dummy
	var td: Node = root.get_node("TransitionDirector")
	var bus: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus, false)
	var Probe: GDScript = load("res://tests/fixtures/transition_probe_target.gd")
	Probe.spawn_runner = true                  # the fixture builds a real first-leg RunnerGraybox in _ready, like Ep2SessionRoot

	# the boss fight: a boss theme is playing
	var boss_tracks: Array = ["res://src/assets/music/boss03_theme.ogg", "res://src/assets/music/boss03_theme_alt.ogg"]
	am.play_playlist(boss_tracks, true, 0.1)
	await get_tree().process_frame
	_check("hand-off: the boss theme is playing before the kill", am.current_music_player != null and am.current_music_player.playing)
	# die(): AudioManager.fade_out_music(0.8)
	am.fade_out_music(0.8)
	_check("hand-off: the kill fades the theme out and empties the playlist (nothing can restart it)",
		am.current_music_player == null and am._playlist.is_empty())
	# the film (its own audio is on Master; its cutscene repeats the fade and never touches the bus)
	var film: Stage3BossDefeatCutscene = Stage3BossDefeatCutscene.new()
	film.keep_cover = true
	dummy.add_child(film)
	film.play()
	await get_tree().process_frame
	_check("hand-off: during the film the Music bus is not muted and no track plays",
		not AudioServer.is_bus_mute(bus) and am.current_music_player == null)
	film._finish()
	await get_tree().process_frame
	_check("hand-off: film end does NOT bring the boss theme back (no blip) and does not unmute anything",
		am.current_music_player == null and am._playlist.is_empty() and not AudioServer.is_bus_mute(bus))
	var cover: Control = film.make_cover()
	film.queue_free()
	td.go(ProbeScenePath, "", "", cover)

	var seen: Dictionary = {"track_under_cover": false, "muted": false, "boss_back": false, "frames": 0, "runner_made": false}
	var guard: int = 0
	while (td._going or td.state != td.S.IDLE) and guard < 3000:
		await get_tree().process_frame
		guard += 1
		seen["frames"] = int(seen["frames"]) + 1
		if AudioServer.is_bus_mute(bus):
			seen["muted"] = true
		var p: Node = Probe.last
		if p != null and is_instance_valid(p) and p.runner != null:
			seen["runner_made"] = true
		if td.handoff_holding() and am.current_music_player != null:
			seen["track_under_cover"] = true
		if am.current_music_player != null and am.current_music_player.stream != null \
				and am.current_music_player.stream.resource_path.contains("boss03"):
			seen["boss_back"] = true
	_check("hand-off: the first runner leg was built under the cover (%d frames)" % int(seen["frames"]), bool(seen["runner_made"]))
	_check("hand-off: NO track starts while the cover is up (the runner theme waits for the reveal)", not bool(seen["track_under_cover"]))
	_check("hand-off: the Music bus was never muted across the whole chain", not bool(seen["muted"]))
	_check("hand-off: the boss theme never re-entered", not bool(seen["boss_back"]))
	await get_tree().create_timer(0.3).timeout
	var mp: AudioStreamPlayer = am.current_music_player
	_check("hand-off: after the reveal the runner theme plays, fading IN from silence (%.1f dB)" % (mp.volume_db if mp != null else 0.0),
		mp != null and mp.playing and mp.stream.resource_path.ends_with("runner_run.mp3") and mp.volume_db < -3.0)
	await get_tree().create_timer(2.0).timeout
	_check("...and reaches full level after the fade (%.1f dB)" % (mp.volume_db if mp != null and is_instance_valid(mp) else 0.0),
		mp != null and is_instance_valid(mp) and mp.volume_db > -1.5)
	_check("the first leg's music did not start twice (one runner theme, one player)", _music_players(am) == 1, str(_music_players(am)))

	# a LATER leg / a retry is created with the director idle: not held, music at once, no extra delay
	am.fade_out_music(0.01)
	var later: Node = load("res://src/episode2/runner/runner_graybox.tscn").instantiate()
	add_child(later)
	later.setup(200.0)
	_check("hand-off: a later leg (director idle) starts its music immediately and is not held",
		not later.is_reveal_holding() and am.current_music_player != null and am.current_music_player.playing)
	later.queue_free()
	am.fade_out_music(0.01)
	Probe.spawn_runner = false
	var cs: Node = get_tree().current_scene
	if cs != null and is_instance_valid(cs) and cs != self:
		cs.queue_free()


const ProbeScenePath := "res://tests/fixtures/transition_probe_target.tscn"


## How many AudioStreamPlayers under AudioManager are PLAYING a music track right now (a fading-out one still counts).
func _music_players(am: Node) -> int:
	var n: int = 0
	for c in am.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing and (c as AudioStreamPlayer).bus == &"Music" \
				and (c as AudioStreamPlayer).volume_db > -45.0:
			n += 1
	return n
