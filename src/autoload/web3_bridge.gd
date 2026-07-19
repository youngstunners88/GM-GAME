extends Node
## Web3Bridge (autoload) — the single seam between the game (Book Layer) and the
## Movie/Video-Game layers (wallet, on-chain badge, token-gated perks, on-chain
## leaderboard, Mistral Oracle, community lore, funnel analytics). See
## LAYER_SHIFT.md for how each maps to the coach's framework.
##
## Design principles:
## - EVERY method degrades gracefully. No config / not on web / no wallet /
##   backend down → the game plays exactly as before (Book Layer intact). The
##   Movie/Video-Game value is ADDITIVE, never a gate on core play.
## - NO secrets or real addresses in code. All wiring loads from res://config.json
##   (CLAUDE.md Global Rule). API keys live ONLY in the backend proxy.
## - The browser half is web/web3.js (plain window.ethereum JSON-RPC + fetch),
##   called via JavaScriptBridge on the Web export; other platforms no-op.

signal wallet_connected(address: String)
signal wallet_failed(reason: String)
signal balances_refreshed()
## Offline mode (Video-Game Layer): fires on every online<->offline flip.
signal connectivity_changed(online: bool)

var config: Dictionary = {}
var wallet_address: String = ""
var token_balances: Dictionary = {}   # "smoke"/"diamonds"/"goldmine" -> float
var _js_ready := false
var _bridge = null

# ---- Offline mode state (offline-mode skill) ----------------------------
## True once a health probe has succeeded this session. Starts false and is
## only meaningful when a backend is configured at all.
var backend_online: bool = false
var _health_checked_once: bool = false
const ANALYTICS_QUEUE_PATH := "user://analytics_queue.json"
const LEADERBOARD_CACHE_PATH := "user://leaderboard_cache.json"
const HEALTH_TIMEOUT := 5.0
const RECONNECT_INTERVAL := 30.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	_init_js()
	_start_health_loop()

## Boot health check (5s timeout) + 30s reconnect probes while offline.
## No backend configured -> permanently offline-quiet (no banner nagging:
## that's the pre-deploy state, not a network failure).
func _start_health_loop() -> void:
	if not has_backend():
		return
	_probe_health()
	var t := Timer.new()
	t.wait_time = RECONNECT_INTERVAL
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		if not backend_online:
			_probe_health())

func _probe_health() -> void:
	var http := HTTPRequest.new()
	http.timeout = HEALTH_TIMEOUT
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _d) -> void:
		_on_health_result(code >= 200 and code < 300)
		http.queue_free())
	var err := http.request(config["backend_base_url"].rstrip("/") + "/health")
	if err != OK:
		_on_health_result(false)
		http.queue_free()

func _on_health_result(ok: bool) -> void:
	var was := backend_online
	backend_online = ok
	var first := not _health_checked_once
	_health_checked_once = true
	if was != ok or first:
		connectivity_changed.emit(ok)
	if ok and (first or not was):
		_flush_analytics_queue()

## True when calls should actually hit the network.
func is_online() -> bool:
	return has_backend() and backend_online

# ---- Analytics offline queue ---------------------------------------------

## Queue one analytics payload for later delivery (bounded at 200 entries).
func _queue_analytics(path: String, body: Dictionary) -> void:
	var q: Array = []
	if FileAccess.file_exists(ANALYTICS_QUEUE_PATH):
		var f := FileAccess.open(ANALYTICS_QUEUE_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_ARRAY:
				q = parsed
	q.append({"path": path, "body": body})
	if q.size() > 200:
		q = q.slice(q.size() - 200)
	var w := FileAccess.open(ANALYTICS_QUEUE_PATH, FileAccess.WRITE)
	if w:
		w.store_string(JSON.stringify(q))

## Silent sync on reconnect: replay the queue, then clear it.
func _flush_analytics_queue() -> void:
	if not FileAccess.file_exists(ANALYTICS_QUEUE_PATH):
		return
	var f := FileAccess.open(ANALYTICS_QUEUE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		DirAccess.remove_absolute(ANALYTICS_QUEUE_PATH)
		return
	for item in (parsed as Array):
		if typeof(item) == TYPE_DICTIONARY:
			_backend("POST", str(item.get("path", "/event")), item.get("body", {}), func(_x): pass)
	DirAccess.remove_absolute(ANALYTICS_QUEUE_PATH)
	track("offline_sync_completed")

func _load_config() -> void:
	if not FileAccess.file_exists("res://config.json"):
		return
	var f := FileAccess.open("res://config.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		config = parsed

## Load web/web3.js into the page and grab a handle. Web export only.
func _init_js() -> void:
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge") and not ClassDB.class_exists("JavaScriptBridge"):
		return
	# JavaScriptBridge is a global in web builds.
	_bridge = Engine.get_singleton("JavaScriptBridge") if Engine.has_singleton("JavaScriptBridge") else null
	# The launcher/page defines window.LilBluntWeb3 (web/web3.js). Confirm it exists.
	var has := JavaScriptBridge.eval("typeof window.LilBluntWeb3 !== 'undefined'", true)
	_js_ready = bool(has)

## Strict 0x-hex sanitizer for anything interpolated into a JavaScriptBridge.eval
## string (wallet + contract addresses). A value that matches ^0x[0-9a-fA-F]+$
## cannot contain quotes, semicolons, or any JS — so interpolating the RESULT is
## injection-proof. Anything else returns "" and the call soft-fails. This is the
## invariant the security sentinel's INJ-003 check enforces.
func _hex(s: String) -> String:
	var re := RegEx.new()
	re.compile("^0x[0-9a-fA-F]{1,64}$")
	return s if re.search(s) != null else ""

func has_backend() -> bool:
	return config.get("backend_base_url", "") != ""

func is_web3_available() -> bool:
	return _js_ready and OS.has_feature("web")

# ---- Wallet -------------------------------------------------------------

## Ask the browser wallet (window.ethereum) to connect. Fills wallet_address
## and emits wallet_connected, or wallet_failed. No-op off-web.
func connect_wallet() -> void:
	if not is_web3_available():
		wallet_failed.emit("No wallet available (play on the web build with a wallet extension).")
		return
	JavaScriptBridge.eval("window.LilBluntWeb3.connect();", true)
	# web3.js calls back into the game via a hidden signal element it polls;
	# here we poll the last-known address it wrote to window.LilBluntWeb3.addr.
	await get_tree().create_timer(1.2).timeout
	var addr := str(JavaScriptBridge.eval("window.LilBluntWeb3.addr || ''", true))
	if addr.begins_with("0x") and addr.length() == 42:
		wallet_address = addr
		wallet_connected.emit(addr)
		await _refresh_token_balances()
	else:
		wallet_failed.emit("Wallet connection was declined or unavailable.")

func short_address(addr: String = "") -> String:
	var a := addr if addr != "" else wallet_address
	if a.length() < 12:
		return a
	return a.substr(0, 6) + "..." + a.substr(a.length() - 4, 4)

# ---- Token-gated perks (Movie Layer) -----------------------------------

## Real ERC-20 balanceOf via the browser (eth_call). Populates token_balances.
## Falls back to 0 everywhere if unavailable — perks simply don't unlock.
## eth_call is ASYNC: web3.js kicks the request and caches the result when the
## promise resolves, so a single synchronous read would return the stale "0".
## We therefore do it in two phases — kick every call, await the resolve window,
## then read the now-populated cache — and emit balances_refreshed when done.
## `await` this before relying on holds() (PR #5 review).
func _refresh_token_balances() -> void:
	token_balances = {"smoke": 0.0, "diamonds": 0.0, "goldmine": 0.0}
	var owner: String = _hex(wallet_address)
	if owner == "":
		balances_refreshed.emit()
		return
	# PREFERRED PATH (cross-chain finding, 2026-07-19): SMOKE lives on Base but
	# DIAMONDS/GOLD live on Ethereum, and a wallet-provider eth_call only sees
	# the wallet's current chain. The backend /balances endpoint reads each
	# token on its own chain (stateless, read-only). Wallet-provider path stays
	# as the fallback so nothing regresses if the backend is down.
	if is_online():
		_backend("GET", "/balances?owner=" + owner, {}, func(res: Variant) -> void:
			if typeof(res) == TYPE_DICTIONARY and (res as Dictionary).get("ok", false):
				var b: Dictionary = (res as Dictionary).get("balances", {})
				for key in ["smoke", "diamonds", "goldmine"]:
					token_balances[key] = str(b.get(key, "0")).to_float()
			balances_refreshed.emit())
		return
	if not is_web3_available():
		balances_refreshed.emit()
		return
	var contracts: Dictionary = config.get("contracts", {})
	# Phase 1 — kick each async eth_call (result caches into web3.js on resolve).
	for key in ["smoke", "diamonds", "goldmine"]:
		var addr: String = _hex(contracts.get(key + "_erc20", ""))
		if addr != "":
			JavaScriptBridge.eval(
				"window.LilBluntWeb3.balanceOf('%s','%s')" % [_hex(addr), _hex(owner)], true)
	# Let the promises resolve before reading the cache back.
	await get_tree().create_timer(0.8).timeout
	# Phase 2 — read the now-populated cache (balanceOf returns cached value).
	for key in ["smoke", "diamonds", "goldmine"]:
		var addr: String = _hex(contracts.get(key + "_erc20", ""))
		if addr == "":
			continue
		var raw := str(JavaScriptBridge.eval(
			"window.LilBluntWeb3.balanceOf('%s','%s')" % [_hex(addr), _hex(owner)], true))
		token_balances[key] = raw.to_float() if raw.is_valid_float() else 0.0
	balances_refreshed.emit()

## Public re-check: refresh balances for the connected wallet and return when
## populated. Call (awaited) before a run so perks reflect latest holdings.
func refresh_balances() -> void:
	await _refresh_token_balances()

func holds(token: String) -> bool:
	return token_balances.get(token, 0.0) > 0.0

# ---- On-chain badge (Movie Layer) --------------------------------------

## Fire the mint tx for the SmokeRing Survivor badge. Returns immediately;
## the wallet handles confirmation. Inert (returns false) until the badge
## contract address is set in config.json.
func mint_survivor_badge() -> bool:
	var contract: String = _hex(config.get("contracts", {}).get("survivor_badge_erc721", ""))
	if not is_web3_available() or wallet_address == "" or contract == "":
		return false
	JavaScriptBridge.eval("window.LilBluntWeb3.mintBadge('%s');" % _hex(contract), true)
	track("badge_mint_initiated")
	return true

func badge_explorer_url() -> String:
	var base: String = config.get("explorer_base_url", "")
	var contract: String = config.get("contracts", {}).get("survivor_badge_erc721", "")
	if base == "" or contract == "":
		return ""
	return "%s/token/%s" % [base, contract]

# ---- Backend: leaderboard / oracle / lore / analytics (Video Game Layer)

## POST/GET the backend proxy. Returns parsed JSON (Dictionary/Array) or an
## empty result on any failure — callers must handle empties. The proxy holds
## the Mistral key; the client never sees it.
func _backend(method: String, path: String, body: Dictionary, on_done: Callable) -> void:
	if not has_backend():
		on_done.call({})
		return
	var http := HTTPRequest.new()
	# Bounded: a configured-but-unreachable backend must degrade, never hang UI
	# that awaits the callback (e.g. the first-play email panel — PR #6 review).
	# On timeout request_completed still fires (RESULT_TIMEOUT, code 0) → {}.
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, data):
		# Variant, NOT `:= {}`: inference would lock this to Dictionary and
		# CRASH on array responses (/leaderboard, /hall-of-blaze). Latent until
		# a live backend existed — caught by kimi-review on deploy day.
		var out: Variant = {}
		if code >= 200 and code < 300:
			var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
			if typeof(parsed) in [TYPE_DICTIONARY, TYPE_ARRAY]:
				out = parsed
		on_done.call(out)
		http.queue_free())
	var url: String = config["backend_base_url"].rstrip("/") + path
	var headers := ["Content-Type: application/json"]
	var err := http.request(url, headers,
		HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET,
		JSON.stringify(body) if method == "POST" else "")
	if err != OK:
		on_done.call({})
		http.queue_free()

func ask_oracle(question: String, on_answer: Callable) -> void:
	_backend("POST", "/oracle", {"question": question, "wallet_address": wallet_address}, on_answer)

func submit_score(score: int, level: int, on_done: Callable) -> void:
	_backend("POST", "/score", {
		"score": score, "level": level, "wallet_address": wallet_address}, on_done)

func get_leaderboard(on_list: Callable) -> void:
	# Offline mode: serve the last good board from local cache; online fetches
	# refresh that cache so the next outage still shows real standings.
	if has_backend() and _health_checked_once and not backend_online:
		on_list.call(_read_leaderboard_cache())
		return
	_backend("GET", "/leaderboard", {}, func(res: Variant) -> void:
		if typeof(res) == TYPE_ARRAY and not (res as Array).is_empty():
			var w := FileAccess.open(LEADERBOARD_CACHE_PATH, FileAccess.WRITE)
			if w:
				w.store_string(JSON.stringify(res))
		on_list.call(res))

func _read_leaderboard_cache() -> Array:
	if not FileAccess.file_exists(LEADERBOARD_CACHE_PATH):
		return []
	var f := FileAccess.open(LEADERBOARD_CACHE_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return (parsed as Array) if typeof(parsed) == TYPE_ARRAY else []

func submit_lore(text: String, on_done: Callable) -> void:
	_backend("POST", "/lore", {"text": text.substr(0, 200), "wallet_address": wallet_address}, on_done)

## Fire-and-forget anonymous funnel analytics (which buttons get clicked).
## Offline: queued to user://analytics_queue.json, flushed on reconnect.
func track(event: String) -> void:
	if not has_backend():
		return
	if _health_checked_once and not backend_online:
		_queue_analytics("/track", {"event": event})
		return
	_backend("POST", "/track", {"event": event}, func(_x): pass)

# ---- AgentMail marketing engine (ADDITIVE — see AGENTMAIL_SETUP.md) --------
# A stable pseudonymous player id ties email/deaths/rank together server-side.
# It is a random UUID stored locally — NOT derived from anything personal.

const PLAYER_ID_PATH := "user://player_id.txt"
var _player_id: String = ""

## Persistent random player id (created on first call).
func player_id() -> String:
	if _player_id != "":
		return _player_id
	if FileAccess.file_exists(PLAYER_ID_PATH):
		var f := FileAccess.open(PLAYER_ID_PATH, FileAccess.READ)
		if f:
			_player_id = f.get_as_text().strip_edges()
	if _player_id == "":
		_player_id = "p" + str(Time.get_unix_time_from_system()) + str(randi() % 1000000)
		var w := FileAccess.open(PLAYER_ID_PATH, FileAccess.WRITE)
		if w:
			w.store_string(_player_id)
	return _player_id

## TASK 1: opt-in email signup (consent is explicit; validated server-side too).
func signup_email(email: String, consent: bool, name: String, on_done: Callable) -> void:
	_backend("POST", "/email/signup", {
		"player_id": player_id(),
		"email": email.strip_edges().substr(0, 254),
		"consent": consent,
		"name": name.substr(0, 40),
		"wallet_address": wallet_address,
	}, on_done)

## TASK 5: invite a friend by email (referral engine).
func invite_friend(friend_email: String, on_done: Callable) -> void:
	_backend("POST", "/referral", {
		"player_id": player_id(),
		"friend_email": friend_email.strip_edges().substr(0, 254),
		"player_name": short_address() if wallet_address != "" else "a Smoke Realm player",
	}, on_done)

## Game events that power the weekly digest + milestone emails
## (play_start / death {boss} / boss_defeat {boss, score, first_time} /
## wallet_connect). Fire-and-forget; no-ops without a backend.
func report_event(event: String, data: Dictionary = {}) -> void:
	if not has_backend():
		return
	var body := {"player_id": player_id(), "event": event}
	body.merge(data)
	if _health_checked_once and not backend_online:
		_queue_analytics("/events", body)
		return
	_backend("POST", "/events", body, func(_x): pass)

# ---- Level Depth (task #23): granular analytics + adaptive-difficulty data --

## Granular gameplay metric (Video-Game Layer): death / powerup_used /
## secret_found / boss_phase_reached / lore_read / share_clicked /
## referral_code_used / level_complete / retry. Feeds pstats on the backend,
## which powers dynamic difficulty + the founder digest. Fire-and-forget.
func report_metric(event_type: String, event_data: Dictionary = {}) -> void:
	if not has_backend():
		return
	var body := {"player_id": player_id(), "event_type": event_type, "event_data": event_data}
	if _health_checked_once and not backend_online:
		_queue_analytics("/event", body)
		return
	_backend("POST", "/event", body, func(_x): pass)

## Death heatmap + pacing stats for DifficultyManager.
func get_player_analytics(on_done: Callable) -> void:
	_backend("GET", "/player-analytics?player_id=" + player_id().uri_encode(), {}, on_done)

## One fresh community-lore snippet for a broken secret wall.
func get_community_lore(on_done: Callable) -> void:
	_backend("GET", "/community-lore", {}, on_done)

## Weekly top-10 silhouettes for the Hall of Blaze easter room.
func get_hall_of_blaze(on_done: Callable) -> void:
	_backend("GET", "/hall-of-blaze", {}, on_done)
