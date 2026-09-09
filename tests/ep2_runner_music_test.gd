extends Node
## Gate for the Episode 2 runner's music wiring. Runtime regression, not
## source-grep — instantiates the real runner_graybox scene and reads back
## AudioManager's actual playlist state, the same `AudioManager._last_track`/
## `_playlist` introspection pattern tests/owner_rage_l1_music_boss1_carts_test.gd
## already uses for Level 1.
##
## Founder direction history (this gate tracks the CURRENT one):
##   - 2026-09-06: goldmine_dreams + goldmine_high shuffle here "until further
##     notice".
##   - 2026-09-09: SUPERSEDED. Run.mp3 / Run_1.mp3 were delivered for the
##     runner specifically and replace both. The two older tracks stay on disk
##     and in assets/audio-manifest.json (real client assets) but must no
##     longer be wired to any scene — asserted below, so a revert to them
##     fails loudly instead of silently regressing the founder's newer call.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_music_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
const EXPECTED_PLAYLIST := [
	"res://src/assets/music/runner_run.mp3",
	"res://src/assets/music/runner_run_1.mp3",
]
## Retired 2026-09-09 — must NOT appear in the runner's playlist any more.
const RETIRED_TRACKS := [
	"res://src/assets/music/goldmine_dreams.mp3",
	"res://src/assets/music/goldmine_high.mp3",
]

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 RUNNER MUSIC:")

	# Arrange: both tracks are real, loadable assets before we even touch the scene.
	for path in EXPECTED_PLAYLIST:
		_check("%s exists and is loadable" % path.get_file(), ResourceLoader.exists(path))

	# Act: instantiate the runner — its _ready() wires the music.
	var r: Node3D = SCENE.instantiate()
	add_child(r)
	await get_tree().process_frame

	# Assert: AudioManager's live playlist is exactly the 2 founder tracks —
	# not the legacy goldmine.mp3 (Fort Knox vault), not a level theme, not
	# a single-track loop.
	var got: Array = AudioManager._playlist
	_check("runner wires exactly the 2 founder tracks (got %s)" % [got],
		got.size() == EXPECTED_PLAYLIST.size() and got.all(func(p): return EXPECTED_PLAYLIST.has(p)))
	_check("runner does NOT wire the Fort Knox vault track (goldmine.mp3)",
		not got.has("res://src/assets/music/goldmine.mp3"))
	for t in RETIRED_TRACKS:
		_check("runner no longer wires the retired track %s" % t.get_file(), not got.has(t))

	# Sequencing proof: play_playlist is the shuffle/advance-capable API (per
	# AudioManager._play_next_in_playlist), NOT a single play_music() loop —
	# so the 2 tracks alternate on natural end rather than one looping forever.
	_check("current track is one of the 2 founder tracks (got %s)" % AudioManager._last_track,
		EXPECTED_PLAYLIST.has(AudioManager._last_track))

	# force_first proof: the runner must OPEN on Run.mp3 specifically, every
	# time — founder direction "plays Run.mp3 during runner segments". Without
	# play_playlist's force_first flag this is a coin flip (the exact Level 1
	# "different song playing on cold start" bug, audio_manager.gd play_playlist).
	_check("runner always opens on runner_run.mp3 (got %s)" % AudioManager._last_track,
		AudioManager._last_track == EXPECTED_PLAYLIST[0])

	# Music bus proof: volume sliders/settings only work if playback is routed
	# through the Music bus, not a bespoke player or the SFX bus.
	_check("playback is routed through the Music bus (got %s)" % AudioManager.current_music_player.bus,
		AudioManager.current_music_player != null and AudioManager.current_music_player.bus == "Music")

	r.queue_free()
	AudioManager._stop_music()  # cleanup: don't leak playback state into other test runs

	print("EP2_RUNNER_MUSIC: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
