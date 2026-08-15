extends Node2D
## S11 — Smoke Lounge brand-video wire-up gate.
##
## The founder supplied the $SMOKE LOUNGE clip (a PORTRAIT 720x1280 phone video);
## it was transcoded to src/assets/video/smoke_lounge.ogv (Ogg Theora, the only
## HTML5-safe format Godot 4.3 decodes). This proves:
##   1. the asset loads as a VideoStreamTheora,
##   2. the lounge builds a BrandVideo player carrying that stream, looping,
##   3. it is presented ASPECT-PRESERVED (not stretched to the landscape
##      viewport) — i.e. the player rect keeps the source's portrait ratio, so
##      the brand footage is not squashed,
##   4. it sits IN FRONT of the -20 parallax room (so it is actually visible,
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
		# 3. Aspect preserved: rect ratio ~ source portrait ratio (405/720=0.5625),
		#    NOT the landscape viewport ratio (~1.78). Guards against the squash.
		var rect_ar: float = vid.size.x / maxf(1.0, vid.size.y)
		_check("brand video is aspect-preserved (portrait, not stretched to landscape)",
			rect_ar < 1.0 and absf(rect_ar - (405.0 / 720.0)) < 0.05,
			"rect aspect %.3f (expected ~0.5625, portrait)" % rect_ar)
		# 4. Visible layer: its CanvasLayer is in FRONT of the -20 plates and
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
