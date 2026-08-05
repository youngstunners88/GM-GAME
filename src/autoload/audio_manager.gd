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
    # A new base-music request (level/boss/menu) supersedes any Blaze override
    # or ambient loop (Smoke Lounge) still playing.
    _drop_override_for_new_music()
    _stop_ambient()
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
    # Don't auto-advance the base playlist while a music override (Blaze) owns
    # the music — the override has its own player. It resumes on release.
    if _override_active:
        return
    if not _playlist.is_empty():
        _play_next_in_playlist()

# ---- Music override (Blaze Mode etc.) — brief correction A ----------------
# One central, race-safe music override. Only ONE override may be audible at a
# time; the normal track is PAUSED (not layered under), and restored once on
# release. A monotonic token invalidates stale expiry callbacks so a scene
# change / death / second pickup can't revive an old track. AudioManager stays
# the sole owner of every music player — nothing else spawns music.

var _override_active: bool = false
var _override_token: int = 0
var _override_player: AudioStreamPlayer = null
# Saved base-music context to restore on release.
var _saved_playlist: Array = []
var _saved_last_track: String = ""
var _saved_stream: AudioStream = null
var _saved_position: float = 0.0

## Take over music with an exclusive track (loops). `token` returned must be
## passed back to release_music_override() so a stale caller can't clobber a
## newer override. Missing asset → no-op that still returns a token (so the
## caller's paired release is harmless). SFX/VO are unaffected.
func push_music_override(path: String) -> int:
    _override_token += 1
    var my_token := _override_token
    var resolved := path
    if not ResourceLoader.exists(resolved):
        resolved = _resolve_audio(path.get_basename())
    if resolved == "" or not ResourceLoader.exists(resolved):
        # No Blaze track available — leave base music alone, but still claim
        # the override slot so the game's paired release is well-defined.
        _override_active = true
        return my_token
    var stream := load(resolved)
    if stream == null:
        _override_active = true
        return my_token
    # Save + PAUSE the base track (position preserved for resume).
    if current_music_player and is_instance_valid(current_music_player):
        _saved_stream = current_music_player.stream
        _saved_position = current_music_player.get_playback_position()
        _saved_playlist = _playlist.duplicate()
        _saved_last_track = _last_track
        current_music_player.stream_paused = true
    else:
        _saved_stream = null
        _saved_playlist = _playlist.duplicate()
        _saved_last_track = _last_track
    _override_active = true
    _clear_override_player()
    _override_player = AudioStreamPlayer.new()
    _override_player.bus = "Music"
    _override_player.stream = stream
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    elif stream is AudioStreamMP3:
        (stream as AudioStreamMP3).loop = true
    add_child(_override_player)
    _override_player.volume_db = -8.0
    var tw := _override_player.create_tween()
    tw.tween_property(_override_player, "volume_db", 0.0, 0.4)
    _override_player.play()
    return my_token

## Release a previously pushed override. Stale tokens are ignored — this is
## what stops a delayed Blaze-expiry from restoring music after a scene change
## or a second pickup already took over.
func release_music_override(token: int) -> void:
    if token != _override_token or not _override_active:
        return
    _override_active = false
    _clear_override_player()
    # Resume the base track from where it paused, if it still exists.
    if current_music_player and is_instance_valid(current_music_player):
        current_music_player.stream_paused = false
        return
    # Base player was freed (scene change, etc.) — rebuild from saved context.
    _playlist = _saved_playlist
    _last_track = _saved_last_track
    if _saved_stream != null:
        current_music_player = AudioStreamPlayer.new()
        current_music_player.bus = "Music"
        current_music_player.stream = _saved_stream
        add_child(current_music_player)
        current_music_player.play(_saved_position)
        current_music_player.finished.connect(_on_music_track_finished)
    elif not _playlist.is_empty():
        _play_next_in_playlist(true)
    _saved_stream = null

func _clear_override_player() -> void:
    if _override_player and is_instance_valid(_override_player):
        _override_player.stop()
        _override_player.queue_free()
    _override_player = null

## A new base-music call (level load, boss arena) supersedes any override —
## the override is dropped and the token bumped so its release no-ops.
func _drop_override_for_new_music() -> void:
    if _override_active:
        _override_active = false
        _override_token += 1
        _clear_override_player()
        _saved_stream = null
        _saved_playlist = []

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
    # Founder F4: "the previous bosses dont speak or the volume is not loud
    # enough." VO played at unity gain on the shared SFX bus, so it sat level
    # with coin pings and axe hits and got lost in a fight. +6dB puts the line
    # clearly on top of the mix; the music duck below was already there and was
    # never the whole story on its own.
    _voice_player.volume_db = 6.0
    _voice_player.stream = stream
    add_child(_voice_player)
    if current_music_player and is_instance_valid(current_music_player):
        var duck := current_music_player.create_tween()
        duck.tween_property(current_music_player, "volume_db", -14.0, 0.2)
    _voice_player.play()
    _voice_player.finished.connect(_on_voice_finished)

func _on_voice_finished() -> void:
    if _voice_player and is_instance_valid(_voice_player):
        _voice_player.queue_free()
    _voice_player = null
    if current_music_player and is_instance_valid(current_music_player):
        var restore := current_music_player.create_tween()
        restore.tween_property(current_music_player, "volume_db", 0.0, 0.5)

## Dedicated player for Lil Blunt's character barks. Deliberately a SEPARATE
## node from _voice_player: play_voice() is the ANNOUNCER (stage/boss intros,
## victory) and is single-slot + music-ducking. If barks reused it, a bark on
## taking damage would cut off a stage-intro line, and every hurt would fire a
## duck/restore tween pair on the music. One bark slot (newest replaces old)
## because barks are reactions — the newest is the relevant one — which also
## stops player nodes accumulating over a long session.
var _bark_player: AudioStreamPlayer = null

## Last-fired timestamp (msec) per bark id. Per-id so a rapid hurt bark can't
## starve an attack bark, and vice versa.
var _bark_last_played: Dictionary = {}

## Play a short Lil Blunt character bark. Never touches current_music_player
## and never touches _voice_player. Calls inside the per-id cooldown are
## silently dropped — the cooldown IS the spam absorber for the fan-axe
## multi-hit and continuous fire-breath tick cadence. A missing or unloadable
## file is a silent no-op: VO assets may be absent in some builds and
## gameplay must never depend on them.
func play_bark(name: String, cooldown: float) -> void:
    var now := Time.get_ticks_msec()
    if _bark_last_played.has(name):
        var last: int = _bark_last_played[name]
        if now - last < int(cooldown * 1000.0):
            return
    var path := _resolve_audio("res://src/assets/sounds/voice/" + name)
    if path == "":
        return
    var stream := load(path)
    if not stream:
        return
    # Stamp only after a successful load, so a build missing this file doesn't
    # burn the cooldown for nothing.
    _bark_last_played[name] = now
    if _bark_player and is_instance_valid(_bark_player):
        _bark_player.queue_free()
    _bark_player = AudioStreamPlayer.new()
    _bark_player.bus = "SFX"
    _bark_player.stream = stream
    add_child(_bark_player)
    _bark_player.play()
    # Self-cleanup so finished barks don't leak nodes across a session.
    _bark_player.finished.connect(_bark_player.queue_free)

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

# ---- Ambient loop with crossfade + pause duck (Smoke Lounge, reusable) ----
# A single looping track that isn't part of the shuffle playlist system —
# for atmospheric rooms that want one dedicated song rather than a rotation.
# Ducks (not silences) while paused so the room never goes dead-quiet.
var _ambient_player: AudioStreamPlayer = null
var _ambient_base_db: float = 0.0
const AMBIENT_DUCK_LINEAR := 0.3

## Fade the current base track out over `fade_seconds` and fade this one in to
## `target_volume_linear` (0..1) over the same span. Missing asset -> silent
## no-op, matching play_playlist's degrade-in-dev-builds convention, so a
## room with no music file yet just plays without music instead of erroring.
func play_ambient_loop(path: String, target_volume_linear: float = 0.7, fade_seconds: float = 2.0) -> void:
    if not ResourceLoader.exists(path):
        return
    var stream := load(path)
    if stream == null:
        return
    _drop_override_for_new_music()
    if current_music_player and is_instance_valid(current_music_player):
        var old := current_music_player
        var out_tween := old.create_tween()
        out_tween.tween_property(old, "volume_db", -80.0, fade_seconds)
        out_tween.finished.connect(old.queue_free)
    current_music_player = null
    _stop_ambient()
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = true
    elif stream is AudioStreamMP3:
        (stream as AudioStreamMP3).loop = true
    _ambient_base_db = linear_to_db(clampf(target_volume_linear, 0.001, 1.0))
    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.bus = "Music"
    _ambient_player.stream = stream
    _ambient_player.volume_db = -80.0
    add_child(_ambient_player)
    _ambient_player.play()
    var in_tween := _ambient_player.create_tween()
    in_tween.tween_property(_ambient_player, "volume_db", _ambient_base_db, fade_seconds)
    # Connected lazily (not in _ready()): AudioManager loads before StateMachine
    # in project.godot's autoload order, so StateMachine wouldn't exist yet if
    # this connected at AudioManager._ready() time.
    if not StateMachine.state_changed.is_connected(_on_state_changed_for_ambient):
        StateMachine.state_changed.connect(_on_state_changed_for_ambient)

func _on_state_changed_for_ambient(_from: String, to: String) -> void:
    if _ambient_player == null or not is_instance_valid(_ambient_player):
        return
    if to != "PLAYING" and to != "PAUSED":
        return
    var target := _ambient_base_db if to == "PLAYING" else linear_to_db(AMBIENT_DUCK_LINEAR)
    var tw := _ambient_player.create_tween()
    tw.tween_property(_ambient_player, "volume_db", target, 0.3)

func _stop_ambient() -> void:
    if _ambient_player and is_instance_valid(_ambient_player):
        _ambient_player.stop()
        _ambient_player.queue_free()
    _ambient_player = null

func set_music_volume(vol_db: float) -> void:
    AudioServer.set_bus_volume_db(music_bus, vol_db)

func set_sfx_volume(vol_db: float) -> void:
    AudioServer.set_bus_volume_db(sfx_bus, vol_db)
