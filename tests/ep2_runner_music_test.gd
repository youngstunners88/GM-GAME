extends Node
## Gate for the Episode 2 runner's music wiring (founder direction, 2026-09-06:
## "these 2 songs must play in the runner cart section on shuffle until further
## notice"). Runtime regression, not source-grep — instantiates the real
## runner_graybox scene and reads back AudioManager's actual playlist state,
## the same `AudioManager._last_track`/`_playlist` introspection pattern
## tests/owner_rage_l1_music_boss1_carts_test.gd already uses for Level 1.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_runner_music_test.tscn

const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
const EXPECTED_PLAYLIST := [
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

	# Shuffle proof: play_playlist's own no-immediate-repeat selection (per
	# AudioManager._play_next_in_playlist) means _last_track is always one of
	# our 2 tracks after wiring — confirms this scene actually reaches the
	# shuffle-capable API, not a single play_music() loop.
	_check("current track is one of the 2 founder tracks (got %s)" % AudioManager._last_track,
		EXPECTED_PLAYLIST.has(AudioManager._last_track))

	r.queue_free()
	AudioManager._stop_music()  # cleanup: don't leak playback state into other test runs

	print("EP2_RUNNER_MUSIC: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
