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

const VIDEO := "res://src/assets/video/cutscenes/stage3_boss_defeat.ogv"

var _video_player: VideoStreamPlayer = null
var _done := false

func play() -> void:
	layer = 5  # above HUD/gameplay, below the level-transition wipe (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(VIDEO):
		_finish()
		return
	var stream: VideoStream = load(VIDEO) as VideoStream
	if stream == null:
		_finish()
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var src := Vector2(1280.0, 720.0)
	var ar: float = src.x / maxf(1.0, src.y)
	var h: float = vp.y
	var w: float = h * ar
	if w < vp.x:
		w = vp.x
		h = w / ar

	var vid := VideoStreamPlayer.new()
	vid.name = "BossDefeatVideo"
	vid.stream = stream
	vid.expand = true
	vid.loop = false
	vid.volume_db = 0.0  # NOT muted — the video's own dialogue is the point.
	vid.position = Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)
	vid.size = Vector2(w, h)
	vid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vid)
	_video_player = vid
	vid.finished.connect(_finish)
	vid.play()

	get_tree().create_timer(20.0, true, false, true).timeout.connect(_finish)

func _exit_tree() -> void:
	if is_instance_valid(_video_player):
		_video_player.stop()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
