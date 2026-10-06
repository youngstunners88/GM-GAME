class_name Ep2VideoFilm
extends CanvasLayer
## A pre-rendered (Seedance 2) film that owns the screen: the cart-over-the-gap transition into Inferno Bull's
## hideout (founder 2026-10-03; skill ep2-seedance-film).
##
## Why a class of its own: the film has to START THE FRAME IT IS ASKED TO. The in-engine cliff film built a whole
## 3D set plus the hideout on the cut and the player stared at a frozen cart ("the delay is stupidly ridiculous").
## This node is a letterboxed VideoStreamPlayer and nothing else; the stream is requested on a worker thread at the
## first runner panic (Ep2SessionRoot._warm_chamber_assets) so `load()` here is a cache hit.
##
## Contract:
##  * `start()` begins playback immediately. `finished` is emitted exactly once: when the video ends, when the
##    player holds JUMP for SKIP_HOLD seconds, or when `step()` has advanced past `seconds + GRACE` (a stalled
##    decode or a headless run must never hang the story).
##  * The soundtrack is baked into the .ogv (dialogue + foley, NO MUSIC). The Music bus is muted while it plays
##    so the runner's playlist cannot sit under it, and restored on finish / exit.
##  * `step(delta)` is the deterministic clock (headless tests); the real player advances it from _process.

signal finished

const GRACE := 2.5
## Hold JUMP this long to skip (a tap would be too easy to hit by accident while the cart is still on screen).
const SKIP_HOLD := 0.9
const SKIP_ACTION := "jump"

var seconds: float = 30.0
## Founder 2026-10-04: the film carries the stage theme from `song_video_offset` seconds in; when it ends (or is
## skipped) the game must CONTINUE that song from the matching position. `continue_track` empty = no hand-off.
var continue_track: String = ""
var song_video_offset: float = 26.53
## The song position the last hand-off continued from (tests and the shot rig read it).
var last_song_position: float = -1.0
var _video: VideoStreamPlayer = null
var _t: float = 0.0
var _skip_held: float = 0.0
var _stall_at: float = -1.0       # clock time the stall banner was raised (the picture never advanced)
var _diag: Label = null
var _real_start_ms: int = 0       # wall clock at start(): the stall check must not trust the (test-driven) film clock
var _skip_armed: bool = false      # JUMP must be RELEASED once (after the first second) before a hold can skip the film
var _done: bool = false
var _music_muted: bool = false
var _hint: Label = null
var _driven_externally: bool = false
var _bg: ColorRect = null
var _finishing: bool = false       # the picture is gone and black is on screen; `finished` follows two frames later
var _black_frames: int = 0
var _black_steps: int = 0


## Build the player. Returns false (and emits nothing) when the stream is missing or not decodable, so the caller
## can fall back to the in-engine film.
func prepare(path: String, length_seconds: float) -> bool:
	seconds = length_seconds
	if not ResourceLoader.exists(path):
		print("[VIDEO] Ep2 film: file missing from the build: %s (falling back to the in-engine film)" % path)
		return false
	var stream: VideoStream = ResourceLoader.load(path) as VideoStream
	if stream == null:
		print("[VIDEO] Ep2 film: not decodable as a VideoStream: %s (falling back to the in-engine film)" % path)
		return false
	layer = 40                       # above the HUD and every gameplay layer
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_bg = bg
	_video = VideoStreamPlayer.new()
	_video.name = "Ep2Film"
	_video.stream = stream
	_video.expand = true
	_video.loop = false
	_video.volume_db = 0.0
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.finished.connect(_on_player_finished)
	add_child(_video)
	_hint = Label.new()
	_hint.text = "HOLD SPACE TO SKIP"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-190.0, -34.0)
	_hint.modulate.a = 0.0
	add_child(_hint)
	return true


func _ready() -> void:
	_letterbox()
	get_viewport().size_changed.connect(_letterbox)


## 16:9 picture centred in whatever the window is (black bars, never a stretch).
func _letterbox() -> void:
	if _video == null or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ar: float = 16.0 / 9.0
	var w: float = minf(vp.x, vp.y * ar)
	var h: float = w / ar
	_video.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_video.position = Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)
	_video.size = Vector2(w, h)


func start() -> void:
	if _done or _video == null:
		return
	_mute_music()
	_letterbox()
	_real_start_ms = Time.get_ticks_msec()
	_video.play()


func _process(delta: float) -> void:
	if _finishing:
		_black_frames += 1
		_try_emit_finished()
		return
	if not _driven_externally:
		step(delta)
	if _hint:
		_hint.modulate.a = clampf(minf(_t - 1.0, 5.0 - _t), 0.0, 1.0) * 0.8


## Advance the clock; the skip hold and the stall guard both live here.
func step(delta: float) -> void:
	if _finishing:
		_black_steps += 1
		_try_emit_finished()
		return
	if _done:
		return
	_t += delta
	# Founder 2026-10-05 "the video isn't playing": Space is also JUMP, and the player is often still holding it (or
	# mashing it) when the cart runs out - the film saw a held JUMP at frame 0 and skipped itself within 0.9 s. A skip now
	# needs the key to have been released first (and the hint on screen), i.e. a deliberate NEW hold.
	if Input.is_action_pressed(SKIP_ACTION):
		if _skip_armed:
			_skip_held += delta
			if _skip_held >= SKIP_HOLD:
				_finish()
				return
	else:
		_skip_held = 0.0
		if _t >= 1.0:
			_skip_armed = true
	_check_stall()
	if _stall_at >= 0.0 and _t >= _stall_at + 2.5:
		_finish()
		return
	if _t >= seconds + GRACE:
		_finish()


## Headless tests drive the clock themselves (the real-time _process must not double-count).
func drive_externally() -> void:
	_driven_externally = true


func is_done() -> bool: return _done
func is_finishing() -> bool: return _finishing
func elapsed() -> float: return _t


func skip() -> void:
	_finish()


## The film ends on BLACK, never on a frozen frame: the picture is hidden first and `finished` is emitted two
## rendered frames later (or three clock steps in a headless run), so whatever the owner builds in response (the
## whole hideout, ~1 s on the web) happens behind black and cannot stutter the film's picture or sound. The film
## itself NEVER does heavy work while it plays (the glitch the founder saw was the room being built mid-film).
## The decoder says it is done. If that happens long before the film's length the picture ended EARLY (a corrupt
## stream or a decoder fault) - say so in the console instead of silently jumping to the hideout.
func _on_player_finished() -> void:
	var pos: float = _video.stream_position if _video and is_instance_valid(_video) else -1.0
	if _t < seconds - 4.0:
		print("[VIDEO] Ep2 film: the decoder ended EARLY at clock %.1f s (stream pos %.1f of %.0f s)" % [_t, pos, seconds])
	_finish()


## The picture never moved although the clock did (a web decoder that did not start, a blocked audio context): show it
## on screen and carry on after a moment, never leave the player on a frozen first frame.
func _check_stall() -> void:
	if _video == null or not is_instance_valid(_video) or _stall_at >= 0.0:
		return
	var real_s: float = float(Time.get_ticks_msec() - _real_start_ms) / 1000.0
	if _real_start_ms > 0 and real_s >= 5.0 and _video.stream_position < 0.3:
		_stall_at = _t
		print("[VIDEO] Ep2 film: STALLED - clock %.1f s but the stream position is %.2f (playing=%s). Continuing." % [_t, _video.stream_position, str(_video.is_playing())])
		_diag = Label.new()
		_diag.text = "VIDEO COULD NOT PLAY IN THIS BROWSER - continuing"
		_diag.add_theme_font_size_override("font_size", 22)
		_diag.set_anchors_preset(Control.PRESET_CENTER)
		_diag.position = Vector2(-260.0, 0.0)
		add_child(_diag)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[VIDEO] Ep2 film: finished at clock %.1f s, stream pos %.1f s" % [_t, _video.stream_position if _video and is_instance_valid(_video) else -1.0])
	# Read where the film IS before stopping it: VideoStreamPlayer.stop() rewinds the Theora clock to 0, and reading
	# it afterwards restarted the stage theme from bar one (founder 2026-10-04: "supposed to continue and not start
	# again"). `film_end_position()` is the single source of truth for the hand-off position.
	var video_t: float = film_end_position()
	if _video and is_instance_valid(_video):
		_video.stop()
		_video.visible = false
	if _hint:
		_hint.visible = false
	_unmute_music()
	_continue_song(video_t)
	_finishing = true


## Where the film's picture/sound is right now, in film seconds. Uses the decoder's own clock while it is still
## running; when the decoder reports nothing useful (already rewound, web decoder not started, headless run) it
## falls back to the wall clock `_t`, capped at the film length. Never returns 0 for a film that played to the end.
func film_end_position() -> float:
	var pos: float = 0.0
	if _video and is_instance_valid(_video):
		pos = maxf(_video.stream_position, 0.0)
	if pos < 0.25:
		pos = minf(_t, seconds)
	return pos


## The song position the game continues from when the film ends at `video_t` film seconds.
func song_position_for(video_t: float) -> float:
	return maxf(video_t - song_video_offset, 0.0)


## Start the stage theme where the film's own copy of it is (or would be) right now, so it never restarts or jumps.
func _continue_song(video_t: float) -> void:
	last_song_position = song_position_for(video_t)
	if continue_track == "":
		return
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_track_from"):
		am.play_track_from(continue_track, last_song_position, 0.12)


func _try_emit_finished() -> void:
	if _black_frames >= 2 or _black_steps >= 3:
		_finishing = false
		finished.emit()


## After the owner has built its scene behind the black: fade the black out and free the film.
func release(seconds: float = 0.8) -> void:
	if _bg == null or not is_inside_tree():
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_bg, "color:a", 0.0, seconds)
	tw.finished.connect(queue_free)


func _mute_music() -> void:
	var bus: int = AudioServer.get_bus_index("Music")
	if bus >= 0 and not AudioServer.is_bus_mute(bus):
		AudioServer.set_bus_mute(bus, true)
		_music_muted = true


func _unmute_music() -> void:
	if not _music_muted:
		return
	var bus: int = AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)
	_music_muted = false


func _exit_tree() -> void:
	# Never leave the Music bus muted if we are torn down off the normal path.
	_unmute_music()
