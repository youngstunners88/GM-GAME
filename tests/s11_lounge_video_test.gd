extends Node2D
## S11 — Smoke Lounge brand-video wire-up gate.
##
## The founder supplied the $SMOKE LOUNGE clip (2026-08-16: a LANDSCAPE
## 1280x720, audio-free encode — replacing the original portrait clip); it is
## transcoded to src/assets/video/smoke_lounge.ogv (Ogg Theora, the only
## HTML5-safe format Godot 4.3 decodes, `-an` at the source so it carries no
## audio track at all). This proves:
##   1. the asset loads as a VideoStreamTheora,
##   2. the lounge builds a BrandVideo player carrying that stream, looping,
##   3. it is presented with a COVER fit — the player rect fills the ENTIRE
##      viewport on both axes (founder: "I want the entire screen to be
##      covered"), never leaving a gap on either edge,
##   4. it is MUTED regardless of the source track (belt-and-suspenders on top
##      of the audio-free encode, so the lounge's own background music is
##      never fought for the audio bus),
##   5. it sits IN FRONT of the -20 parallax room (so it is actually visible,
##      not occluded behind the opaque room jpg as the original wire-up was).
##
## Run: godot --headless res://tests/s11_lounge_video_test.tscn

const LOUNGE := preload("res://src/level/secret_realm.tscn")
const VIDEO_PATH := "res://src/assets/video/smoke_lounge.ogv"

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("S11 LOUNGE VIDEO:")
	# 1. Asset loads as a Theora stream.
	_check("brand video asset exists + loads as VideoStreamTheora",
		ResourceLoader.exists(VIDEO_PATH) and (load(VIDEO_PATH) is VideoStreamTheora),
		"missing or wrong type at %s" % VIDEO_PATH)

	var realm: Node = LOUNGE.instantiate()
	add_child(realm)
	for _i in range(4):
		await get_tree().process_frame

	# 2. The lounge built a BrandVideo player with the stream, looping.
	var vids: Array = []
	_collect(realm, vids)
	var vid: VideoStreamPlayer = vids[0] if not vids.is_empty() else null
	_check("lounge builds a BrandVideo player with a stream (looping)",
		vid != null and vid.stream != null and vid.loop,
		"no VideoStreamPlayer with a stream/loop found")

	if vid != null:
		# 3. COVER fit: the player rect must be >= the viewport on BOTH axes
		#    (within a tiny float-rounding tolerance) — i.e. it never leaves a
		#    gap for the room art to show through. This is the opposite
		#    assertion from the earlier "contain" gate (which required the
		#    rect to be SMALLER than the viewport on one axis, letterboxed).
		var vp: Vector2 = realm.get_viewport().get_visible_rect().size
		_check("brand video COVERS the entire screen (no gap on either axis)",
			vid.size.x >= vp.x - 0.5 and vid.size.y >= vp.y - 0.5,
			"rect %s vs viewport %s" % [str(vid.size), str(vp)])
		# 4. Muted regardless of the (now audio-free) source encode.
		_check("brand video is muted (no sound leaks over the lounge music)",
			vid.volume_db <= -40.0,
			"volume_db=%.1f (want <= -40)" % vid.volume_db)
		# 5. Visible layer: its CanvasLayer is in FRONT of the -20 plates and
		#    behind the gameplay plane (0).
		var cl := vid.get_parent() as CanvasLayer
		_check("brand video layer is in front of the room plates and behind gameplay",
			cl != null and cl.layer > -20 and cl.layer < 0,
			"layer=%s (want between -20 and 0)" % (str(cl.layer) if cl else "no CanvasLayer"))

	realm.queue_free()
	await get_tree().process_frame
	print("S11_LOUNGE_VIDEO: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _collect(n: Node, acc: Array) -> void:
	if n is VideoStreamPlayer:
		acc.append(n)
	for c in n.get_children():
		_collect(c, acc)
