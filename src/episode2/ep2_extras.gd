class_name Ep2Extras
extends RefCounted
## EPISODE 2 EXTRAS, STREAMED (founder 2026-10-19: "Stream Episode 2 extras").
##
## The web build has a hard 190 MiB gate on index.pck (itch rejects any file over 200 MB). New Episode 2 art that does not fit -
## the two-storey Armory, the founder's Tripo Rich and Utah with their mocap clips - lives under res://src/episode2/extras/.
## CI leaves that folder OUT of index.pck and packs it into a second file, ep2_extras.pck, deployed next to it
## (tools/ep2_extras/pack_extras.gd). When Episode 2 starts, the web build downloads that pack into user:// and mounts it with
## ProjectSettings.load_resource_pack; from then on ResourceLoader.exists() finds the extras like any other resource.
##
## Rules: callers ALWAYS check `has(path)` and keep their old asset as the fallback, so a slow or failed download only means the
## old Armory / old Rich and Utah are shown - never a missing building. In the editor, tests and a desktop run the files are on
## disk (has() is true at once, nothing downloads).

const PACK := "ep2_extras.pck"
const LOCAL := "user://ep2_extras.pck"
const ARMORY := "res://src/episode2/extras/armory/armory2.glb"
const RICH := "res://src/episode2/extras/folk/rich_armory2.glb"
const UTAH := "res://src/episode2/extras/folk/utah_armory2.glb"
## The town kit with REAL openings (windows, doors, side windows; 2026-10-19 openings pass): same piece names as town_kit.glb.
const TOWN_KIT := "res://src/episode2/extras/town/town_kit2.glb"
## The townspeople (Ep2TownPeople), one rigged GLB each.
const PEOPLE_DIR := "res://src/episode2/extras/people/"

static var _state: String = ""            # "" never started, "loading", "ready", "failed"
static var _http: HTTPRequest = null


## True when `path` can be loaded now (on disk in the editor/desktop, or after the web pack mounted).
static func has(path: String) -> bool:
	return ResourceLoader.exists(path)


## "ready" once the pack mounted (or the files are already present), "loading", "failed" or "" (not started).
static func state() -> String:
	if _state == "" and has(ARMORY):
		return "ready"
	return _state


## Start the background download once, from any node in the tree (Episode 2's entry calls it). The HTTPRequest lives on the
## tree root so it survives scene changes. No-op off the web or when the extras are already loadable.
static func start(from: Node) -> void:
	if _state != "" or has(ARMORY) or not OS.has_feature("web") or from == null or not from.is_inside_tree():
		return
	_state = "loading"
	_http = HTTPRequest.new()
	_http.name = "Ep2ExtrasDownload"
	_http.download_file = LOCAL
	_http.use_threads = false
	_http.timeout = 300.0
	# lambdas, not bare static-method callables: they bind the same in every 4.x
	_http.request_completed.connect(func(r: int, c: int, h: PackedStringArray, b: PackedByteArray) -> void: Ep2Extras._on_done(r, c, h, b))
	_http.ready.connect(func() -> void: Ep2Extras._request(), CONNECT_ONE_SHOT)
	from.get_tree().root.add_child.call_deferred(_http)


static func _request() -> void:
	if _http == null or not _http.is_inside_tree():
		_state = "failed"
		return
	# page base (literal JS, no interpolation: security-sentinel INJ-003 form (a)) + the pack + a cache-buster per build
	var base: String = str(JavaScriptBridge.eval("window.location.href.substring(0, window.location.href.lastIndexOf('/') + 1)", true))
	var tag: String = GameManager.BUILD_TAG                 # CI stamps it per build, so a new pack is never served stale
	var err: int = _http.request(base + PACK + "?v=" + tag.uri_encode())
	if err != OK:
		_state = "failed"


static func _on_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and ProjectSettings.load_resource_pack(LOCAL, false):
		_state = "ready" if has(ARMORY) else "failed"
	else:
		_state = "failed"
	if _http != null:
		_http.queue_free()
		_http = null
	print("[EP2] extras ", _state, " (http ", code, ")")
