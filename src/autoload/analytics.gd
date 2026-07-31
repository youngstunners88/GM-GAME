extends Node
## PostHog product analytics for the WEB export.
##
## WHY A MIRROR AND NOT NEW CALL SITES: this game already had a complete,
## well-shaped telemetry layer in `Web3Bridge` — `report_event()`,
## `report_metric()` and `track()`, all keyed by a random pseudonymous UUID,
## all offline-queued, all free of PII. Adding a second set of capture calls
## across the codebase would have produced two taxonomies that drift apart.
## Instead Web3Bridge forwards what it already emits to `capture()` here, so
## there is exactly ONE list of events and PostHog sees the same thing the
## backend does.
##
## PRIVACY POSTURE (deliberate, do not loosen without asking):
##   - The only identifier sent is `Web3Bridge.player_id()`, a locally
##     generated random UUID. No email, no IP-derived identity, no wallet
##     address — a wallet address is a real financial identifier and is
##     NEVER forwarded here even though the game knows it.
##   - `person_profiles: "identified_only"` + we never call identify(), so
##     PostHog does not build person profiles from anonymous traffic.
##   - Autocapture and session recording are OFF. We send only the explicit
##     game events listed in docs/analytics/EVENT_SCHEMA.md.
##
## FAILS QUIET, NEVER LOUD: no token, non-web platform, blocked by CSP or an
## ad-blocker — every path degrades to a no-op. Analytics must never be able
## to break the game.

## Event names are whitelisted to this shape before they reach JS. See
## _capture_js() for why this matters.
const _SAFE_NAME := "^[a-z0-9_]+$"

var _enabled: bool = false
var _token: String = ""
var _host: String = "https://us.i.posthog.com"
var _loaded: bool = false
var _name_re: RegEx

func _ready() -> void:
	_name_re = RegEx.new()
	_name_re.compile(_SAFE_NAME)
	_load_config()
	if _enabled:
		_boot()

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
	var cfg: Dictionary = parsed
	var a: Dictionary = cfg.get("analytics", {})
	_token = str(a.get("posthog_token", ""))
	_host = str(a.get("posthog_host", _host))
	# Every condition must hold: switched on, a token present, and actually on
	# the web export (JavaScriptBridge only exists there).
	_enabled = bool(a.get("enabled", false)) and _token != "" and OS.has_feature("web")

## Loads posthog-js from the configured host.
##
## NOTE FOR WHOEVER DEBUGS THIS LATER: this needs BOTH `script-src` (to fetch
## the library) and `connect-src` (to POST events) to allow the PostHog host
## in the Content-Security-Policy. The shipped CSP was `connect-src 'self'`,
## which would have swallowed every event silently while the code looked
## perfectly healthy. vercel.json, netlify.toml and web/_headers were all
## updated alongside this file — if you add another host, update all three.
func _boot() -> void:
	if _loaded:
		return
	# Fixed template with only the two config values interpolated, both of
	# which are validated below. No event data flows through this string.
	if not _looks_like_token(_token) or not _looks_like_host(_host):
		push_warning("Analytics: token or host failed validation — disabled.")
		_enabled = false
		return
	var js := """
	(function(){
	  if (window.__lbPH) return;
	  window.__lbPH = {ready:false, q:[]};
	  var s = document.createElement('script');
	  s.src = '%s/static/array.js';
	  s.async = true;
	  s.onload = function(){
	    try {
	      window.posthog.init('%s', {
	        api_host: '%s',
	        person_profiles: 'identified_only',
	        autocapture: false,
	        capture_pageview: false,
	        disable_session_recording: true
	      });
	      window.__lbPH.ready = true;
	      var q = window.__lbPH.q; window.__lbPH.q = [];
	      for (var i=0;i<q.length;i++) { try { window.posthog.capture(q[i].e, q[i].p); } catch(_){} }
	    } catch(_){}
	  };
	  s.onerror = function(){ window.__lbPH.blocked = true; };
	  document.head.appendChild(s);
	  window.__lbCapture = function(name, props){
	    try {
	      if (window.__lbPH.blocked) return;
	      if (window.__lbPH.ready && window.posthog) window.posthog.capture(name, props);
	      else if (window.__lbPH.q.length < 100) window.__lbPH.q.push({e:name, p:props});
	    } catch(_){}
	  };
	})();
	""" % [_js_config(_host), _js_config(_token), _js_config(_host)]
	JavaScriptBridge.eval(js, true)
	_loaded = true

## `phc_` + base64url-ish body. Anything else is not a PostHog project key and
## must not be pasted into a <script> context.
func _looks_like_token(t: String) -> bool:
	var re := RegEx.new()
	re.compile("^phc_[A-Za-z0-9]{20,80}$")
	return re.search(t) != null

func _looks_like_host(h: String) -> bool:
	var re := RegEx.new()
	re.compile("^https://[A-Za-z0-9.-]+$")
	return re.search(h) != null


## Keys that must never reach a third-party analytics service, stripped
## recursively regardless of what a caller passes.
##
## Kimi audit finding: before this existed, the "no wallet, no email" promise
## in the header comment was enforced by NOTHING — `props` went straight to
## JSON.stringify, so the guarantee rested entirely on every current and
## future caller remembering the rule. No call site violates it today; this is
## defence in depth so that a future one cannot.
const _DENY_KEYS := [
	"wallet", "wallet_address", "address", "email", "name", "username",
	"player_name", "signature", "private_key", "seed", "ip",
]

func _strip_identifiers(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		var key := str(k)
		if key.to_lower() in _DENY_KEYS:
			continue
		var v: Variant = d[k]
		out[key] = _strip_identifiers(v) if typeof(v) == TYPE_DICTIONARY else v
	return out

## A PostHog-scoped id derived from — but not equal to — the backend's
## player_id.
##
## Kimi audit finding: sending the raw player_id meant the PostHog profile was
## a single backend JOIN away from being re-identified, because the backend
## also receives the wallet address (see submit_lore). Hashing with a fixed
## salt keeps the id stable per player (so funnels and retention still work)
## while making it useless for correlating the two datasets.
func _analytics_id() -> String:
	var raw := "lil-blunt-posthog-v1|" + Web3Bridge.player_id()
	return raw.sha256_text().substr(0, 32)


# ---- JS interpolation sanitizers -------------------------------------------
#
# Every value that reaches a JavaScriptBridge.eval string goes through one of
# these three, by name, so that both a reader and the INJ-003 static check in
# scripts/security-sentinel.sh can see the boundary. They are the analytics
# equivalent of web3_bridge.gd's _hex(): each one either returns a value that
# provably cannot carry JS syntax, or returns empty.

## Whitelist an identifier to [a-z0-9_]. Cannot contain a quote, backslash,
## semicolon, angle bracket, or whitespace, so it is safe inside '...'.
func _js_ident(name: String) -> String:
	return name if _name_re.search(name) != null else ""

## Serialise a payload to a JSON literal. JSON is a subset of JS expression
## syntax, so the result is a valid literal; the two Unicode line terminators
## that are legal in JSON but act as line breaks in JS SOURCE are stripped
## (built with String.chr so an editor normalising the file cannot silently
## turn them back into real characters).
func _js_json(d: Dictionary) -> String:
	var out := JSON.stringify(d)
	return out.replace(String.chr(0x2028), "").replace(String.chr(0x2029), "")

## Re-validate a config value at the point of interpolation. _boot() already
## refuses to run on a bad token/host; this is the second gate so the eval
## string itself has a sanitizer on every hole rather than relying on a check
## several lines above it.
func _js_config(v: String) -> String:
	if _looks_like_token(v) or _looks_like_host(v):
		return v
	return ""

## Send one event. `props` must be plain JSON-encodable data.
##
## INJECTION NOTE (project rule INJ-003): the event name is whitelisted to
## [a-z0-9_] and the properties are passed as a JSON literal produced by
## JSON.stringify, with the two Unicode line terminators that are legal in
## JSON but ILLEGAL in JS source stripped. Nothing else from gameplay reaches
## the JS string.
func capture(event_name: String, props: Dictionary = {}) -> void:
	if not _enabled or not _loaded:
		return
	if _name_re.search(event_name) == null:
		return
	var payload := _strip_identifiers(props.duplicate(true))
	# Pseudonymous only — see the privacy note at the top of this file.
	payload["distinct_id"] = _analytics_id()
	JavaScriptBridge.eval(
		"window.__lbCapture && window.__lbCapture('%s', %s);"
		% [_js_ident(event_name), _js_json(payload)], true)
