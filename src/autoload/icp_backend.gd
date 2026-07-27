extends Node
## Layer 4 — Internet Computer bridge.
##
## Reads the leaderboard from the ICP canister's HTTP gateway, and falls back
## to the existing Cloudflare Worker when ICP is unconfigured, slow, or down.
##
## DESIGN RULES (these are the reason this file is small and boring):
##  1. ICP is ADDITIVE. Nothing here is on the critical path to playing the
##     game. Every method degrades to the Worker, and the Worker already
##     degrades to offline mode. A dead canister must never cost a player a run.
##  2. Canister IDs live in config.json, never in code — same rule the project
##     already applies to contract addresses.
##  3. READS ONLY over HTTP. Score submission is an authenticated Candid update
##     call, which needs Internet Identity in the browser; until that ships,
##     writes keep going to the Worker and we do not pretend otherwise.
##     See docs/architecture/adr-icp-integration.md §"Write path".

signal leaderboard_ready(entries: Array, source: String)

## Populated from config.json → icp.leaderboard_canister_id.
var canister_id: String = ""
var gateway: String = "icp0.io"
## Flipped false after a failed read so we stop paying the timeout on every
## call; the Worker fallback takes over for the rest of the session.
var icp_online: bool = true

const REQUEST_TIMEOUT := 6.0

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if not FileAccess.file_exists("res://config.json"):
		return
	var f := FileAccess.open("res://config.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var icp: Variant = (parsed as Dictionary).get("icp", {})
	if typeof(icp) != TYPE_DICTIONARY:
		return
	canister_id = str((icp as Dictionary).get("leaderboard_canister_id", ""))
	gateway = str((icp as Dictionary).get("gateway", "icp0.io"))

## True only when a canister id is actually configured. Mirrors
## Web3Bridge.has_backend() so callers can branch the same way.
func has_canister() -> bool:
	return canister_id.strip_edges() != "" and _is_valid_canister_id(canister_id)

## Canister IDs are base32-with-dashes (e.g. "ryjl3-tyaaa-aaaaa-aaaba-cai").
## Validating before interpolating into a URL keeps a malformed/hostile config
## value from building a request to somewhere else entirely.
func _is_valid_canister_id(id: String) -> bool:
	var stripped := id.strip_edges()
	if stripped.length() < 10 or stripped.length() > 63:
		return false
	for c in stripped:
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "-"):
			return false
	return true

func base_url() -> String:
	return "https://%s.%s" % [canister_id, gateway]

## Fetch the top scores. `level` 0 means "all levels".
## Always calls back — with ICP data, Worker data, or an empty list.
func fetch_leaderboard(level: int = 0, limit: int = 25) -> void:
	if not has_canister() or not icp_online or GameManager.offline_mode:
		_fallback_leaderboard(level, limit)
		return

	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	var url := "%s/top?level=%d&limit=%d" % [base_url(), level, limit]
	http.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			if code != 200:
				# One strike and we stop trying for this session. A leaderboard
				# is not worth a 6-second stall on every menu open.
				icp_online = false
				_fallback_leaderboard(level, limit)
				return
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if typeof(parsed) != TYPE_DICTIONARY:
				icp_online = false
				_fallback_leaderboard(level, limit)
				return
			var entries: Variant = (parsed as Dictionary).get("entries", [])
			leaderboard_ready.emit(
				entries if typeof(entries) == TYPE_ARRAY else [], "icp")
	)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		icp_online = false
		_fallback_leaderboard(level, limit)

func _fallback_leaderboard(_level: int, _limit: int) -> void:
	if not Web3Bridge.has_backend():
		leaderboard_ready.emit([], "offline")
		return
	# Web3Bridge.get_leaderboard already handles its own offline cache, so this
	# path stays useful even with no network at all.
	Web3Bridge.get_leaderboard(func(entries: Array) -> void:
		leaderboard_ready.emit(entries, "worker"))

## Liveness probe for the canister. Used by docs/tools and the settings screen;
## deliberately not called on the hot path.
func check_health(on_done: Callable) -> void:
	if not has_canister():
		on_done.call(false, "no canister configured")
		return
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			on_done.call(code == 200, body.get_string_from_utf8())
	)
	if http.request(base_url() + "/health") != OK:
		http.queue_free()
		on_done.call(false, "request failed")

## Score submission is NOT implemented over HTTP on purpose: an HTTP POST to
## the canister arrives as the anonymous principal, so it could not be
## attributed to a player and would make the on-chain board no more trustworthy
## than the Worker one. Until Internet Identity is wired through
## JavaScriptBridge, writes stay on the Worker path that already works.
func submit_score(score: int, level: int, on_done: Callable) -> void:
	Web3Bridge.submit_score(score, level, on_done)
