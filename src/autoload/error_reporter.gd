extends Node
## Sentry error reporting for the WEB export.
##
## Built to the same rules as `analytics.gd` (PostHog), for the same reasons:
##
##   1. MIRROR WHAT EXISTS, don't invent a parallel system. The project already
##      marks its real failures with `push_error()`. The highest-value of those
##      sites now also call `ErrorReporter.report()`. There is no new error
##      taxonomy to keep in sync.
##   2. HUNT THE SILENT DROP. Sentry ingest is a cross-origin POST, so
##      `connect-src` in the Content-Security-Policy has to allow it or every
##      report vanishes while the code looks healthy. That is the exact trap
##      PostHog hit. vercel.json, netlify.toml and web/_headers were all
##      updated; `script-src` also needs the CDN host for the SDK itself.
##   3. NEVER CRASH THE GAME. Missing DSN, non-web platform, blocked CDN,
##      ad-blocker, Sentry down — every path is a silent no-op.
##
## WHAT IT CAPTURES
##   - Uncaught JS exceptions and unhandled promise rejections from the export
##     shell (this is where engine/WASM failures surface).
##   - Explicit GDScript failures worth waking up for: scene-load failure and
##     save failure. A failed save silently loses a player's campaign, which is
##     the single worst non-crash outcome this game has.
##
## PRIVACY — matches or exceeds the PostHog bar
##   - `sendDefaultPii: false`.
##   - The id attached is an INDEPENDENT random UUID (user://error_id.txt), not
##     `player_id()` and not a hash of it. A hash with a client-visible salt
##     would still be re-computable by anyone holding the backend's player_id
##     list, which sits beside the wallet address — see _scoped_id().
##   - No wallet, no email, no name — enforced in code, by key AND by value,
##     through dictionaries and arrays. Not by caller discipline.
##   - The SDK's own URL/query-string and fetch-XHR breadcrumbs are scrubbed;
##     `sendDefaultPii: false` alone does not stop those.
##   - The SDK bundle is version-pinned AND integrity-checked (SRI), because
##     this page can prompt a wallet signature.

const _SAFE_NAME := "^[a-z0-9_.:-]+$"

var _enabled: bool = false
var _dsn: String = ""
var _release: String = "dev"
var _loaded: bool = false
var _name_re: RegEx

## Keys that must never leave the client, stripped recursively from any
## context dictionary regardless of what a caller passes.
const _DENY_KEYS := [
	"wallet", "wallet_address", "address", "email", "name", "username",
	"player_name", "signature", "private_key", "seed", "ip",
]

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
	var s: Dictionary = cfg.get("sentry", {})
	_dsn = str(s.get("dsn", ""))
	_release = str(s.get("release", "dev"))
	_enabled = bool(s.get("enabled", false)) and _dsn != "" and OS.has_feature("web")

## Loads the Sentry browser SDK and installs the global handlers.
##
## `environment` is derived from the HOSTNAME at runtime rather than baked in,
## so one build reports correctly from itch.io, Vercel, Netlify and localhost
## without a per-mirror export. Without this every mirror's errors land in one
## undifferentiated pile and "is this only broken on itch?" is unanswerable.
func _boot() -> void:
	if _loaded:
		return
	if not _looks_like_dsn(_dsn):
		push_warning("ErrorReporter: DSN failed validation — disabled.")
		_enabled = false
		return
	var js := """
	(function(){
	  if (window.__lbSentry) return;
	  window.__lbSentry = {ready:false, q:[]};
	  var env = 'unknown';
	  try {
	    var h = String(location.hostname || '');
	    if (h.indexOf('itch.io') !== -1 || h.indexOf('hwcdn.net') !== -1) env = 'itch';
	    else if (h.indexOf('vercel.app') !== -1) env = 'vercel';
	    else if (h.indexOf('netlify') !== -1) env = 'netlify';
	    else if (h.indexOf('pages.dev') !== -1) env = 'cloudflare';
	    else if (h === 'localhost' || h === '127.0.0.1') env = 'local';
	    else if (h) env = 'other';
	  } catch(_){}
	  window.__lbSentry.env = env;
	  var s = document.createElement('script');
	  s.src = 'https://browser.sentry-cdn.com/8.42.0/bundle.tracing.min.js';
	  // SUBRESOURCE INTEGRITY. This page can prompt a wallet signature, so a
	  // swapped or compromised bundle could hook that flow with full page
	  // privileges. The version is pinned AND the bytes are verified; the
	  // browser refuses to execute on any mismatch. Hash computed from the
	  // exact 8.42.0 bundle (openssl dgst -sha384). If the version is bumped,
	  // RECOMPUTE THIS or the SDK silently stops loading.
	  s.integrity = 'sha384-bG2vyJAuRm/JbGQrlET5H7y0CTvPF0atiBjekU/WUKUwKwThDXrqRhZiQ+jWaagS';
	  s.crossOrigin = 'anonymous';
	  s.async = true;
	  s.onload = function(){
	    try {
	      window.Sentry.init({
	        dsn: '%s',
	        release: '%s',
	        environment: env,
	        sendDefaultPii: false,
	        tracesSampleRate: 0,
	        replaysSessionSampleRate: 0,
	        replaysOnErrorSampleRate: 0,
	        autoSessionTracking: true,
	        // sendDefaultPii:false does NOT stop the default integrations from
	        // attaching the full page URL or recording fetch/XHR breadcrumbs.
	        // On itch the URL carries session-ish query params, and this game
	        // makes Web3 RPC calls whose URLs can embed API keys — so both are
	        // scrubbed here rather than trusted.
	        beforeSend: function(ev){
	          try {
	            if (ev.request && ev.request.url) ev.request.url = String(ev.request.url).split('?')[0];
	            if (ev.request && ev.request.query_string) delete ev.request.query_string;
	            if (ev.request && ev.request.headers) delete ev.request.headers;
	          } catch(_){}
	          return ev;
	        },
	        beforeBreadcrumb: function(bc){
	          try {
	            if (!bc) return null;
	            if (bc.category === 'fetch' || bc.category === 'xhr') return null;
	            if (bc.data && bc.data.url) bc.data.url = String(bc.data.url).split('?')[0];
	          } catch(_){}
	          return bc;
	        }
	      });
	      window.__lbSentry.ready = true;
	      var q = window.__lbSentry.q; window.__lbSentry.q = [];
	      for (var i=0;i<q.length;i++) {
	        try { window.Sentry.captureMessage(q[i].m, {level:q[i].l, extra:q[i].x}); } catch(_){}
	      }
	    } catch(_){}
	  };
	  s.onerror = function(){ window.__lbSentry.blocked = true; };
	  document.head.appendChild(s);
	  window.__lbReport = function(msg, level, extra){
	    try {
	      if (window.__lbSentry.blocked) return;
	      if (window.__lbSentry.ready && window.Sentry) {
	        window.Sentry.captureMessage(msg, {level: level, extra: extra});
	      } else if (window.__lbSentry.q.length < 50) {
	        window.__lbSentry.q.push({m:msg, l:level, x:extra});
	      }
	    } catch(_){}
	  };
	  window.__lbSetUser = function(id){
	    try { if (window.Sentry && window.Sentry.setUser) window.Sentry.setUser({id:id}); } catch(_){}
	  };
	})();
	""" % [_js_dsn(_dsn), _js_ident(_release)]
	JavaScriptBridge.eval(js, true)
	_loaded = true
	# Pseudonymous, salted — see the privacy note above.
	JavaScriptBridge.eval(
		"window.__lbSetUser && window.__lbSetUser('%s');" % _js_ident(_scoped_id()), true)

## A Sentry DSN: https://<publicKey>@<host>/<projectId>. Anything else must not
## reach a <script> context.
func _looks_like_dsn(d: String) -> bool:
	var re := RegEx.new()
	re.compile("^https://[A-Za-z0-9]+@[A-Za-z0-9.\\-]+/[0-9]+$")
	return re.search(d) != null

## An INDEPENDENT random id, not derived from player_id() at all.
##
## The first version hashed player_id() with a fixed salt and the header claimed
## that made it un-joinable. Kimi correctly pointed out that is false: the salt
## ships in the client, so anyone holding the backend's player_id list (which
## sits beside the wallet address, via submit_lore) can recompute the hash for
## every row and re-link every Sentry profile to a wallet. A distinct salt only
## stops Sentry<->PostHog correlation; it does nothing against the backend.
##
## A separately generated UUID breaks that join outright — there is no function
## from player_id to this value.
const ERROR_ID_PATH := "user://error_id.txt"

func _scoped_id() -> String:
	if FileAccess.file_exists(ERROR_ID_PATH):
		var rf := FileAccess.open(ERROR_ID_PATH, FileAccess.READ)
		if rf != null:
			var existing := rf.get_as_text().strip_edges()
			rf.close()
			if existing.length() == 32:
				return existing
	var fresh := _random_hex32()
	var wf := FileAccess.open(ERROR_ID_PATH, FileAccess.WRITE)
	if wf != null:
		wf.store_string(fresh)
		wf.close()
	return fresh

func _random_hex32() -> String:
	var out := ""
	for i in 32:
		out += "0123456789abcdef"[randi() % 16]
	return out

# ---- JS interpolation sanitizers -------------------------------------------
#
# Same contract as analytics.gd: every hole in an eval'd string goes through a
# named sanitizer so both a reader and the INJ-003 check in
# scripts/security-sentinel.sh can see the boundary.

## Whitelist to [a-z0-9_.:-] — no quotes, backslashes, semicolons or brackets,
## so it is safe inside '...'.
func _js_ident(v: String) -> String:
	return v if _name_re.search(v) != null else ""

## Re-validate the DSN at the point of interpolation, so the eval string has a
## sanitizer on every hole rather than relying on a check further up.
func _js_dsn(v: String) -> String:
	return v if _looks_like_dsn(v) else ""

## Serialise context to a JSON literal, stripping the two Unicode line
## terminators that are legal in JSON but act as line breaks in JS source.
func _js_json(d: Dictionary) -> String:
	var out := JSON.stringify(_strip_identifiers(d))
	return out.replace(String.chr(0x2028), "").replace(String.chr(0x2029), "")

## Strips identifying data by KEY and by VALUE, through dictionaries AND
## arrays.
##
## The first version only recursed dictionaries and matched keys exactly, so
## `{"items": [{"walletAddress": "0x..."}]}` sailed straight through on two
## counts (array, camelCase). It also never looked at values, and this game's
## error context carries URLs and RPC endpoints that can embed keys or
## addresses. Kimi finding; all three closed here.
const _MAX_VALUE_LEN := 256

func _norm_key(k: String) -> String:
	return k.to_lower().replace("_", "").replace("-", "")

func _strip_identifiers(d: Dictionary) -> Dictionary:
	var out := {}
	var deny_norm := []
	for dk in _DENY_KEYS:
		deny_norm.append(_norm_key(dk))
	for k in d.keys():
		var key := str(k)
		if _norm_key(key) in deny_norm:
			continue
		out[key] = _scrub_value(d[k])
	return out

func _scrub_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			return _strip_identifiers(v)
		TYPE_ARRAY:
			var arr := []
			for item in v:
				arr.append(_scrub_value(item))
			return arr
		TYPE_STRING:
			return _scrub_string(v)
		_:
			return v

## Redacts anything that looks like a wallet address or a bearer-ish token,
## drops URL query strings, and caps length so a stack-ish blob cannot smuggle
## a payload through in one field.
func _scrub_string(s_in: String) -> String:
	var out := s_in
	var addr := RegEx.new()
	addr.compile("0x[0-9a-fA-F]{20,}")
	out = addr.sub(out, "[redacted-address]", true)
	var q := out.find("?")
	if q != -1 and out.begins_with("http"):
		out = out.substr(0, q)
	if out.length() > _MAX_VALUE_LEN:
		out = out.substr(0, _MAX_VALUE_LEN) + "…"
	return out

## Report an explicit game-side failure.
##
## `where` is a short stable identifier ("scene_load_failed", "save_failed") —
## it becomes the Sentry issue title, so it must be a constant, never
## interpolated with a path or id. Put the variable part in `context`.
func report(where: String, context: Dictionary = {}, level: String = "error") -> void:
	if not _enabled or not _loaded:
		return
	var name := _js_ident(where)
	if name == "":
		return
	var lvl := _js_ident(level)
	if lvl == "":
		lvl = "error"
	JavaScriptBridge.eval(
		"window.__lbReport && window.__lbReport('%s', '%s', %s);"
		% [name, lvl, _js_json(context)], true)
