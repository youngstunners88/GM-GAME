extends Node

var music_bus: int = 0
var sfx_bus: int = 0
var current_music_player: AudioStreamPlayer = null

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    music_bus = AudioServer.get_bus_index("Music")
    sfx_bus = AudioServer.get_bus_index("SFX")
    # Create buses if they don't exist
    if music_bus == -1:
        AudioServer.add_bus(-1)
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
        music_bus = AudioServer.get_bus_index("Music")
    if sfx_bus == -1:
        AudioServer.add_bus(-1)
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
        sfx_bus = AudioServer.get_bus_index("SFX")

## Active shuffle pool. When the current track ends, another is drawn from
## here (never the same track twice in a row while 2+ exist).
var _playlist: Array = []
var _last_track: String = ""

## Play a single track on repeat (routed through the shuffle system).
func play_music(path: String) -> void:
    play_playlist([path])

## Play a set of tracks on shuffle — the stage/boss music model: every level
## and every boss has two songs that alternate randomly, forever.
func play_playlist(paths: Array) -> void:
    var found: Array = []
    for p in paths:
        # Tracks may be absent in dev builds — degrade silently instead of
        # logging "No loader found" errors for files not in the pck yet.
        if ResourceLoader.exists(p):
            found.append(p)
    _stop_music()
    _playlist = found
    if _playlist.is_empty():
        return
    _play_next_in_playlist()

func _stop_music() -> void:
    if current_music_player and is_instance_valid(current_music_player):
        current_music_player.stop()
        current_music_player.queue_free()
    current_music_player = null

func _play_next_in_playlist() -> void:
    var candidates: Array = _playlist
    if _playlist.size() > 1:
        candidates = _playlist.filter(func(p): return p != _last_track)
    var path: String = candidates[randi() % candidates.size()]
    var stream := load(path)
    if not stream:
        return
    _last_track = path
    current_music_player = AudioStreamPlayer.new()
    current_music_player.bus = "Music"
    current_music_player.stream = stream
    add_child(current_music_player)
    current_music_player.play()
    current_music_player.finished.connect(_on_music_track_finished)

func _on_music_track_finished() -> void:
    if current_music_player and is_instance_valid(current_music_player):
        current_music_player.queue_free()
    current_music_player = null
    if not _playlist.is_empty():
        _play_next_in_playlist()

func play_sfx(name: String) -> void:
    var path := "res://src/assets/sounds/" + name + ".ogg"
    if not ResourceLoader.exists(path):
        return
    var stream := load(path)
    if not stream:
        return
    var player := AudioStreamPlayer.new()
    player.bus = "SFX"
    player.stream = stream
    add_child(player)
    player.play()
    player.finished.connect(player.queue_free)

func set_music_volume(vol_db: float) -> void:
    AudioServer.set_bus_volume_db(music_bus, vol_db)

func set_sfx_volume(vol_db: float) -> void:
    AudioServer.set_bus_volume_db(sfx_bus, vol_db)
