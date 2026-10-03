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
var _video: VideoStreamPlayer = null
var _t: float = 0.0
var _skip_held: float = 0.0
var _done: bool = false
var _music_muted: bool = false
var _hint: Label = null
var _driven_externally: bool = false


## Build the player. Returns false (and emits nothing) when the stream is missing or not decodable, so the caller
## can fall back to the in-engine film.
func prepare(path: String, length_seconds: float) -> bool:
	seconds = length_seconds
	if not ResourceLoader.exists(path):
		return false
	var stream: VideoStream = ResourceLoader.load(path) as VideoStream
	if stream == null:
		return false
	layer = 40                       # above the HUD and every gameplay layer
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_video = VideoStreamPlayer.new()
	_video.name = "Ep2Film"
	_video.stream = stream
	_video.expand = true
	_video.loop = false
	_video.volume_db = 0.0
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.finished.connect(_finish)
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
	_video.play()


func _process(delta: float) -> void:
	if not _driven_externally:
		step(delta)
	if _hint:
		_hint.modulate.a = clampf(minf(_t - 1.0, 5.0 - _t), 0.0, 1.0) * 0.8


## Advance the clock; the skip hold and the stall guard both live here.
func step(delta: float) -> void:
	if _done:
		return
	_t += delta
	if Input.is_action_pressed(SKIP_ACTION):
		_skip_held += delta
		if _skip_held >= SKIP_HOLD:
			_finish()
			return
	else:
		_skip_held = 0.0
	if _t >= seconds + GRACE:
		_finish()


## Headless tests drive the clock themselves (the real-time _process must not double-count).
func drive_externally() -> void:
	_driven_externally = true


func is_done() -> bool: return _done
func elapsed() -> float: return _t


func skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _video and is_instance_valid(_video):
		_video.stop()
	_unmute_music()
	finished.emit()


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
