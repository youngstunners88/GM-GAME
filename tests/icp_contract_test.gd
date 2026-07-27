extends Node
## End-to-end test of the Godot -> ICP HTTP read path.
##
## SCOPE, STATED PRECISELY: this drives the real `IcpBackend` autoload over real
## HTTP against a server returning the EXACT bytes `price_feed.mo`'s
## `http_request` emits. It proves the client half — URL construction in both
## addressing styles, HTTP, JSON parse, GameManager publication, and the
## fallback path.
##
## It does NOT prove the canister half. A local replica cannot start in this
## sandbox (`icp network start` fetches its launcher from api.github.com, which
## the egress policy 403s; Docker has no daemon). So the canister's own output
## is verified by compiling it, not by running it. When someone runs a replica
## on a dev machine, point this same test at it by flipping the config — the
## assertions do not change.
##
## Run: godot --headless res://tests/icp_contract_test.tscn -- <base-url>
## Exit code 0 = all assertions passed.

var _failures: int = 0
var _base: String = "http://127.0.0.1:8788"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("http"):
			_base = arg
	await _run()

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	_test_url_building()
	await _test_price_fetch_parses_canister_json()
	await _test_offline_fallback_keeps_last_price()

	if _failures == 0:
		print("ICP_CONTRACT: ALL PASS")
		get_tree().quit(0)
	else:
		print("ICP_CONTRACT: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

func _test_url_building() -> void:
	print("URL construction:")
	# Mainnet subdomain style.
	IcpBackend.path_style = false
	IcpBackend.scheme = "https"
	IcpBackend.gateway = "icp0.io"
	IcpBackend.port = 0
	_check("mainnet subdomain form",
		IcpBackend.endpoint("aaaaa-aa", "/prices") == "https://aaaaa-aa.icp0.io/prices",
		IcpBackend.endpoint("aaaaa-aa", "/prices"))

	# Local replica path style.
	IcpBackend.path_style = true
	IcpBackend.scheme = "http"
	IcpBackend.gateway = "127.0.0.1"
	IcpBackend.port = 4943
	var local := IcpBackend.endpoint("aaaaa-aa", "/prices")
	_check("local path form carries canisterId",
		local == "http://127.0.0.1:4943/prices?canisterId=aaaaa-aa", local)

	var with_query := IcpBackend.endpoint("aaaaa-aa", "/top", {"level": 2})
	_check("extra query params survive",
		with_query.contains("level=2") and with_query.contains("canisterId=aaaaa-aa"),
		with_query)

	# A malformed id must be rejected before it can build a request elsewhere.
	IcpBackend.price_feed_canister_id = "evil.example.com/x"
	_check("hostile canister id rejected", not IcpBackend.has_price_feed())
	IcpBackend.price_feed_canister_id = "ryjl3-tyaaa-aaaaa-aaaba-cai"
	_check("well-formed canister id accepted", IcpBackend.has_price_feed())

func _test_price_fetch_parses_canister_json() -> void:
	print("price fetch against the canister's JSON contract:")
	var parts := _base.trim_prefix("http://").split(":")
	IcpBackend.path_style = true
	IcpBackend.scheme = "http"
	IcpBackend.gateway = parts[0]
	IcpBackend.port = int(parts[1]) if parts.size() > 1 else 0
	IcpBackend.icp_online = true
	GameManager.offline_mode = false

	IcpBackend.fetch_prices()
	var result: Array = await IcpBackend.prices_ready
	var prices: Dictionary = result[0]
	var source: String = result[1]

	_check("source reported as icp", source == "icp", "got '%s'" % source)
	_check("ETH parsed", prices.has("ETH"), str(prices))
	_check("ETH value correct",
		absf(float(prices.get("ETH", 0.0)) - 3456.78) < 0.01,
		str(prices.get("ETH", 0.0)))
	# Sub-cent tokens are the reason the canister renders 8 decimal places.
	_check("sub-cent SMOKE keeps precision",
		absf(float(prices.get("SMOKE", 0.0)) - 0.00042) < 0.0000001,
		str(prices.get("SMOKE", 0.0)))
	_check("published into GameManager.crypto_state",
		absf(GameManager.get_crypto("eth_price") - 3456.78) < 0.01,
		str(GameManager.get_crypto("eth_price")))

func _test_offline_fallback_keeps_last_price() -> void:
	print("offline fallback:")
	# Point at a dead port: the request must fail, not hang the game.
	IcpBackend.gateway = "127.0.0.1"
	IcpBackend.port = 9   # discard port, nothing listening
	IcpBackend.icp_online = true

	IcpBackend.fetch_prices()
	var result: Array = await IcpBackend.prices_ready
	var source: String = result[1]
	_check("degrades to offline, not an error", source == "offline",
		"got '%s'" % source)
	# The critical property: a failed fetch must not blank a good price.
	_check("last good ETH price retained",
		absf(GameManager.get_crypto("eth_price") - 3456.78) < 0.01,
		str(GameManager.get_crypto("eth_price")))
	_check("icp_online latched off after failure", IcpBackend.icp_online == false)
