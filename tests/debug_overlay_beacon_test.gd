extends Node
## DEBUG_OVERLAY_BEACON: the schema scripts/lib/pw.mjs and scripts/mobile-transition-probe.mjs read from window.__gm,
## and the on-demand visible-text list the wordless checks use. Headless: the postMessage itself is web-only, so this
## drives the pure parts (_beacon_value, _compose, collect_words) and the "off by default" contract.

var _fail: int = 0

func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fail += 1

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	_check("overlay is OFF by default (never covers normal play, no beacon)", not DebugOverlay.is_on())

	# --- beacon schema (scalars only) -------------------------------------------------------------------------
	var v: Dictionary = DebugOverlay._beacon_value()
	for k: String in ["t", "build", "harness", "state", "paused", "time_scale", "scene", "td", "td_frozen", "held",
			"touch", "win", "frames", "avg_ms", "worst_ms", "worst_all_ms", "mem_mb", "mem_peak_mb", "tex_mb", "tex_peak_mb"]:
		_check("beacon has '%s'" % k, v.has(k))
	var touch: Dictionary = v.get("touch", {})
	for k: String in ["shown", "susp", "profile", "layout", "held"]:
		_check("beacon.touch has '%s'" % k, touch.has(k))
	_check("beacon.harness is false in this (untagged) build", v.get("harness", true) == false)
	_check("beacon.touch.held mirrors TouchActions.held_count()", int(touch.get("held", -1)) == TouchActions.held_count())
	_check("beacon.state mirrors StateMachine", str(v.get("state", "")) == StateMachine.get_current_state())
	var json := JSON.stringify({"type": "gm", "value": v})
	_check("the payload is one JSON line (postMessage template safe)", json != "" and not json.contains("\n"))
	var back: Variant = JSON.parse_string(json)
	_check("the payload round-trips through JSON", back is Dictionary and (back as Dictionary).get("type") == "gm")
	TouchActions.press(&"move_right")
	_check("a held touch action shows up in beacon.touch.held", int(DebugOverlay._beacon_value()["touch"]["held"]) == 1)
	TouchActions.release_all()
	_check("...and is gone after release_all()", int(DebugOverlay._beacon_value()["touch"]["held"]) == 0)

	# --- the label lines -----------------------------------------------------------------------------------------
	var label: String = DebugOverlay._compose()
	for tag: String in ["STATE ", "SCENE ", "TOUCH touch shown=", "FRAME avg ", "INPUT held:"]:
		_check("label has a '%s' line" % tag.strip_edges(), label.contains(tag))

	# --- visible-text list -----------------------------------------------------------------------------------------
	var host := Control.new()
	host.name = "WordsHost"
	add_child(host)
	var seen := Label.new(); seen.name = "Seen"; seen.text = "SEEN WORD"; host.add_child(seen)
	var hid := Label.new(); hid.name = "Hid"; hid.text = "HIDDEN WORD"; hid.visible = false; host.add_child(hid)
	var ghost := Label.new(); ghost.name = "Ghost"; ghost.text = "GHOST WORD"; ghost.modulate.a = 0.0; host.add_child(ghost)
	var branch := Control.new(); branch.name = "HiddenBranch"; branch.visible = false; host.add_child(branch)
	var inbranch := Label.new(); inbranch.name = "InBranch"; inbranch.text = "BRANCH WORD"; branch.add_child(inbranch)
	var btn := Button.new(); btn.name = "Btn"; btn.text = "A BUTTON"; host.add_child(btn)
	var secret := LineEdit.new(); secret.name = "Secret"; secret.secret = true; secret.text = "hunter2"
	secret.placeholder_text = "code"; host.add_child(secret)
	var layer := CanvasLayer.new(); layer.name = "OffLayer"; layer.visible = false; add_child(layer)
	var onlayer := Label.new(); onlayer.name = "OnLayerWord"; onlayer.text = "LAYER WORD"; layer.add_child(onlayer)
	await get_tree().process_frame
	var words: Array = DebugOverlay.collect_words()
	var texts: Array[String] = []
	for w: Dictionary in words:
		texts.append(str(w["text"]))
	_check("words: a visible Label is listed", "SEEN WORD" in texts)
	_check("words: a visible Button is listed", "A BUTTON" in texts)
	_check("words: a hidden Label is not", not ("HIDDEN WORD" in texts))
	_check("words: a fully transparent Label is not", not ("GHOST WORD" in texts))
	_check("words: a Label under a hidden branch is not", not ("BRANCH WORD" in texts))
	_check("words: a Label under a hidden CanvasLayer is not", not ("LAYER WORD" in texts))
	_check("words: a secret LineEdit reports only its placeholder", "code" in texts and not ("hunter2" in texts))
	var seen_rect: Array = []
	for w: Dictionary in words:
		if str(w["text"]) == "A BUTTON":
			seen_rect = w.get("rect", [])
	_check("words: a Control entry carries a window-pixel rect [x,y,w,h]", seen_rect.size() == 4 and int(seen_rect[2]) > 0 and int(seen_rect[3]) > 0)
	_check("words: each entry has path + text", words.size() > 0 and (words[0] as Dictionary).has("path") and (words[0] as Dictionary).has("text"))
	DebugOverlay._label.text = "OWN LABEL TEXT"          # give the overlay's own label something to (wrongly) report
	DebugOverlay._label.visible = true
	var own: Array[String] = []
	for w: Dictionary in DebugOverlay.collect_words():
		if str(w["path"]).begins_with(str(DebugOverlay.get_path()) + "/"):
			own.append("%s=%s" % [w["path"], w["text"]])
	_check("words: the overlay's own label is excluded (%s)" % ", ".join(own), own.is_empty())
	DebugOverlay._label.visible = false
	DebugOverlay._label.text = ""
	for i in 400:
		var l := Label.new(); l.text = "FILL %d" % i; host.add_child(l)
	_check("words: capped at WORDS_MAX (%d)" % DebugOverlay.WORDS_MAX, DebugOverlay.collect_words().size() == DebugOverlay.WORDS_MAX)
	host.queue_free()
	layer.queue_free()
	print("DEBUG_OVERLAY_BEACON: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
