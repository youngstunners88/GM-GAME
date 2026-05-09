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

func play_music(path: String) -> void:
    if current_music_player and is_instance_valid(current_music_player):
        current_music_player.stop()
        current_music_player.queue_free()
        current_music_player = null
    var stream := load(path)
    if not stream:
        return
    current_music_player = AudioStreamPlayer.new()
    current_music_player.bus = "Music"
    current_music_player.stream = stream
    add_child(current_music_player)
    current_music_player.play()

func play_sfx(name: String) -> void:
    var path := "res://src/assets/sounds/" + name + ".ogg"
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
