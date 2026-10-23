class_name Stage3BossDefeatCutscene
extends CanvasLayer
## Stage 3 FINAL boss-defeat cutscene — Episode 1 close. Plays after the
## Claim Jumper's own death tween (see bandit_boss.gd::die()) and replaces
## its plain "GAME COMPLETE!" Label + 3s wait — the queue_free() +
## SceneRouter.load_scene(main_menu) that follows is untouched. There is no
## Stage 4 today; this closes the episode and correctly returns to the menu.
##
## A real Seedance-2-generated video (shot list: docs/model-responses/
## 2026-09-05-astra-stage3-defeat-cutscene.md; reference still:
## artifacts/founder-art/references/stage3_boss_defeat_cutscene_reference.jpg),
## encoded to Ogg Theora+Vorbis with its dialogue baked into the video's own
## audio track — same architecture as src/level/stage1_boss_defeat_cutscene.gd
## and stage2_boss_defeat_cutscene.gd (both already shipped in PR #63).
##
## This is the third stage's cutscene to make this switch: the first version
## shipped an in-engine ColorRect/particle placeholder because the founder's
## Muapi balance was insufficient for the $4.50 generation job at the time.
## Once topped up, the real video was generated from the same reference
## image and the same three approved VO lines already used for that
## placeholder, so nothing about the approved dialogue changed — only the
## delivery medium did, matching Stage 1/2's precedent exactly (plays at
## normal volume; the Smoke Lounge brand video's `-80dB` mute was a specific
## founder request for that one ambient asset, not a platform limitation).
##
## Failure-safety: a missing/corrupt video asset degrades to an immediate
## `finished` rather than hanging the boss-death sequence, and a 20s hard
## deadline covers a stalled decode or a browser that silently blocks
## autoplay-with-sound.

signal finished

const VIDEO_OLD := "res://src/assets/video/cutscenes/stage3_boss_defeat.ogv"
## Founder 2026-10-03: "defeating Boss 3" is THE transition into Episode 2. When this file is in the build it plays
## instead of the old cut; the boss then hands straight to Episode 2 (bandit_boss.gd).
const VIDEO_EP2 := "res://src/assets/video/cutscenes/stage3_boss_defeat_to_ep2.ogv"
## Hold JUMP this long to skip; a hard deadline well past the film's length covers a stalled decode.
const SKIP_HOLD := 1.0
const DEADLINE_SEC := 120.0
var VIDEO: String = VIDEO_EP2 if ResourceLoader.exists(VIDEO_EP2) else VIDEO_OLD
var _skip_held := 0.0
var _skip_armed := false
## When true the node is NOT freed at the end: the boss takes `make_cover()` (the film's last frame) and hands it to
## TransitionDirector.go() so the cut into Episode 2 never shows black (skill ep2-seamless-transition).
var keep_cover := false
var _cover_rect: Rect2 = Rect2()

var _video_player: VideoStreamPlayer = null
var _done := false
## Stage music leaves with a FADE (AudioManager.fade_out_music), not a Music-bus mute: a muted bus keeps the boss theme
## playing silently for the whole film and it re-enters mid-song the moment the bus is unmuted (the "boss-theme blip" at
## film end, 2026-10-22 hand-off audit). The film's own audio is on Master, so it is unaffected either way.
const MUSIC_FADE_SECONDS := 0.8

func play() -> void:
	layer = 5  # above HUD/gameplay, below the level-transition wipe (layer 10)
	# The film is skipped by HOLDING jump; ask for the on-screen controls so a touch
	# player can do it too (MobileLayoutManager keeps them through LEVEL_COMPLETE for
	# opted-in scenes only). Removed again in _finish().
	add_to_group("touch_controls_wanted")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(VIDEO):
		print("[VIDEO] %s: file missing from the build: %s (skipping the film)" % [name, VIDEO])
		_finish()
		return
	var stream: VideoStream = load(VIDEO) as VideoStream
	if stream == null:
		print("[VIDEO] %s: not decodable as a VideoStream: %s (skipping the film)" % [name, VIDEO])
		_finish()
		return

	var vid := VideoStreamPlayer.new()
	vid.name = "BossDefeatVideo"
	vid.stream = stream
	vid.expand = true
	vid.loop = false
	vid.volume_db = 0.0  # NOT muted — the video's own dialogue is the point.
	vid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vid)
	_video_player = vid
	_layout_video()
	# A phone rotated during the 15 s film must not leave the picture at its old pixel rect.
	get_viewport().size_changed.connect(_layout_video)
	vid.finished.connect(_finish)
	# Stage/boss music leaves with a fade so it does not play over the cutscene's own baked-in VO. (The bosses already
	# fade it at the top of die(); this makes the film correct on its own and is a harmless repeat after them.)
	AudioManager.fade_out_music(MUSIC_FADE_SECONDS)
	vid.play()

	get_tree().create_timer(DEADLINE_SEC, true, false, true).timeout.connect(_finish)

## Touch profile (read by MobileLayoutManager because the film joins group touch_controls_wanted): ONE wordless skip button
## with a hold ring (the `ep2_film` layout, which presses the ordinary `jump` action) instead of the whole platformer
## cluster over the 15 s film. The skip RULE is unchanged - hold jump for SKIP_HOLD seconds after one release - so
## keyboard and gamepad behave exactly as before; the ring is only a cue (its own timer is a shade shorter than SKIP_HOLD).
func touch_profile() -> StringName:
	return &"ep2_film"

## Fit the 16:9 film to the CURRENT viewport, filling and cropping (never letterboxed), and remember that rect for the
## cover. Runs at play() and on every viewport resize (rotation, a resized browser tab).
func _layout_video() -> void:
	if not is_instance_valid(_video_player):
		return
	_cover_rect = _fill_rect(get_viewport().get_visible_rect().size)
	_video_player.position = _cover_rect.position
	_video_player.size = _cover_rect.size

## The film's 1280x720 frame scaled to cover `vp` completely (cropping the overflow), centred.
static func _fill_rect(vp: Vector2) -> Rect2:
	var src := Vector2(1280.0, 720.0)
	var ar: float = src.x / maxf(1.0, src.y)
	var h: float = vp.y
	var w: float = h * ar
	if w < vp.x:
		w = vp.x
		h = w / ar
	return Rect2(Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5), Vector2(w, h))

func _process(delta: float) -> void:
	if _done:
		return
	# A JUMP still held from the boss fight must never skip the film (founder 2026-10-05 "the video isn't playing"):
	# the key has to be RELEASED once before a hold counts.
	if Input.is_action_pressed("jump"):
		if _skip_armed:
			_skip_held += delta
			if _skip_held >= SKIP_HOLD:
				_finish()
	else:
		_skip_held = 0.0
		_skip_armed = true

func _exit_tree() -> void:
	if is_instance_valid(_video_player):
		_video_player.stop()

## The film's last frame as a full-screen Control (a still image of the final video frame on black), for the
## seamless hand-off. Null if the video never produced a frame.
func make_cover() -> Control:
	# The rect comes from the viewport AS IT IS NOW (the part of this node that outlives the film: a phone rotated
	# during the film must not hand over a stale one).
	_cover_rect = _fill_rect(get_viewport().get_visible_rect().size)
	var frame: Texture2D = null
	if is_instance_valid(_video_player):
		var tex: Texture2D = _video_player.get_video_texture()
		if tex != null:
			var img: Image = tex.get_image()
			if img != null and not img.is_empty():
				frame = ImageTexture.create_from_image(img)
	return build_cover(frame)

## A full-screen cover: black, with `frame` (when there is one) anchored full-rect and stretched "covered" (fill + crop,
## like the film itself), so the picture keeps filling the screen if the phone is rotated again while the cover waits for
## Episode 2. A null frame (a skipped / undecodable film) is a plain black cover. Static so a test can build one from a
## synthetic texture (a headless renderer never yields a real video frame).
static func build_cover(frame: Texture2D) -> Control:
	var root := Control.new()
	root.name = "Stage3Cover"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	if frame != null:
		var tr := TextureRect.new()
		tr.name = "LastFrame"
		tr.texture = frame
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
	return root

func _finish() -> void:
	if _done:
		return
	_done = true
	remove_from_group("touch_controls_wanted")
	if get_viewport().size_changed.is_connected(_layout_video):
		get_viewport().size_changed.disconnect(_layout_video)
	finished.emit()
	if not keep_cover:
		queue_free()
