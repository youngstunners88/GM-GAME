class_name Stage2BossDefeatCutscene
extends CanvasLayer
## Stage 2 boss-defeat cutscene: Distributor (Crystalline Bureaucrat)
## shattered by the pickaxe -> Fort Knox vault door opens -> chest reveal ->
## golden revolver claimed -> Gold Rush (Stage 3). Plays after the
## Distributor's own death tween (see distributor.gd::die()) and replaces its
## plain 3s "LEVEL COMPLETE!" Label wait — the queue_free() +
## SceneRouter.load_scene() that follows is untouched.
##
## Same architecture as src/level/stage1_boss_defeat_cutscene.gd: a real
## generated video, encoded to Ogg Theora+Vorbis with its dialogue baked into
## the video's own audio track — no separate AudioStreamPlayer needed. Plays
## at normal volume; the Smoke Lounge brand video (secret_realm.gd) ships
## muted by specific founder request for that ambient asset, not because this
## engine can't play Theora+Vorbis audio.
##
## EXTENDED (founder, 2026-09-16): the original ~15.1s cut (Seedance-2, shot
## list docs/model-responses/2026-09-05-astra-stage2-defeat-cutscene.md;
## reference artifacts/founder-art/references/stage2_boss_defeat_cutscene_
## reference.jpg) ended on the vault door opening. Lil Blunt then finds a
## treasure chest bearing the real GM logo (artifacts/founder-art/references/
## gm_logo.png, pulled from the founder's own Drive link), opens it, and
## lifts out the golden revolver — the same weapon Stage 3 now fires (see
## combat_handler.gd::_uses_revolver) and visibly holds (see
## player.gd::_update_tool_visual).
##
## CORRECTED (founder, 2026-09-16, 2nd pass — furious, all caps): "the video
## scene is an extension! Not a replacement! It is a continuation!" The FIRST
## attempt used Muapi's seedance-2.5-video-extend directly, which does not
## append — it regenerates its own version of the source clip's tail and
## blends into it, so the shipped ~18s result had already re-cut/altered the
## original vault-door footage by its first few seconds (confirmed by frame
## diffing against the true original: the AI output's very first frame is
## already a different shot, not a continuation of the last frame). That is
## a partial REPLACEMENT of founder-approved footage, not an extension, and
## is exactly what the correction rejects.
##
## The fix: the true original 15.104s file (recovered byte-for-byte from git
## history, commit 6df635c, pre-dating the first extend attempt) is now
## concatenated (ffmpeg concat filter, re-encoded once to a single Theora/
## Vorbis stream) with the SAME already-generated chest/revolver AI footage
## used the first time — no new paid generation call. The splice is a hard
## cut at 15.104s (verified frame-by-frame: t=15.5s is still the untouched
## vault-door footage, t=16.0s is already the new chest shot) — original
## footage first, unmodified, new footage appended after it. A hard cut
## between two shots is a normal edit; the founder's objection was to the
## ORIGINAL being altered, not to a scene change existing at all. Final
## duration is ~33.1s (15.104s original + 18.0s new, unchanged from the
## first attempt). The earlier same-day in-engine "bus smash" reveal beat
## (a placeholder built before this video pipeline was available) stays
## removed from distributor.gd — still redundant with this video's own
## reveal, unrelated to which cut of the video ships.
##
## Failure-safety: a missing/corrupt video asset degrades to an immediate
## `finished` rather than hanging the boss-death sequence, and a hard
## deadline (see _DEADLINE_SEC below) covers a stalled decode or a browser
## that silently blocks autoplay-with-sound.

signal finished

const VIDEO := "res://src/assets/video/cutscenes/stage2_boss_defeat.ogv"
## Real video length is ~33.1s (15.104s true original + 18.0s appended reveal
## footage — see the class comment's CORRECTED section). Must stay above that
## with real margin: the OLD 20.0s deadline predates the true-concatenation
## fix and would have silently cut the video off ~13s early.
const _DEADLINE_SEC := 40.0

var _video_player: VideoStreamPlayer = null
var _done := false
var _music_muted := false

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
	# Silence the stage/boss music so it doesn't play over the cutscene's own
	# baked-in VO. The video's audio is on the Master bus, so muting the Music
	# bus only kills the background track; restored in _finish() so the next
	# stage's music plays normally.
	_mute_stage_music()
	vid.play()

	get_tree().create_timer(_DEADLINE_SEC, true, false, true).timeout.connect(_finish)

func _exit_tree() -> void:
	if is_instance_valid(_video_player):
		_video_player.stop()
	# Safety: never leave the Music bus muted if we're torn down off the
	# normal _finish() path.
	_restore_stage_music()

func _mute_stage_music() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, true)
	_music_muted = true

func _restore_stage_music() -> void:
	if not _music_muted:
		return
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)
	_music_muted = false

func _finish() -> void:
	if _done:
		return
	_done = true
	_restore_stage_music()
	finished.emit()
	queue_free()
