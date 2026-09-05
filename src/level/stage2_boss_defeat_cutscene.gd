class_name Stage2BossDefeatCutscene
extends CanvasLayer
## Stage 2 boss-defeat cutscene: Distributor (Crystalline Bureaucrat)
## shattered by the pickaxe -> Fort Knox vault door opens -> Gold Rush
## (Stage 3). Plays after the Distributor's own death tween (see
## distributor.gd::die()) and replaces its plain 3s "LEVEL COMPLETE!" Label
## wait — the queue_free() + SceneRouter.load_scene() that follows is
## untouched.
##
## Same architecture as src/level/stage1_boss_defeat_cutscene.gd: a real
## Seedance-2-generated video (shot list: docs/model-responses/2026-09-05-
## astra-stage2-defeat-cutscene.md; reference still: artifacts/founder-art/
## references/stage2_boss_defeat_cutscene_reference.jpg), encoded to Ogg
## Theora+Vorbis with its dialogue baked into the video's own audio track —
## no separate AudioStreamPlayer needed. Plays at normal volume; the Smoke
## Lounge brand video (secret_realm.gd) ships muted by specific founder
## request for that ambient asset, not because this engine can't play
## Theora+Vorbis audio.
##
## Failure-safety: a missing/corrupt video asset degrades to an immediate
## `finished` rather than hanging the boss-death sequence, and a 20s hard
## deadline covers a stalled decode or a browser that silently blocks
## autoplay-with-sound.

signal finished

const VIDEO := "res://src/assets/video/cutscenes/stage2_boss_defeat.ogv"

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
