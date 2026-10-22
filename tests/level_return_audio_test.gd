extends Node
## Coming BACK from Blaze Rush must sound like the stage carried on - not like the
## game restarted.
##
## The old exit called AudioManager.discard_music_override(): the Blaze track and the
## PAUSED stage track were both stopped, the wipe ran in silence, and the level then
## restarted a SHUFFLED track from 0:00 AND replayed its 4-10 s "stageN_intro" voice
## line (which ducks the music -16 dB) on every single return. A player in a short
## Blaze loop heard that dozens of times.
##
## Now: AudioManager.release_music_override_faded(token, 0.35) resumes the paused stage
## track under the wipe (Blaze fades out as the stage fades in), the exit sets
## GameManager.side_return = {kind, level}, and the level starts its audio through
## LevelBase._start_stage_audio(), which reads and clears that flag and - when it names
## THIS level - leaves a playing stage track alone and never replays the intro.
##
## THE "FAINT SECOND SONG" RULE (the reason discard exists) IS RE-TESTED: after the whole
## round trip exactly ONE stage track may be audible (a Blaze tail may overlap it for the
## 0.35 s crossfade only). A CONTROL run proves the detector can fail: the same trip WITHOUT
## the side_return guard does start a second stage track.
##
## Run: godot --headless res://tests/level_return_audio_test.tscn
## Verdict: LEVEL_RETURN_AUDIO: ALL PASS | N FAILURE(S)

const BLAZE_TRACK := "res://src/assets/music/blaze_rush_theme.mp3"
const LEVELS := {
	1: "res://src/level/level_01_smoke_realm.tscn",
	2: "res://src/level/level_02_crystal_caverns.tscn",
	3: "res://src/level/level_03_gold_rush.tscn",
}
const CROSSFADE_S: float = 0.35

var _fail: int = 0
var _checks: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("LEVEL RETURN AUDIO:")
	_isolate_game_state()
	for level: int in [1, 2, 3]:
		await _round_trip(level)
	await _real_blaze_exit(1)
	await _control_without_guard(1)
	await _stale_and_foreign_flags()
	await _rebuild_when_base_player_was_freed()
	_test_discard_still_hard_stops()
	_test_stale_token_is_ignored()
	if _checks < 30:
		_fail += 1
		print("  [FAIL] only %d checks ran - a false green" % _checks)
	print("LEVEL_RETURN_AUDIO: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

# ---- audio introspection -------------------------------------------------------------

## Every music-bus player AudioManager owns that is currently audible (playing, not
## paused, louder than -20 dB), split into [blaze, stage].
func _audible() -> Dictionary:
	var blaze: Array[AudioStreamPlayer] = []
	var stage: Array[AudioStreamPlayer] = []
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == &"Music":
			var p: AudioStreamPlayer = c
			if p.playing and not p.stream_paused and p.volume_db > -20.0 and not p.is_queued_for_deletion():
				if p.stream != null and p.stream.resource_path == BLAZE_TRACK:
					blaze.append(p)
				else:
					stage.append(p)
	return {"blaze": blaze, "stage": stage}

func _make_level(level: int) -> Node:
	var scene: PackedScene = load(str(LEVELS[level]))
	var node: Node = scene.instantiate()
	add_child(node)
	return node

func _free_level(node: Node) -> void:
	node.queue_free()

## The persisted dev save (user://save.json) is shared with every other test run on this
## machine and can hold a checkpoint AT the Blaze portal plus completed-run flags, which
## would spawn the player on an unlocked portal and send the test into Blaze. Pin the
## in-memory state instead (no save_session(): this test must not write the user save).
func _isolate_game_state() -> void:
	GameManager.level_checkpoints.clear()
	GameManager.blaze_rush_completed.clear()
	GameManager.dash_return = {}
	GameManager.side_return = {}
	for lvl in [1, 2, 3]:
		# The portal frees itself when its entrance is used: nothing can re-enter Blaze.
		GameManager.blaze_portal_used[lvl] = true

func _fresh_audio() -> void:
	AudioManager.fade_out_music(0.01)
	GameManager.side_return = {}

# ---- the real round trip ----------------------------------------------------------------

func _round_trip(level: int) -> void:
	_fresh_audio()
	await get_tree().create_timer(0.1).timeout
	var tag: String = "L%d" % level
	# 1. An ordinary load: the stage song starts and the intro line plays.
	var voice_before: int = AudioManager._voice_gen
	var node: Node = _make_level(level)
	await get_tree().process_frame
	var stage_player: AudioStreamPlayer = AudioManager.current_music_player
	_check("%s: an ordinary load starts the stage track" % tag, stage_player != null and stage_player.playing)
	_check("%s: an ordinary load plays the stage-intro voice line" % tag, AudioManager._voice_gen == voice_before + 1)
	await get_tree().create_timer(0.6).timeout
	var pos_before: float = stage_player.get_playback_position()

	# 2. Enter Blaze (what blaze_rush._ready does) and leave the level scene.
	var token: int = AudioManager.push_music_override(BLAZE_TRACK)
	_free_level(node)
	await get_tree().process_frame
	_check("%s: entering Blaze PAUSES the stage track (same node kept)" % tag,
		is_instance_valid(stage_player) and stage_player.stream_paused and AudioManager.current_music_player == stage_player)
	await get_tree().create_timer(0.3).timeout

	# 3. Blaze exits: faded release + the flag the level reads.
	var voice_mid: int = AudioManager._voice_gen
	GameManager.side_return = {"kind": "blaze", "level": level}
	AudioManager.release_music_override_faded(token, CROSSFADE_S)
	_check("%s: the exit RESUMES the very same stage player (not a new track)" % tag,
		AudioManager.current_music_player == stage_player and not stage_player.stream_paused and stage_player.playing)

	# 4. The wipe (0.30 s) elapses, the level loads again.
	await get_tree().create_timer(0.30).timeout
	var node2: Node = _make_level(level)
	await get_tree().process_frame
	_check("%s: the level's _start_stage_audio kept the SAME stage player (no restart, no second song)" % tag,
		AudioManager.current_music_player == stage_player and is_instance_valid(stage_player))
	_check("%s: the stage-intro voice line is NOT replayed after a Blaze return" % tag,
		AudioManager._voice_gen == voice_mid, "voice_gen %d -> %d" % [voice_mid, AudioManager._voice_gen])
	_check("%s: side_return was consumed (a stale flag can never mute the next load)" % tag, GameManager.side_return.is_empty())
	var pos_after: float = stage_player.get_playback_position() if is_instance_valid(stage_player) else -1.0
	print("     (info) %s stage track position before Blaze %.2f s, after return %.2f s" % [tag, pos_before, pos_after])
	if pos_before > 0.3:
		_check("%s: the stage song continued (position %.2f s >= %.2f s, not restarted from 0)" % [tag, pos_after, pos_before - 0.05],
			pos_after >= pos_before - 0.05)
	# 5. Dual-track overlap, sampled through the crossfade and well after it.
	var elapsed: float = 0.0
	for at_s: float in [0.0, 0.1, 0.25, 0.6, 1.2]:
		if at_s > elapsed:
			await get_tree().create_timer(at_s - elapsed).timeout
			elapsed = at_s
		var a: Dictionary = _audible()
		_check("%s: exactly ONE stage track audible %.2f s into the return" % [tag, at_s], (a["stage"] as Array).size() == 1,
			"stage=%d blaze=%d" % [(a["stage"] as Array).size(), (a["blaze"] as Array).size()])
	var late: Dictionary = _audible()
	_check("%s: the Blaze track has faded out and been freed after the crossfade" % tag, (late["blaze"] as Array).is_empty())
	_check("%s: no override left active, nothing left retiring" % tag,
		not AudioManager._override_active and AudioManager._retiring.is_empty() and AudioManager._override_player == null,
		"active=%s retiring=%d" % [AudioManager._override_active, AudioManager._retiring.size()])
	_free_level(node2)
	await get_tree().process_frame

# ---- the REAL Blaze exit (blaze_rush.gd:_exit_to_level -> SceneRouter -> the level) -------------

## Drives the shipped code on both ends: a live blaze_rush.tscn exits, SceneRouter swaps in
## the level scene, and the level's own _ready starts its audio. The first half above
## simulates Blaze by hand; THIS is what catches blaze_rush.gd forgetting side_return or
## calling discard again. The test node is detached from `current_scene` so the router's
## scene swap does not free the test itself.
func _real_blaze_exit(level: int) -> void:
	_fresh_audio()
	await get_tree().create_timer(0.1).timeout
	var tag: String = "REAL EXIT L%d" % level
	var first: Node = _make_level(level)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var stage_player: AudioStreamPlayer = AudioManager.current_music_player
	_free_level(first)
	await get_tree().process_frame
	GameManager.dash_return = {
		"scene_path": str(LEVELS[level]),
		"position": Vector2(1450.0, 250.0),
		"level_index": level,
	}
	var run: Node = (load("res://src/dashmode/blaze_rush.tscn") as PackedScene).instantiate()
	add_child(run)
	await get_tree().process_frame
	_check("%s: a live Blaze run paused the stage track" % tag, stage_player.stream_paused)
	var voice_before: int = AudioManager._voice_gen
	# (The portal is already marked used by _isolate_game_state: the real state at every
	# Blaze exit, so the returning player cannot re-trigger it.)
	get_tree().current_scene = null
	run.call("_exit_to_level")
	_check("%s: the router was handed Blaze's SHORT wipe (%.2f s, not the global %.2f s)" % [tag, SceneRouter._wipe_seconds, SceneRouter.DEFAULT_WIPE_SECONDS],
		is_equal_approx(SceneRouter._wipe_seconds, SceneRouter.BLAZE_WIPE_SECONDS))
	_check("%s: the exit sets GameManager.side_return = {blaze, %d}" % [tag, level],
		GameManager.side_return.get("kind", "") == "blaze" and int(GameManager.side_return.get("level", -1)) == level,
		str(GameManager.side_return))
	_check("%s: the exit RESUMES the stage player at once (the wipe is not silent)" % tag,
		AudioManager.current_music_player == stage_player and not stage_player.stream_paused and stage_player.playing)
	var landed: Node = null
	for i in range(240):
		await get_tree().process_frame
		var cur: Node = get_tree().current_scene
		if cur != null and cur != run and cur.scene_file_path == str(LEVELS[level]):
			landed = cur
			break
	_check("%s: the router lands the level scene" % tag, landed != null)
	await get_tree().create_timer(0.2).timeout
	_check("%s: the stage song carried on (same player, no restart)" % tag,
		AudioManager.current_music_player == stage_player and is_instance_valid(stage_player))
	_check("%s: the stage-intro voice line was NOT replayed" % tag, AudioManager._voice_gen == voice_before)
	var a: Dictionary = _audible()
	_check("%s: one stage track audible after the real round trip" % tag, (a["stage"] as Array).size() == 1,
		"stage=%d blaze=%d" % [(a["stage"] as Array).size(), (a["blaze"] as Array).size()])
	if landed != null:
		landed.queue_free()
	if is_instance_valid(run):
		run.queue_free()
	await get_tree().create_timer(0.6).timeout
	GameManager.level_checkpoints.erase(level)
	get_tree().current_scene = self

# ---- the control: the same trip without the guard IS a second song -------------------------

func _control_without_guard(level: int) -> void:
	_fresh_audio()
	await get_tree().create_timer(0.1).timeout
	var node: Node = _make_level(level)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var token: int = AudioManager.push_music_override(BLAZE_TRACK)
	_free_level(node)
	await get_tree().process_frame
	# NO side_return: this is what the level would do if it called play_playlist after
	# the faded resume (the "faint second song" bleed).
	AudioManager.release_music_override_faded(token, CROSSFADE_S)
	await get_tree().create_timer(0.30).timeout
	var voice_before: int = AudioManager._voice_gen
	var node2: Node = _make_level(level)
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	var a: Dictionary = _audible()
	_check("CONTROL (no side_return): the old resumed track and a fresh one overlap - the detector can see a second song",
		(a["stage"] as Array).size() >= 2, "stage=%d" % (a["stage"] as Array).size())
	_check("CONTROL (no side_return): the intro voice line replays", AudioManager._voice_gen == voice_before + 1)
	_free_level(node2)
	await get_tree().create_timer(0.7).timeout

# ---- stale / foreign flags -----------------------------------------------------------------

func _stale_and_foreign_flags() -> void:
	_fresh_audio()
	await get_tree().create_timer(0.1).timeout
	# A flag for ANOTHER level must not suppress this level's audio, and is still cleared.
	GameManager.side_return = {"kind": "blaze", "level": 3}
	var voice_before: int = AudioManager._voice_gen
	var node: Node = _make_level(1)
	await get_tree().process_frame
	_check("a side_return for another level does not mute Level 1's audio",
		AudioManager._voice_gen == voice_before + 1 and AudioManager.current_music_player != null)
	_check("...and is consumed anyway", GameManager.side_return.is_empty())
	_free_level(node)
	await get_tree().process_frame
	# A return with NO stage music playing (it was lost) still restarts the playlist - but not the voice.
	_fresh_audio()
	await get_tree().create_timer(0.1).timeout
	GameManager.side_return = {"kind": "blaze", "level": 2}
	var voice_b: int = AudioManager._voice_gen
	var node2: Node = _make_level(2)
	await get_tree().process_frame
	_check("a Blaze return whose stage music was LOST restarts the playlist...",
		AudioManager.current_music_player != null and AudioManager.current_music_player.playing)
	_check("...but still does not replay the intro line", AudioManager._voice_gen == voice_b)
	_free_level(node2)
	await get_tree().process_frame

func _rebuild_when_base_player_was_freed() -> void:
	_fresh_audio()
	await get_tree().create_timer(0.1).timeout
	var node: Node = _make_level(1)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var token: int = AudioManager.push_music_override(BLAZE_TRACK)
	_free_level(node)
	# The base player is gone by the time Blaze exits (a scene change freed it).
	var old: AudioStreamPlayer = AudioManager.current_music_player
	AudioManager.current_music_player = null
	old.stop()
	old.queue_free()
	await get_tree().process_frame
	AudioManager.release_music_override_faded(token, CROSSFADE_S)
	_check("a freed base player is REBUILT from the saved context and plays",
		AudioManager.current_music_player != null and AudioManager.current_music_player.playing)
	await get_tree().create_timer(0.5).timeout
	var a: Dictionary = _audible()
	_check("...exactly one stage track after the rebuild", (a["stage"] as Array).size() == 1)
	_fresh_audio()
	await get_tree().create_timer(0.1).timeout

func _test_discard_still_hard_stops() -> void:
	# The safety net blaze_rush._exit_tree relies on is unchanged: discard stops BOTH tracks.
	AudioManager.play_playlist(["res://src/assets/music/level02_theme.ogg"])
	var token: int = AudioManager.push_music_override(BLAZE_TRACK)
	AudioManager.discard_music_override(token)
	_check("discard_music_override still hard-stops the stage track and the override",
		AudioManager.current_music_player == null and AudioManager._override_player == null and not AudioManager._override_active)

func _test_stale_token_is_ignored() -> void:
	AudioManager.play_playlist(["res://src/assets/music/level02_theme.ogg"])
	var token: int = AudioManager.push_music_override(BLAZE_TRACK)
	AudioManager.release_music_override_faded(token + 99, CROSSFADE_S)
	_check("a stale token is ignored by release_music_override_faded", AudioManager._override_active)
	AudioManager.discard_music_override(token)
	AudioManager.fade_out_music(0.01)
