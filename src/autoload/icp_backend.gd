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
## Emitted after a price fetch resolves, whatever the source. `source` is
## "icp" | "worker" | "offline" so the HUD can show provenance honestly.
signal prices_ready(prices: Dictionary, source: String)

## Populated from config.json → icp.leaderboard_canister_id.
var canister_id: String = ""
var price_feed_canister_id: String = ""
var gateway: String = "icp0.io"
## "https" on mainnet, "http" against a local replica.
var scheme: String = "https"
## 0 = default port for the scheme. A local replica listens on 4943.
var port: int = 0
## false = https://<id>.icp0.io (mainnet). true = <gateway>/path?canisterId=<id>
## (local replica, and anywhere wildcard DNS for *.localhost is unavailable).
var path_style: bool = false
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
	var cfg: Dictionary = icp
	canister_id = str(cfg.get("leaderboard_canister_id", ""))
	price_feed_canister_id = str(cfg.get("price_feed_canister_id", ""))
	gateway = str(cfg.get("gateway", "icp0.io"))
	# Only http/https are permitted. config.json is shipped in the export, so a
	# tampered file must not be able to point the client at an arbitrary scheme.
	var want_scheme := str(cfg.get("scheme", "https"))
	scheme = want_scheme if want_scheme in ["http", "https"] else "https"
	port = int(cfg.get("port", 0))
	path_style = bool(cfg.get("path_style", false))

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
	return canister_url(canister_id)

func canister_url(id: String) -> String:
	return endpoint(id, "", {})

## Build a canister URL in whichever addressing style is configured.
##
## The IC gateway accepts two forms and a local replica is far more reliable on
## the second, because `<id>.localhost` needs wildcard DNS that many machines
## (and this CI sandbox) simply don't resolve:
##   subdomain style — https://<id>.icp0.io/prices          (mainnet default)
##   path style      — http://127.0.0.1:4943/prices?canisterId=<id>  (local)
##
## Supporting both is not over-engineering: without path style there is no way
## to point the game at a local replica at all.
func endpoint(id: String, path: String, query: Dictionary = {}) -> String:
	var params := query.duplicate()
	var host := ""
	if path_style:
		host = gateway
		params["canisterId"] = id
	else:
		host = "%s.%s" % [id, gateway]
	var authority := "%s://%s" % [scheme, host]
	if port > 0:
		authority += ":%d" % port
	var url := authority + path
	if params.is_empty():
		return url
	var parts: PackedStringArray = []
	for k in params.keys():
		parts.append("%s=%s" % [
			String(k).uri_encode(), String(str(params[k])).uri_encode()])
	return url + "?" + "&".join(parts)

func has_price_feed() -> bool:
	return _is_valid_canister_id(price_feed_canister_id)

## Fetch token prices from the price-feed canister, falling back to the
## Cloudflare Worker's oracle and finally to whatever GameManager already
## cached. Always emits `prices_ready` exactly once.
##
## Every price lands in GameManager via set_crypto_price(), which ignores
## non-positive values — so a half-broken response can never blank a good
## price that is already on screen.
func fetch_prices() -> void:
	if not has_price_feed() or not icp_online or GameManager.offline_mode:
		_fallback_prices()
		return

	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			if code != 200:
				icp_online = false
				_fallback_prices()
				return
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if typeof(parsed) != TYPE_DICTIONARY:
				icp_online = false
				_fallback_prices()
				return
			var prices: Variant = (parsed as Dictionary).get("prices", {})
			if typeof(prices) != TYPE_DICTIONARY:
				_fallback_prices()
				return
			_publish_prices(prices, "icp")
	)
	if http.request(endpoint(price_feed_canister_id, "/prices")) != OK:
		http.queue_free()
		icp_online = false
		_fallback_prices()

## Push into GameManager's crypto_state so every listener updates by signal
## rather than polling this node (systems architecture §3.3).
func _publish_prices(prices: Dictionary, source: String) -> void:
	for symbol in prices.keys():
		GameManager.set_crypto_price(str(symbol).to_lower(), float(prices[symbol]))
	prices_ready.emit(prices, source)

## There is NO worker price fallback, and that is a fact about the project
## rather than an omission here: the Cloudflare Worker exposes /health, /oracle,
## /score, /leaderboard, /lore and /track — no price route. The price-feed
## canister is the first price source this game has ever had.
##
## So the honest degradation is "serve the last known values and label them
## offline", never a fabricated number. A HUD showing $0.00 for ETH reads as a
## crashed market; showing the previous price with a stale marker does not.
func _fallback_prices() -> void:
	var cached := {
		"eth": GameManager.get_crypto("eth_price"),
		"btc": GameManager.get_crypto("btc_price"),
		"titanx": GameManager.get_crypto("titanx_price"),
	}
	prices_ready.emit(cached, "offline")

## Fetch the top scores. `level` 0 means "all levels".
## Always calls back — with ICP data, Worker data, or an empty list.
func fetch_leaderboard(level: int = 0, limit: int = 25) -> void:
	if not has_canister() or not icp_online or GameManager.offline_mode:
		_fallback_leaderboard(level, limit)
		return

	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	var url := endpoint(canister_id, "/top", {"level": level, "limit": limit})
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
	if http.request(endpoint(canister_id, "/health")) != OK:
		http.queue_free()
		on_done.call(false, "request failed")

## Submit a run.
##
## Routes to the Cloudflare Worker, deliberately, and will keep doing so until
## Internet Identity is wired through JavaScriptBridge.
##
## WHY NOT POST TO THE CANISTER: an HTTP request to a canister arrives as the
## ANONYMOUS principal. The canister's submit() rejects anonymous callers by
## design, because a score nobody can be attributed to makes the on-chain board
## exactly as trustworthy as the Worker one — i.e. it would be theatre. Writing
## an HTTP write path here would look like progress and deliver none.
##
## The real write path is a Candid update call signed by the player's II
## identity. That needs agent-js in the browser; see
## docs/architecture/adr-icp-integration.md §"Write path".
func submit_score(score: int, level: int, on_done: Callable) -> void:
	Web3Bridge.submit_score(score, level, on_done)

## True once scores are actually going on-chain. Anything user-facing that
## claims "verified on ICP" must check this first rather than assuming.
func writes_are_onchain() -> bool:
	return false
