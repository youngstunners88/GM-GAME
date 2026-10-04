extends Node
## NFT issuer — the six soulbound NFTs (a boss NFT and a test NFT for each stage).
##
## Contract: docs/nft/NFT_CONTRACT.md (one source for the game, the ICP canister and smokegame.win).
## Data: src/data/nft_collection.json — never hard-code ids, names or art here.
##
## FLOW (this order is deliberate):
##   1. A real game event arrives (boss killed / protocol exam PASSED).
##   2. We issue LOCALLY at once: instant congrats (card + jingle + short spoken line). Offline never blocks play.
##   3. We POST /issue to the nft_ledger canister. The canister stamps the issuance with ITS OWN clock
##      (Time.now() on the Internet Computer) — that is the on-chain date and time of issuance.
##   4. Only when the canister answers do we show/store the chain time. We NEVER show a made-up chain time.
##   5. Unconfirmed issuances are retried (next launch / next issuance). Idempotent on both sides.
##
## Phase 1 is client-reported and soulbound (cosmetic, no value) — see the contract's anti-cheat note.

signal nft_issued(nft_id: String, record: Dictionary)
signal nft_chain_confirmed(nft_id: String, record: Dictionary)

const COLLECTION_PATH := "res://src/data/nft_collection.json"
const SAVE_PATH := "user://nft_issued.json"
const JINGLE_PATHS := {
	"boss": "res://src/assets/nft/audio/jingle_boss.mp3",
	"test": "res://src/assets/nft/audio/jingle_test.mp3",
}
const VOICE_PATH_FMT := "res://src/assets/nft/audio/%s_voice.mp3"
const REQUEST_TIMEOUT := 8.0
const CARD_SECONDS := 5.5
const VOICE_GAIN_DB := 8.0
const JINGLE_GAIN_DB := 2.0
## Canister time as the canister prints it: 2026-10-04T12:34:56Z. Anything else is rejected.
const ISO_PATTERN := "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"

var _defs: Dictionary = {}            # nft_id -> definition
var _by_trigger: Dictionary = {}      # "event:key" -> nft_id
var _state: Dictionary = {"player_key": "", "issued": {}}
var _iso_re: RegEx = RegEx.new()
var _in_flight: bool = false
var _chain_failed_this_session: bool = false
var _card_queue: Array[String] = []
var _card_busy: bool = false
var _card_root: Control = null
var _card_chain_label: Label = null
var _card_nft_id: String = ""
var _jingle_player: AudioStreamPlayer = null
var _voice_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_iso_re.compile(ISO_PATTERN)
	_load_collection()
	_load_state()
	_jingle_player = _make_player(JINGLE_GAIN_DB)
	_voice_player = _make_player(VOICE_GAIN_DB)
	# Re-send anything the canister never confirmed (offline last time, canister id added since).
	get_tree().create_timer(4.0).timeout.connect(retry_pending)


# ---- Public API -----------------------------------------------------------

## A stage boss died. `boss_key` is the id GameManager uses: "auditor" | "distributor" | "claim_jumper".
func on_boss_defeated(boss_key: String) -> void:
	_issue_for_trigger("boss_defeated", boss_key, {})


## A protocol exam was PASSED (never called for a fail). `protocol` is "smoke" | "diamonds" | "gold".
func on_test_passed(protocol: String, score: int = -1, total: int = -1) -> void:
	_issue_for_trigger("test_passed", protocol, {"score": score, "total": total, "passed": true})


func has_nft(nft_id: String) -> bool:
	return (_state["issued"] as Dictionary).has(nft_id)


## Everything the player holds, newest data first-class for menus: [{id, name, issued, chain_iso, token_index}].
func holdings() -> Array:
	var out: Array = []
	for id in _defs.keys():
		var rec: Dictionary = (_state["issued"] as Dictionary).get(id, {})
		out.append({
			"id": id, "name": str(_defs[id].get("name", id)), "issued": not rec.is_empty(),
			"chain_iso": str(rec.get("chain_iso", "")), "token_index": int(rec.get("token_index", -1)),
		})
	return out


## The anonymous id the player pastes on smokegame.win to claim with Internet Identity.
func player_key() -> String:
	return str(_state.get("player_key", ""))


func copy_claim_key() -> void:
	DisplayServer.clipboard_set(player_key())


func definition(nft_id: String) -> Dictionary:
	return _defs.get(nft_id, {})


func collection_ids() -> Array:
	return _defs.keys()


## Issue by id (used by the triggers and by tests). Idempotent: a second call does nothing.
func issue(nft_id: String, meta: Dictionary = {}) -> bool:
	if not _defs.has(nft_id) or has_nft(nft_id):
		return false
	var rec := {"issued_local_unix": int(Time.get_unix_time_from_system()), "meta": meta,
		"chain_iso": "", "token_index": -1, "confirmed": false}
	(_state["issued"] as Dictionary)[nft_id] = rec
	_save_state()
	nft_issued.emit(nft_id, rec)
	_enqueue_card(nft_id)
	_submit_pending()
	return true


# ---- Triggers ---------------------------------------------------------------

func _issue_for_trigger(event: String, key: String, meta: Dictionary) -> void:
	var id: String = str(_by_trigger.get("%s:%s" % [event, key], ""))
	if id == "":
		return
	var m := meta.duplicate()
	m["stage"] = int(_defs[id].get("stage", 0))
	m["build"] = _build_tag()
	issue(id, m)


func _build_tag() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


# ---- Collection + state -----------------------------------------------------

func _load_collection() -> void:
	var f := FileAccess.open(COLLECTION_PATH, FileAccess.READ)
	if f == null:
		push_error("NftIssuer: collection file missing")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for d in SaveSafe.to_dict(parsed).get("nfts", []):
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := str(d.get("id", ""))
		var trig: Dictionary = SaveSafe.to_dict(d.get("trigger", {}))
		if id == "":
			continue
		_defs[id] = d
		_by_trigger["%s:%s" % [str(trig.get("event", "")), str(trig.get("key", ""))]] = id


func _load_state() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			var data: Dictionary = SaveSafe.to_dict(parsed)
			_state["player_key"] = _clean_key(str(data.get("player_key", "")))
			var raw: Dictionary = SaveSafe.to_dict(data.get("issued", {}))
			for id in raw.keys():
				if not _defs.has(id):
					continue  # a hand-edited save cannot invent an NFT
				var r: Dictionary = SaveSafe.to_dict(raw[id])
				var iso: String = SaveSafe.to_str(r.get("chain_iso", ""))
				(_state["issued"] as Dictionary)[id] = {
					"issued_local_unix": SaveSafe.to_int(r.get("issued_local_unix", 0)),
					"meta": SaveSafe.to_dict(r.get("meta", {})),
					"chain_iso": iso if _iso_re.search(iso) != null else "",
					"token_index": SaveSafe.to_int(r.get("token_index", -1), -1),
					"confirmed": bool(r.get("confirmed", false)) and _iso_re.search(iso) != null,
				}
	if str(_state["player_key"]) == "":
		_state["player_key"] = Crypto.new().generate_random_bytes(16).hex_encode()
		_save_state()


## 32 lowercase hex or nothing.
func _clean_key(k: String) -> String:
	if k.length() != 32:
		return ""
	for c in k:
		if not ((c >= "0" and c <= "9") or (c >= "a" and c <= "f")):
			return ""
	return k


func _save_state() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_state))
	f.close()


# ---- ICP issuance (HTTP update call to the nft_ledger canister) -----------

func retry_pending() -> void:
	_chain_failed_this_session = false
	_submit_pending()


func _submit_pending() -> void:
	if _in_flight or _chain_failed_this_session or not IcpBackend.has_nft_ledger():
		return
	if GameManager.offline_mode:
		return
	for id in (_state["issued"] as Dictionary).keys():
		var rec: Dictionary = _state["issued"][id]
		if not bool(rec.get("confirmed", false)):
			_post_issue(id, rec)
			return


func _post_issue(nft_id: String, rec: Dictionary) -> void:
	_in_flight = true
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_issue_done.bind(http, nft_id))
	var meta: Dictionary = SaveSafe.to_dict(rec.get("meta", {}))
	var body := JSON.stringify({"nft_id": nft_id, "player_key": player_key(), "meta": {
		"stage": SaveSafe.to_int(meta.get("stage", 0)),
		"score": meta.get("score", null), "total": meta.get("total", null),
		"passed": meta.get("passed", null), "build": str(meta.get("build", "")).left(40)}})
	var url := IcpBackend.endpoint(IcpBackend.nft_canister_id, "/issue")
	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_finish_request(http, false)


func _on_issue_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray,
		http: HTTPRequest, nft_id: String) -> void:
	var ok := false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		var d: Dictionary = SaveSafe.to_dict(parsed)
		var iso: String = SaveSafe.to_str(d.get("issued_at_iso", ""))
		# The reply is untrusted input: it must be OK, name THIS nft, and carry a well-formed canister time.
		if bool(d.get("ok", false)) and str(d.get("nft_id", "")) == nft_id and _iso_re.search(iso) != null \
				and (_state["issued"] as Dictionary).has(nft_id):
			var rec: Dictionary = _state["issued"][nft_id]
			rec["chain_iso"] = iso
			rec["token_index"] = SaveSafe.to_int(d.get("token_index", -1), -1)
			rec["confirmed"] = true
			_save_state()
			ok = true
			nft_chain_confirmed.emit(nft_id, rec)
			_update_card_chain_text(nft_id)
	_finish_request(http, ok)


func _finish_request(http: HTTPRequest, ok: bool) -> void:
	_in_flight = false
	if is_instance_valid(http):
		http.queue_free()
	if not ok:
		_chain_failed_this_session = true   # stop paying the timeout; retried next launch / next issuance
	else:
		_submit_pending()                   # drain the rest, one at a time


# ---- Congratulations: card + jingle + a short spoken line ------------------

func _make_player(gain_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Voice" if AudioServer.get_bus_index("Voice") != -1 else "SFX"
	p.volume_db = gain_db
	add_child(p)
	return p


func _enqueue_card(nft_id: String) -> void:
	_card_queue.append(nft_id)
	if not _card_busy:
		_next_card()


func _next_card() -> void:
	if _card_queue.is_empty():
		_card_busy = false
		return
	_card_busy = true
	var id: String = _card_queue.pop_front()
	_show_card(id)


func _show_card(nft_id: String) -> void:
	var d: Dictionary = _defs[nft_id]
	var rec: Dictionary = (_state["issued"] as Dictionary).get(nft_id, {})
	_card_nft_id = nft_id
	var layer := CanvasLayer.new()
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_card_root = Control.new()
	_card_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_card_root)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	sb.border_color = Color(1.0, 0.82, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14.0)
	card.add_theme_stylebox_override("panel", sb)
	var card_w := 620.0
	card.custom_minimum_size = Vector2(card_w, 0.0)
	var view_w: float = get_viewport().get_visible_rect().size.x
	card.position = Vector2((view_w - card_w) * 0.5, -190.0)  # top-centre, slides down from above
	_card_root.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(120.0, 120.0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Variant = load(str(d.get("art", "")))
	if tex is Texture2D:
		art.texture = tex
	row.add_child(art)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_label("NFT UNLOCKED", 15, Color(1.0, 0.82, 0.3)))
	col.add_child(_label(str(d.get("name", nft_id)), 28, Color(0.97, 0.98, 1.0)))
	col.add_child(_label(str(d.get("blurb", "")), 17, Color(0.78, 0.84, 0.9)))
	_card_chain_label = _label("", 14, Color(0.62, 0.7, 0.78))
	col.add_child(_card_chain_label)
	_update_card_chain_text(nft_id, rec)

	_play_congrats(d)
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(card, "position:y", 18.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(CARD_SECONDS)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.finished.connect(func() -> void:
		layer.queue_free()
		_card_root = null
		_card_chain_label = null
		_card_nft_id = ""
		_next_card())


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Honest status line: the ICP time appears only once the canister has confirmed it.
func _update_card_chain_text(nft_id: String, rec: Dictionary = {}) -> void:
	if _card_chain_label == null or not is_instance_valid(_card_chain_label) or nft_id != _card_nft_id:
		return
	if rec.is_empty():
		rec = (_state["issued"] as Dictionary).get(nft_id, {})
	if bool(rec.get("confirmed", false)):
		var iso: String = str(rec.get("chain_iso", ""))
		_card_chain_label.text = "On ICP: %s %s UTC  ·  #%d   (C = copy claim key)" % [
			iso.substr(0, 10), iso.substr(11, 8), int(rec.get("token_index", 0))]
	elif IcpBackend.has_nft_ledger():
		_card_chain_label.text = "Recording on the Internet Computer…"
	else:
		_card_chain_label.text = "Saved. Recording on ICP soon.  (C = copy claim key)"


func _play_congrats(d: Dictionary) -> void:
	var kind := str(d.get("kind", "boss"))
	var jingle: Variant = load(str(JINGLE_PATHS.get(kind, JINGLE_PATHS["boss"])))
	if jingle is AudioStream:
		_jingle_player.stream = jingle
		_jingle_player.play()
	var voice: Variant = load(VOICE_PATH_FMT % str(d.get("id", "")))
	if voice is AudioStream:
		_voice_player.stream = voice
		# Jingle first, then the line — short and not on top of each other.
		get_tree().create_timer(1.7, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(_voice_player):
				_voice_player.play())


func _unhandled_input(event: InputEvent) -> void:
	if _card_root != null and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_C:
		copy_claim_key()
