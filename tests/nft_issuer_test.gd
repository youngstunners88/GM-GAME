extends Node
## The six NFTs (boss + test per stage): collection integrity, issuance rules, ICP reply validation, congrats audio+card.
## Run: godot --headless res://tests/nft_issuer_test.tscn   (autoload-dependent, so a scene, not --script)

const IDS := ["boss_auditor", "boss_distributor", "boss_claimjumper", "test_smoke", "test_diamonds", "test_gold"]
var _fail := 0

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _reset() -> void:
	NftIssuer._state = {"player_key": NftIssuer.player_key(), "issued": {}}
	NftIssuer._card_queue.clear()
	NftIssuer._chain_failed_this_session = false

func _ready() -> void:
	await get_tree().process_frame
	print("NFT ISSUER:")
	var ids: Array = NftIssuer.collection_ids()
	ids.sort()
	var want := IDS.duplicate(); want.sort()
	_check("exactly the six contract ids", ids == want, str(ids))
	for id in IDS:
		var d: Dictionary = NftIssuer.definition(id)
		_check("%s art exists" % id, ResourceLoader.exists(str(d.get("art", ""))))
		_check("%s spoken line is short" % id, str(d.get("spoken", "")).length() > 5 and str(d.get("spoken", "")).length() < 60)
		_check("%s voice clip exists" % id, ResourceLoader.exists(NftIssuer.VOICE_PATH_FMT % id))
	for k in NftIssuer.JINGLE_PATHS.values():
		_check("jingle exists %s" % k.get_file(), ResourceLoader.exists(k))
	var kinds := {}
	for id in IDS:
		var d: Dictionary = NftIssuer.definition(id)
		kinds["%s_%s" % [d.get("kind"), d.get("stage")]] = true
	_check("each stage has one boss NFT and one test NFT", kinds.size() == 6)

	_reset()
	_check("player key is 32 lowercase hex", NftIssuer._clean_key(NftIssuer.player_key()) == NftIssuer.player_key() and NftIssuer.player_key().length() == 32)
	# Triggers
	NftIssuer.on_boss_defeated("auditor")
	_check("Auditor kill issues Tax Evader", NftIssuer.has_nft("boss_auditor"))
	NftIssuer.on_boss_defeated("auditor")
	_check("second kill does not issue again (soulbound, once)", (NftIssuer._state["issued"] as Dictionary).size() == 1)
	NftIssuer.on_boss_defeated("not_a_boss")
	_check("unknown boss issues nothing", (NftIssuer._state["issued"] as Dictionary).size() == 1)
	NftIssuer.on_test_passed("gold", 9, 11)
	_check("passing the GOLD exam issues GOLD Scholar", NftIssuer.has_nft("test_gold"))
	_check("no on-chain time is shown before the canister confirms", str(NftIssuer._state["issued"]["test_gold"]["chain_iso"]) == "")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("congrats card is on screen", NftIssuer._card_root != null and is_instance_valid(NftIssuer._card_root))
	_check("jingle is playing", NftIssuer._jingle_player.playing or NftIssuer._jingle_player.stream != null)

	# ICP reply validation (the reply is untrusted)
	var http := HTTPRequest.new(); add_child(http)
	var good := JSON.stringify({"ok": true, "nft_id": "boss_auditor", "token_index": 7, "issued_at_iso": "2026-10-04T12:34:56Z"}).to_utf8_buffer()
	NftIssuer._in_flight = true
	NftIssuer._on_issue_done(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), good, http, "boss_auditor")
	var rec: Dictionary = NftIssuer._state["issued"]["boss_auditor"]
	_check("canister reply stores the chain time and token index", rec["confirmed"] == true and rec["chain_iso"] == "2026-10-04T12:34:56Z" and rec["token_index"] == 7)
	var http2 := HTTPRequest.new(); add_child(http2)
	var bad_time := JSON.stringify({"ok": true, "nft_id": "test_gold", "token_index": 1, "issued_at_iso": "yesterday <b>"}).to_utf8_buffer()
	NftIssuer._in_flight = true
	NftIssuer._on_issue_done(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), bad_time, http2, "test_gold")
	_check("a malformed chain time is rejected", NftIssuer._state["issued"]["test_gold"]["confirmed"] == false)
	var http3 := HTTPRequest.new(); add_child(http3)
	var wrong_id := JSON.stringify({"ok": true, "nft_id": "boss_auditor", "token_index": 1, "issued_at_iso": "2026-10-04T12:34:56Z"}).to_utf8_buffer()
	NftIssuer._in_flight = true
	NftIssuer._on_issue_done(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), wrong_id, http3, "test_gold")
	_check("a reply naming a different NFT is rejected", NftIssuer._state["issued"]["test_gold"]["confirmed"] == false)

	# Hostile save cannot invent NFTs or fake a chain time
	var f := FileAccess.open(NftIssuer.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"player_key": "NOT-HEX", "issued": {"made_up": {"chain_iso": "2026-01-01T00:00:00Z"}, "test_smoke": {"chain_iso": "garbage", "confirmed": true, "token_index": [1]}}}))
	f.close()
	NftIssuer._state = {"player_key": "", "issued": {}}
	NftIssuer._load_state()
	_check("hostile save: invented id dropped", not NftIssuer.has_nft("made_up"))
	_check("hostile save: bad time cannot be 'confirmed'", NftIssuer.has_nft("test_smoke") and NftIssuer._state["issued"]["test_smoke"]["confirmed"] == false)
	_check("hostile save: bad player key regenerated", NftIssuer.player_key().length() == 32)

	# Wiring (source-level: the real events call us)
	for pair in [["res://src/boss/auditor.gd", 'mark_boss_defeated("auditor")'], ["res://src/boss/distributor.gd", 'mark_boss_defeated("distributor")'],
			["res://src/boss/claim_jumper.gd", 'mark_boss_defeated("claim_jumper")'], ["res://src/protocol_portals/StudyRoom.gd", "NftIssuer.on_test_passed"],
			["res://src/autoload/game_manager.gd", "NftIssuer.on_boss_defeated"]]:
		_check("%s is wired" % pair[0].get_file(), FileAccess.get_file_as_string(pair[0]).contains(pair[1]))
	_reset(); NftIssuer._save_state()
	print("NFT_ISSUER: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
