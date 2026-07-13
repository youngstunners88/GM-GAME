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
    _setup_reverb()

# ---- Environmental reverb -------------------------------------------------
# One Reverb effect on the SFX bus; each realm sets its own room feel.
var _reverb: AudioEffectReverb

const REVERB_PROFILES := {
    "forest": 0.2,   # light open-air reflections (Level 1)
    "cave": 0.6,     # heavy wet cavern echo (Level 2 Crystal Caverns)
    "mine": 0.35,    # timber-and-rock mine shafts (Level 3)
    "boss": 0.4,     # metallic arena presence
    "none": 0.0,
}

func _setup_reverb() -> void:
    _reverb = AudioEffectReverb.new()
    _reverb.wet = 0.0
    AudioServer.add_bus_effect(sfx_bus, _reverb)

## Set the environment reverb by realm name ("forest", "cave", "mine",
## "boss", "none"). Levels call this in _ready(); boss triggers switch to
## "boss" for the arena.
func set_reverb_profile(profile: String) -> void:
    if _reverb:
        _reverb.wet = REVERB_PROFILES.get(profile, 0.0)

## Active shuffle pool. When the current track ends, another is drawn from
## here (never the same track twice in a row while 2+ exist).
var _playlist: Array = []
var _last_track: String = ""

## Play a single track on repeat (routed through the shuffle system).
func play_music(path: String) -> void:
    play_playlist([path])

## Play a set of tracks on shuffle — the stage/boss music model: every level
## and every boss has two songs that alternate randomly, forever.
## Switches DUCK: the outgoing track fades to silence over ~0.8s while the
## incoming one rises from -12dB, so boss-arena handoffs stop hard-cutting.
func play_playlist(paths: Array) -> void:
    var found: Array = []
    for p in paths:
        # Tracks may be absent in dev builds — degrade silently instead of
        # logging "No loader found" errors for files not in the pck yet.
        if ResourceLoader.exists(p):
            found.append(p)
    _duck_out_music()
    _playlist = found
    if _playlist.is_empty():
        return
    _play_next_in_playlist(true)

## Fade the current track out and free it — replaces the old hard stop.
func _duck_out_music() -> void:
    if current_music_player and is_instance_valid(current_music_player):
        var old := current_music_player
        var tween := old.create_tween()
        tween.tween_property(old, "volume_db", -32.0, 0.8)
        tween.finished.connect(old.queue_free)
    current_music_player = null

func _stop_music() -> void:
    if current_music_player and is_instance_valid(current_music_player):
        current_music_player.stop()
        current_music_player.queue_free()
    current_music_player = null

func _play_next_in_playlist(fade_in: bool = false) -> void:
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
    if fade_in:
        current_music_player.volume_db = -12.0
        var tween := current_music_player.create_tween()
        tween.tween_property(current_music_player, "volume_db", 0.0, 1.0)
    current_music_player.play()
    current_music_player.finished.connect(_on_music_track_finished)

func _on_music_track_finished() -> void:
    if current_music_player and is_instance_valid(current_music_player):
        current_music_player.queue_free()
    current_music_player = null
    if not _playlist.is_empty():
        _play_next_in_playlist()

## Resolve an SFX/VO id to a file: legacy .ogg first, then generated .mp3
## (the game-audio-forge pipeline outputs mp3 — Godot 4.3 plays it natively).
func _resolve_audio(base: String) -> String:
    # NOTE: ext must be explicitly typed — iterating an untyped array yields
    # Variant, and `base + Variant` breaks := inference under the web
    # export's compiler (this exact line shipped a build where EVERY script
    # referencing AudioManager cascade-failed to compile; caught by the
    # browser harness, not gdparse, which is syntax-only).
    for ext: String in [".ogg", ".mp3"]:
        var path: String = base + ext
        if ResourceLoader.exists(path):
            return path
    return ""

func play_sfx(name: String) -> void:
    var path := _resolve_audio("res://src/assets/sounds/" + name)
    if path == "":
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

## Announcer voiceover (game-audio-forge pipeline). Ducks music −8dB while
## the line plays so the words always read, then restores. One line at a
## time: a new call replaces the current one.
var _voice_player: AudioStreamPlayer

func play_voice(name: String) -> void:
    var path := _resolve_audio("res://src/assets/sounds/voice/" + name)
    if path == "":
        return
    var stream := load(path)
    if not stream:
        return
    if _voice_player and is_instance_valid(_voice_player):
        _voice_player.queue_free()
    _voice_player = AudioStreamPlayer.new()
    _voice_player.bus = "SFX"
    _voice_player.stream = stream
    add_child(_voice_player)
    if current_music_player and is_instance_valid(current_music_player):
        var duck := current_music_player.create_tween()
        duck.tween_property(current_music_player, "volume_db", -8.0, 0.25)
    _voice_player.play()
    _voice_player.finished.connect(_on_voice_finished)

func _on_voice_finished() -> void:
    if _voice_player and is_instance_valid(_voice_player):
        _voice_player.queue_free()
    _voice_player = null
    if current_music_player and is_instance_valid(current_music_player):
        var restore := current_music_player.create_tween()
        restore.tween_property(current_music_player, "volume_db", 0.0, 0.5)

## Positional SFX: plays at a world position so pickups/impacts pan and
## attenuate with distance from the player instead of sounding global.
func play_sfx_at(name: String, pos: Vector2) -> void:
    var path := _resolve_audio("res://src/assets/sounds/" + name)
    if path == "":
        return
    var root := get_tree().current_scene
    if root == null:
        play_sfx(name)
        return
    var player := AudioStreamPlayer2D.new()
    player.bus = "SFX"
    player.stream = load(path)
    player.max_distance = 900.0
    player.global_position = pos
    root.add_child(player)
    player.play()
    player.finished.connect(player.queue_free)

func set_music_volume(vol_db: float) -> void:
    AudioServer.set_bus_volume_db(music_bus, vol_db)

func set_sfx_volume(vol_db: float) -> void:
    AudioServer.set_bus_volume_db(sfx_bus, vol_db)
